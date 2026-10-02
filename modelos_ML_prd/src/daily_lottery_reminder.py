import argparse
import re
import sys
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from pathlib import Path

from sqlalchemy import text

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine
from config.backend_notifications import BackendNotificationClient




class DailyLotteryReminder:
    """Un recordatorio diario por usuario, agrupando las loterías de su país."""

    def __init__(self):
        self.engine = get_engine()
        self.client = BackendNotificationClient()

    def _lotteries_due_on(self, target_date: date) -> list[dict]:
        """Calendario oficial interno: loteria_horarios es la fuente de verdad."""
        with self.engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT
                        l.id,
                        l.nombre,
                        l.pais_id,
                        p.nombre AS pais_nombre,
                        COALESCE(NULLIF(l.timezone, ''), p.timezone_default) AS timezone,
                        h.hora_sorteo,
                        h.nombre_sorteo,
                        h.id AS horario_id,
                        COALESCE(l.horas_anticipacion_recordatorio, 5)
                            AS horas_anticipacion_recordatorio
                    FROM loteria_horarios h
                    JOIN loterias l ON l.id = h.loteria_id
                    JOIN paises p ON p.id = l.pais_id
                    WHERE h.dia_semana = :dia_semana
                      AND COALESCE(h.activo, TRUE) = TRUE
                      AND COALESCE(l.activa, TRUE) = TRUE
                      AND l.pais_id IS NOT NULL
                      AND COALESCE(NULLIF(l.timezone, ''), p.timezone_default)
                          IS NOT NULL
                    ORDER BY l.pais_id, h.hora_sorteo, l.nombre
                """),
                {"dia_semana": target_date.isoweekday()},
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

    def _already_sent(
        self,
        user_id: int,
        target_date: date,
        reminder_key: str,
    ) -> bool:
        """
        Idempotencia por usuario + fecha + ventana.

        No requiere migración de BD: reminder_key se guarda dentro de
        message_params y se consulta desde allí. Así dos sorteos del mismo día
        (p. ej. Chispazo 15:00 y 21:00) no se bloquean entre sí.
        """
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
                              AND COALESCE(
                                  message_params::jsonb ->> 'reminder_key',
                                  ''
                              ) = :reminder_key
                        )
                    """),
                    {
                        "user_id": user_id,
                        "fecha": target_date,
                        "reminder_key": reminder_key,
                    },
                ).scalar()
            )

    @staticmethod
    def _reminder_key(target_date: date, lotteries: list[dict]) -> str:
        """Clave estable para una ventana concreta de recordatorio."""
        parts = []
        for item in lotteries:
            draw_time = item.get("hora_sorteo")
            if isinstance(draw_time, time):
                draw_value = draw_time.strftime("%H:%M")
            else:
                draw_value = str(draw_time or "")
            parts.append(
                f"{int(item['id'])}:{int(item.get('horario_id') or 0)}:{draw_value}"
            )
        return f"{target_date.isoformat()}|" + "|".join(sorted(parts))

    @staticmethod
    def _message_key(names: list[str]) -> str:
        # La gramática vive en los catálogos del backend, no en Airflow.
        # Aquí solo elegimos singular/plural de forma semántica.
        return (
            "reminder.draws_today_one"
            if len(names) == 1
            else "reminder.draws_today_many"
        )

    @staticmethod
    def _local_now(timezone_name: str, now_utc: datetime) -> datetime | None:
        try:
            return now_utc.astimezone(ZoneInfo(timezone_name))
        except (ZoneInfoNotFoundError, ValueError):
            return None

    @staticmethod
    def _reminder_time(lottery: dict) -> time:
        """Hora local de envío. Fallback: 18:00 local."""
        draw_time = lottery.get("hora_sorteo")
        if draw_time is None:
            return time(18, 0)

        if isinstance(draw_time, str):
            try:
                draw_time = time.fromisoformat(draw_time)
            except ValueError:
                return time(18, 0)

        anticipation = max(
            0, int(lottery.get("horas_anticipacion_recordatorio") or 5)
        )
        base = datetime.combine(date(2000, 1, 2), draw_time)
        reminder = base - timedelta(hours=anticipation)

        # El mensaje actual dice "hoy juega". Si cae el día anterior,
        # mantenemos temporalmente el fallback de las 18:00 del día del sorteo.
        if reminder.date() != base.date():
            return time(18, 0)

        return reminder.time().replace(second=0, microsecond=0)

    @staticmethod
    def _is_reminder_window(local_now: datetime, reminder_time: time) -> bool:
        """
        El DAG corre cada hora. La ejecución de HH:00 cubre la ventana
        [HH:00, HH:59:59]. Así, un recordatorio calculado para 16:30 se
        procesa en la ejecución de las 16:00, sin perder los minutos.
        """
        return local_now.hour == reminder_time.hour

    def _scheduled_lotteries(self, now_utc: datetime) -> dict[date, list[dict]]:
        """Selecciona las loterías que están en su ventana local de envío."""
        with self.engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT DISTINCT
                        COALESCE(NULLIF(l.timezone, ''), p.timezone_default) AS timezone
                    FROM loterias l
                    JOIN paises p ON p.id = l.pais_id
                    WHERE COALESCE(l.activa, TRUE) = TRUE
                      AND COALESCE(NULLIF(l.timezone, ''), p.timezone_default)
                          IS NOT NULL
                """)
            ).mappings().all()

        local_dates: set[date] = set()
        for row in rows:
            tz_name = str(row["timezone"]).strip()
            local_now = self._local_now(tz_name, now_utc)
            if local_now is not None:
                local_dates.add(local_now.date())

        selected: dict[date, list[dict]] = defaultdict(list)
        for local_date in sorted(local_dates):
            for lottery in self._lotteries_due_on(local_date):
                tz_name = str(lottery.get("timezone") or "").strip()
                if not tz_name:
                    print(f"⚠️ Lotería {lottery.get('id')} sin timezone; se omite.")
                    continue

                local_now = self._local_now(tz_name, now_utc)
                if local_now is None:
                    print(
                        f"⚠️ Timezone inválida '{tz_name}' "
                        f"para lotería {lottery.get('id')}; se omite."
                    )
                    continue

                if local_now.date() != local_date:
                    continue
                reminder_time = self._reminder_time(lottery)
                if not self._is_reminder_window(local_now, reminder_time):
                    continue
                lottery["horario_especial"] = True
                selected[local_date].append(lottery)

        return selected

    def _print_dry_run_diagnostics(
        self,
        now_utc: datetime,
        scheduled: dict[date, list[dict]],
    ) -> None:
        """Muestra qué loterías entraron en la ventana sin depender de usuarios."""
        print("\n🔎 DIAGNÓSTICO DE VENTANAS")
        total = 0

        for local_date, lotteries in sorted(scheduled.items()):
            for lottery in lotteries:
                tz_name = str(lottery.get("timezone") or "").strip()
                local_now = self._local_now(tz_name, now_utc)
                if local_now is None:
                    continue

                reminder_time = self._reminder_time(lottery)
                draw_time = lottery.get("hora_sorteo")
                anticipation = int(
                    lottery.get("horas_anticipacion_recordatorio") or 5
                )

                print(
                    f"🌍 {lottery.get('pais_nombre') or 'País'} "
                    f"(id={lottery.get('pais_id')})"
                )
                print(
                    f"   🎟️ {lottery.get('nombre')} "
                    f"(loteria_id={lottery.get('id')})"
                )
                print(f"   🕒 timezone: {tz_name}")
                print(
                    f"   📅 local: "
                    f"{local_now.strftime('%Y-%m-%d %H:%M:%S %z')}"
                )
                schedule_name = lottery.get("nombre_sorteo")
                source = "loteria_horarios"
                print(
                    f"   ⏰ recordatorio calculado: "
                    f"{reminder_time.strftime('%H:%M')} "
                    f"| hora_sorteo={draw_time or 'NULL'} "
                    f"| anticipación={anticipation}h "
                    f"| fuente={source}"
                )
                if schedule_name:
                    print(f"   🏷️ horario: {schedule_name}")
                print("   ✅ Ventana activa")
                total += 1

        if total == 0:
            print("   ℹ️ Ninguna lotería está en ventana en esta hora.")
        else:
            print(f"\n🧪 Loterías en ventana: {total}")

    def run(
        self,
        target_date: date | None = None,
        force: bool = False,
        dry_run: bool = False,
        simulate_utc: datetime | None = None,
    ) -> None:
        # Modo manual/diagnóstico: --date procesa esa fecha inmediatamente.
        if target_date is not None:
            lotteries = self._lotteries_due_on(target_date)
            if not lotteries:
                print(f"ℹ️ No se detectaron sorteos para {target_date}.")
                return
            self._send_reminders(target_date, lotteries, force, dry_run)
            return

        # Modo automático: Airflow corre cada hora en UTC y aquí se decide
        # qué países/loterías están en su hora local de recordatorio.
        now_utc = simulate_utc or datetime.now(ZoneInfo("UTC"))
        if now_utc.tzinfo is None:
            now_utc = now_utc.replace(tzinfo=ZoneInfo("UTC"))
        else:
            now_utc = now_utc.astimezone(ZoneInfo("UTC"))

        if simulate_utc is not None:
            print(f"🧪 Hora UTC simulada: {now_utc.isoformat(timespec='seconds')}")
        if dry_run:
            print("🛡️ DRY-RUN activo: NO se enviará ninguna notificación.")
        scheduled = self._scheduled_lotteries(now_utc)

        if dry_run:
            self._print_dry_run_diagnostics(now_utc, scheduled)

        if not scheduled:
            print(
                f"ℹ️ Sin recordatorios en esta ventana. "
                f"UTC={now_utc.isoformat(timespec='seconds')}"
            )
            return

        for local_date, lotteries in sorted(scheduled.items()):
            self._send_reminders(local_date, lotteries, force, dry_run)

    def _send_reminders(
        self,
        target_date: date,
        lotteries: list[dict],
        force: bool = False,
        dry_run: bool = False,
    ) -> None:
        by_country: dict[int, list[dict]] = defaultdict(list)
        for lottery in lotteries:
            by_country[int(lottery["pais_id"])].append(lottery)

        users = self._users_for_countries(sorted(by_country))
        if not users:
            if dry_run:
                for pais_id, country_lotteries in sorted(by_country.items()):
                    pais_nombre = (
                        country_lotteries[0].get("pais_nombre") or "País"
                    )
                    names = ", ".join(
                        str(item["nombre"]) for item in country_lotteries
                    )
                    print(
                        f"👤 {pais_nombre} (id={pais_id}) "
                        f"| usuarios habilitados=0 "
                        f"| loterías={names}"
                    )
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

            reminder_key = self._reminder_key(target_date, country_lotteries)
            if not force and self._already_sent(
                user_id, target_date, reminder_key
            ):
                skipped += 1
                continue

            names = list(
                dict.fromkeys(str(item["nombre"]) for item in country_lotteries)
            )
            message_key = self._message_key(names)

            if dry_run:
                print(
                    f"🧪 DRY-RUN | user_id={user_id} | país={pais_id} "
                    f"| fecha={target_date} | loterías={', '.join(names)} "
                    "| NO ENVIADO"
                )
                sent += 1
                continue

            try:
                response = self.client.publish(
                    loteria_id=int(country_lotteries[0]["id"]),
                    fecha_sorteo=target_date,
                    mensaje=(
                        f"🎟️ {', '.join(names)} draw today. "
                        "Check your analyses and plays in Eterlotto."
                    ),
                    message_key=message_key,
                    message_params={
                        "lotteries": names,
                        "reminder_key": reminder_key,
                    },
                    tipo="recordatorio_sorteos_hoy",
                    user_id=user_id,
                )
                push = response.get("push") or {}
                print(
                    f"✅ user_id={user_id} | país={pais_id} "
                    f"| fecha={target_date} | loterías={len(names)} "
                    f"| sent={push.get('sent', 0)}"
                )
                sent += 1
            except Exception as exc:
                print(f"⚠️ user_id={user_id}: {exc}")
                failed += 1

        if dry_run:
            print(
                f"🧪 DRY-RUN {target_date}: simulados={sent}, "
                f"enviados=0, omitidos={skipped}, fallidos={failed}"
            )
        else:
            print(
                f"📨 Recordatorios {target_date}: enviados={sent}, "
                f"omitidos={skipped}, fallidos={failed}"
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Recordatorio diario de sorteos por país"
    )
    parser.add_argument(
        "--date",
        help="Fecha YYYY-MM-DD. Si se indica, procesa esa fecha inmediatamente.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignora idempotencia; solo para pruebas.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Muestra lo que se enviaría sin llamar al backend.",
    )
    parser.add_argument(
        "--simulate-utc",
        help="Simula una hora UTC ISO, por ejemplo 2026-10-01T23:00:00.",
    )
    args = parser.parse_args()

    target = (
        datetime.strptime(args.date, "%Y-%m-%d").date()
        if args.date
        else None
    )
    simulated = None
    if args.simulate_utc:
        simulated = datetime.fromisoformat(
            args.simulate_utc.replace("Z", "+00:00")
        )
        if simulated.tzinfo is None:
            simulated = simulated.replace(tzinfo=ZoneInfo("UTC"))

    DailyLotteryReminder().run(
        target,
        force=args.force,
        dry_run=args.dry_run,
        simulate_utc=simulated,
    )
