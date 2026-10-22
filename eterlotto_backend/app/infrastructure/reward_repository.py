"""Eterlotto rewards: atomic operations on the existing PostgreSQL pool.

All reward mutations are performed inside a transaction serialized by locking
public.users.id for that user. Flutter must never write these tables directly.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

from app.infrastructure.db_connection import get_pool

VIDEOS_PER_PASS = 7
CHALLENGE_DURATION = timedelta(days=7)
REDEEM_DURATION = timedelta(days=7)
PASS_DURATION = timedelta(hours=12)
FUNCTION_DURATION = timedelta(minutes=30)
SESSION_DURATION = timedelta(hours=24)


class RewardRejected(Exception):
    """Expected, safe-to-report rejection of a reward operation."""


async def start_video_session(user_id: int, origin: str, feature_key: str | None) -> dict:
    pool = get_pool()
    # Prevent accidental rapid retries from creating unbounded pending sessions.
    async with pool.acquire() as connection:
        async with connection.transaction():
            user = await connection.fetchval(
                "SELECT id FROM public.users WHERE id=$1 FOR UPDATE", user_id
            )
            if user is None:
                raise RewardRejected("Usuario no encontrado")
            recent_pending = await connection.fetchval(
                """SELECT COUNT(*) FROM public.recompensa_sesiones
                   WHERE user_id=$1 AND estado='pendiente'
                     AND creada_en > NOW() - INTERVAL '10 minutes'""", user_id
            )
            if recent_pending >= 10:
                raise RewardRejected("Demasiadas solicitudes de video. Intenta más tarde")
            row = await connection.fetchrow(
                """INSERT INTO public.recompensa_sesiones
                   (user_id, origen, funcion_clave, expira_en)
                   VALUES ($1, $2, $3, NOW() + INTERVAL '24 hours')
                   RETURNING id, expira_en""",
                user_id, origin, feature_key,
            )
    return {
        "session_id": str(row["id"]),
        "ssv_custom_data": str(row["id"]),
        "ssv_user_id": str(user_id),
        "expires_at": row["expira_en"],
    }


async def get_reward_status(user_id: int) -> dict:
    pool = get_pool()
    async with pool.acquire() as connection:
        # All expiration checks use NOW() from PostgreSQL (UTC timestamps).
        challenge = await connection.fetchrow(
            """SELECT videos_verificados, iniciado_en, vence_en FROM public.recompensa_retos
               WHERE user_id=$1 AND estado='en_progreso' AND vence_en > NOW()
               ORDER BY iniciado_en DESC LIMIT 1""", user_id
        )
        available = await connection.fetch(
            """SELECT id, activar_antes_de FROM public.recompensa_pases
               WHERE user_id=$1 AND estado='disponible' AND activar_antes_de > NOW()
               ORDER BY obtenido_en""", user_id
        )
        active = await connection.fetchrow(
            """SELECT id, activado_en, vence_en FROM public.recompensa_pases
               WHERE user_id=$1 AND estado='activo' AND vence_en > NOW()
               ORDER BY activado_en DESC LIMIT 1""", user_id
        )
        unlocks = await connection.fetch(
            """SELECT funcion_clave, desbloqueado_hasta FROM public.recompensa_desbloqueos
               WHERE user_id=$1 AND desbloqueado_hasta > NOW()""", user_id
        )
        server_now = await connection.fetchval("SELECT NOW()")
    return {
        "server_time": server_now,
        "videos_required": VIDEOS_PER_PASS,
        "videos_completed": challenge["videos_verificados"] if challenge else 0,
        "challenge_expires_at": challenge["vence_en"] if challenge else None,
        "passes_available": len(available),
        "available_passes": [
            {"id": str(p["id"]), "activate_before": p["activar_antes_de"]}
            for p in available
        ],
        "pass_active": active is not None,
        "active_pass_id": str(active["id"]) if active else None,
        "pass_expires_at": active["vence_en"] if active else None,
        "feature_unlocks": {p["funcion_clave"]: p["desbloqueado_hasta"] for p in unlocks},
    }


async def activate_pass(user_id: int) -> dict:
    pool = get_pool()
    async with pool.acquire() as connection:
        async with connection.transaction():
            user = await connection.fetchval(
                "SELECT id FROM public.users WHERE id=$1 FOR UPDATE", user_id
            )
            if user is None:
                raise RewardRejected("Usuario no encontrado")
            await connection.execute(
                """UPDATE public.recompensa_pases SET estado='consumido'
                   WHERE user_id=$1 AND estado='activo' AND vence_en <= NOW()""", user_id
            )
            await connection.execute(
                """UPDATE public.recompensa_pases SET estado='vencido'
                   WHERE user_id=$1 AND estado='disponible'
                     AND activar_antes_de <= NOW()""", user_id
            )
            active = await connection.fetchrow(
                """SELECT id, vence_en FROM public.recompensa_pases
                   WHERE user_id=$1 AND estado='activo' AND vence_en > NOW()
                   LIMIT 1""", user_id
            )
            if active:
                return {"activated": False, "already_active": True,
                        "pass_id": str(active["id"]), "expires_at": active["vence_en"]}
            available = await connection.fetchrow(
                """SELECT id FROM public.recompensa_pases
                   WHERE user_id=$1 AND estado='disponible'
                     AND activar_antes_de > NOW()
                   ORDER BY obtenido_en ASC LIMIT 1 FOR UPDATE""", user_id
            )
            if not available:
                raise RewardRejected("No tienes un pase disponible")
            started_at = datetime.now(timezone.utc)
            expires_at = started_at + PASS_DURATION
            await connection.execute(
                """UPDATE public.recompensa_pases
                   SET estado='activo', activado_en=$2, vence_en=$3
                   WHERE id=$1""", available["id"], started_at, expires_at
            )
    return {"activated": True, "already_active": False,
            "pass_id": str(available["id"]), "expires_at": expires_at}


async def credit_verified_video(
    session_id: UUID, user_id: int, transaction_id: str,
    ad_unit: str, rewarded_at: datetime,
) -> dict:
    """Credit exactly once; caller MUST verify Google ECDSA signature first."""
    pool = get_pool()
    async with pool.acquire() as connection:
        async with connection.transaction():
            # One lock per user serializes both concurrent callbacks and activation.
            user = await connection.fetchval(
                "SELECT id FROM public.users WHERE id=$1 FOR UPDATE", user_id
            )
            if user is None:
                raise RewardRejected("Usuario no encontrado")
            session = await connection.fetchrow(
                """SELECT id, user_id, origen, funcion_clave, estado, creada_en, expira_en,
                          admob_transaction_id
                   FROM public.recompensa_sesiones WHERE id=$1 FOR UPDATE""", session_id
            )
            if not session or session["user_id"] != user_id:
                raise RewardRejected("Sesión de video no válida")

            # AdMob may retry the *same* signed notification; never grant twice.
            if session["estado"] == "verificada":
                if session["admob_transaction_id"] == transaction_id:
                    return {"status": "already_credited", "credited": False}
                raise RewardRejected("Sesión ya utilizada")
            if session["estado"] != "pendiente":
                raise RewardRejected("Sesión no disponible")
            if not (session["creada_en"] - timedelta(minutes=5)
                    <= rewarded_at <= session["expira_en"]):
                raise RewardRejected("Recompensa fuera del periodo de la sesión")

            existing = await connection.fetchval(
                """SELECT id FROM public.recompensa_sesiones
                   WHERE admob_transaction_id=$1""", transaction_id
            )
            if existing is not None:
                raise RewardRejected("Transacción publicitaria ya utilizada")

            await connection.execute(
                """UPDATE public.recompensa_sesiones SET
                   estado='verificada', admob_transaction_id=$2,
                   admob_ad_unit=$3, verificada_en=NOW()
                   WHERE id=$1""", session_id, transaction_id, ad_unit
            )
            await connection.execute(
                """UPDATE public.recompensa_retos SET estado='vencido', actualizado_en=NOW()
                   WHERE user_id=$1 AND estado='en_progreso' AND vence_en <= NOW()""", user_id
            )
            challenge = await connection.fetchrow(
                """SELECT id, videos_verificados FROM public.recompensa_retos
                   WHERE user_id=$1 AND estado='en_progreso' AND vence_en > NOW()
                   LIMIT 1 FOR UPDATE""", user_id
            )
            if challenge is None:
                challenge = await connection.fetchrow(
                    """INSERT INTO public.recompensa_retos
                       (user_id, estado, videos_verificados, iniciado_en, vence_en)
                       VALUES ($1, 'en_progreso', 0, NOW(), NOW() + INTERVAL '7 days')
                       RETURNING id, videos_verificados""", user_id
                )
            count = challenge["videos_verificados"] + 1
            if count == VIDEOS_PER_PASS:
                await connection.execute(
                    """UPDATE public.recompensa_retos
                       SET videos_verificados=$2, estado='completado',
                           completado_en=NOW(), actualizado_en=NOW()
                       WHERE id=$1""", challenge["id"], count
                )
                await connection.execute(
                    """INSERT INTO public.recompensa_pases
                       (user_id, reto_id, estado, obtenido_en, activar_antes_de)
                       VALUES ($1, $2, 'disponible', NOW(), NOW() + INTERVAL '7 days')""",
                    user_id, challenge["id"]
                )
            else:
                await connection.execute(
                    """UPDATE public.recompensa_retos
                       SET videos_verificados=$2, actualizado_en=NOW() WHERE id=$1""",
                    challenge["id"], count
                )
            await connection.execute(
                """UPDATE public.recompensa_sesiones SET reto_id=$2 WHERE id=$1""",
                session_id, challenge["id"]
            )

            if session["origen"] == "funcion":
                await connection.execute(
                    """INSERT INTO public.recompensa_desbloqueos
                       (user_id, funcion_clave, desbloqueado_hasta, ultima_sesion_id, actualizado_en)
                       VALUES ($1, $2, NOW() + INTERVAL '30 minutes', $3, NOW())
                       ON CONFLICT (user_id, funcion_clave) DO UPDATE SET
                           desbloqueado_hasta = GREATEST(
                               public.recompensa_desbloqueos.desbloqueado_hasta,
                               NOW() + INTERVAL '30 minutes'),
                           ultima_sesion_id = EXCLUDED.ultima_sesion_id,
                           actualizado_en=NOW()""",
                    user_id, session["funcion_clave"], session_id
                )
    return {"status": "credited", "credited": True,
            "videos_completed": count, "pass_earned": count == VIDEOS_PER_PASS}
