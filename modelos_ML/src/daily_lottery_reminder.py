import argparse
import re
import sys
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path

from sqlalchemy import inspect, text

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine
from config.backend_notifications import BackendNotificationClient


_SAFE_IDENTIFIER = re.compile(r"^[a-zA-Z0-9_]+$")


class DailyLotteryReminder:
    """Un recordatorio diario por usuario, agrupando las loterías de su país."""

    def __init__(self):
        self.engine = get_engine()
        self.client = BackendNotificationClient()

    def _lotteries_due_on(self, target_date: date) -> list[dict]:
        due_ids: set[int] = set()

        with self.engine.connect() as conn:
            # Fuente 1: predicciones del día.
            try:
                rows = conn.execute(
                    text("""
                        SELECT DISTINCT loteria_id
                        FROM predicciones
                        WHERE fecha = :fecha
                          AND loteria_id IS NOT NULL
                    """),
                    {"fecha": target_date},
                ).fetchall()
                due_ids.update(int(row[0]) for row in rows if row[0] is not None)
            except Exception:
                pass

            # Fuente 2: placeholders de próximos sorteos en tablas resultados_*.
            inspector = inspect(conn)
            for table_name in inspector.get_table_names(schema="public"):
                if (
                    not table_name.startswith("resultados_")
                    or not _SAFE_IDENTIFIER.fullmatch(table_name)
                ):
                    continue

                columns = {
                    c["name"]
                    for c in inspector.get_columns(table_name, schema="public")
                }
                if not {"loteria_id", "fecha", "balota1"}.issubset(columns):
                    continue

                try:
                    rows = conn.execute(
                        text(
                            f"""
                            SELECT DISTINCT loteria_id
                            FROM {table_name}
                            WHERE fecha = :fecha
                              AND loteria_id IS NOT NULL
                              AND COALESCE(balota1, 0) = 0
                            """
                        ),
                        {"fecha": target_date},
                    ).fetchall()
                    due_ids.update(
                        int(row[0]) for row in rows if row[0] is not None
                    )
                except Exception:
                    continue

            if not due_ids:
                return []

            rows = conn.execute(
                text("""
                    SELECT id, nombre, pais_id
                    FROM loterias
                    WHERE id = ANY(:ids)
                      AND pais_id IS NOT NULL
                    ORDER BY pais_id, nombre
                """),
                {"ids": sorted(due_ids)},
            ).mappings().all()

        return [dict(row) for row in rows]

    def _users_for_countries(self, pais_ids: list[int]) -> list[dict]:
        if not pais_ids:
            return []

        with self.engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT id, pais_id
                    FROM users
                    WHERE pais_id = ANY(:pais_ids)
                      AND COALESCE(activo, TRUE) = TRUE
                      AND COALESCE(notificaciones_activas, TRUE) = TRUE
                    ORDER BY id
                """),
                {"pais_ids": pais_ids},
            ).mappings().all()

        return [dict(row) for row in rows]

    def _already_sent(self, user_id: int, target_date: date) -> bool:
        with self.engine.connect() as conn:
            return bool(
                conn.execute(
                    text("""
                        SELECT EXISTS (
                            SELECT 1
                            FROM notificaciones
                            WHERE usuario_id = :user_id
                              AND fecha_sorteo = :fecha
                              AND tipo = 'recordatorio_sorteos_hoy'
                        )
                    """),
                    {
                        "user_id": user_id,
                        "fecha": target_date,
                    },
                ).scalar()
            )

    @staticmethod
    def _message(names: list[str]) -> str:
        if len(names) == 1:
            return (
                f"🎟️ Hoy juega {names[0]}. "
                "Revisa tus análisis y jugadas en Eterlotto."
            )

        if len(names) == 2:
            joined = f"{names[0]} y {names[1]}"
        else:
            joined = ", ".join(names[:-1]) + f" y {names[-1]}"

        return (
            f"🎟️ Hoy juegan {joined}. "
            "Revisa tus análisis y jugadas en Eterlotto."
        )

    def run(self, target_date: date | None = None, force: bool = False) -> None:
        target_date = target_date or date.today()
        lotteries = self._lotteries_due_on(target_date)

        if not lotteries:
            print(f"ℹ️ No se detectaron sorteos para {target_date}.")
            return

        by_country: dict[int, list[dict]] = defaultdict(list)
        for lottery in lotteries:
            by_country[int(lottery["pais_id"])].append(lottery)

        users = self._users_for_countries(sorted(by_country))
        if not users:
            print("ℹ️ No hay usuarios habilitados para los países con sorteos.")
            return

        sent = 0
        skipped = 0
        failed = 0

        for user in users:
            user_id = int(user["id"])
            pais_id = int(user["pais_id"])
            country_lotteries = by_country.get(pais_id, [])
            if not country_lotteries:
                continue

            if not force and self._already_sent(user_id, target_date):
                skipped += 1
                continue

            names = [str(item["nombre"]) for item in country_lotteries]
            message = self._message(names)

            try:
                # Se asocia al primer juego únicamente para mantener contexto
                # de país en el buzón; el mensaje resume todas las loterías.
                response = self.client.publish(
                    loteria_id=int(country_lotteries[0]["id"]),
                    fecha_sorteo=target_date,
                    mensaje=message,
                    tipo="recordatorio_sorteos_hoy",
                    user_id=user_id,
                )
                push = response.get("push") or {}
                print(
                    f"✅ user_id={user_id} | país={pais_id} "
                    f"| loterías={len(names)} | sent={push.get('sent', 0)}"
                )
                sent += 1
            except Exception as exc:
                print(f"⚠️ user_id={user_id}: {exc}")
                failed += 1

        print(
            f"📨 Recordatorios: enviados={sent}, "
            f"omitidos={skipped}, fallidos={failed}"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Recordatorio diario de sorteos por país"
    )
    parser.add_argument(
        "--date",
        help="Fecha YYYY-MM-DD. Por defecto usa hoy.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignora idempotencia; solo para pruebas.",
    )
    args = parser.parse_args()

    target = (
        datetime.strptime(args.date, "%Y-%m-%d").date()
        if args.date
        else None
    )
    DailyLotteryReminder().run(target, force=args.force)
