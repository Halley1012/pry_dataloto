import argparse
import re
import sys
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
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
                    SELECT
                        l.id,
                        l.nombre,
                        l.pais_id,
                        COALESCE(NULLIF(l.timezone, ''), p.timezone_default) AS timezone,
                        l.hora_sorteo,
                        COALESCE(l.horas_anticipacion_recordatorio, 5)
                            AS horas_anticipacion_recordatorio
                    FROM loterias l
                    JOIN paises p ON p.id = l.pais_id
                    WHERE l.id = ANY(:ids)
                      AND l.pais_id IS NOT NULL
                      AND COALESCE(l.activa, TRUE) = TRUE
                    ORDER BY l.pais_id, l.nombre
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
    def _reminder_hour(lottery: dict) -> int:
        """Hora local de envío. Fallback: 18:00 local."""
        draw_time = lottery.get("hora_sorteo")
        if draw_time is None:
            return 18

        if isinstance(draw_time, str):
            try:
                draw_time = time.fromisoformat(draw_time)
            except ValueError:
                return 18

        anticipation = max(
            0, int(lottery.get("horas_anticipacion_recordatorio") or 5)
        )
        base = datetime.combine(date(2000, 1, 2), draw_time)
        reminder = base - timedelta(hours=anticipation)

        # El mensaje actual dice "hoy juega". Si el cálculo cae el día anterior,
        # usamos 18:00 del día del sorteo hasta tener mensaje "mañana juega".
        if reminder.date() != base.date():
            return 18
        return reminder.hour

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
                if local_now.hour != self._reminder_hour(lottery):
                    continue

                selected[local_date].append(lottery)

        return selected

    def run(self, target_date: date | None = None, force: bool = False) -> None:
        # Modo manual/diagnóstico: --date procesa esa fecha inmediatamente.
        if target_date is not None:
            lotteries = self._lotteries_due_on(target_date)
            if not lotteries:
                print(f"ℹ️ No se detectaron sorteos para {target_date}.")
                return
            self._send_reminders(target_date, lotteries, force)
            return

        # Modo automático: Airflow corre cada hora en UTC y aquí se decide
        # qué países/loterías están en su hora local de recordatorio.
        now_utc = datetime.now(ZoneInfo("UTC"))
        scheduled = self._scheduled_lotteries(now_utc)

        if not scheduled:
            print(
                f"ℹ️ Sin recordatorios en esta ventana. "
                f"UTC={now_utc.isoformat(timespec='seconds')}"
            )
            return

        for local_date, lotteries in sorted(scheduled.items()):
            self._send_reminders(local_date, lotteries, force)

    def _send_reminders(
        self,
        target_date: date,
        lotteries: list[dict],
        force: bool = False,
    ) -> None:
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
            message_key = self._message_key(names)

            try:
                response = self.client.publish(
                    loteria_id=int(country_lotteries[0]["id"]),
                    fecha_sorteo=target_date,
                    mensaje=(
                        f"🎟️ {', '.join(names)} draw today. "
                        "Check your analyses and plays in Eterlotto."
                    ),
                    message_key=message_key,
                    message_params={"lotteries": names},
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
    args = parser.parse_args()

    target = (
        datetime.strptime(args.date, "%Y-%m-%d").date()
        if args.date
        else None
    )
    DailyLotteryReminder().run(target, force=args.force)
