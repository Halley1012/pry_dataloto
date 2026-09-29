import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.python import PythonOperator


MODELOS_ML_DIR = str(Path(__file__).resolve().parent)
if MODELOS_ML_DIR not in sys.path:
    sys.path.insert(0, MODELOS_ML_DIR)

from config.airflow_runtime import configure_airflow_runtime
from config.airflow_notifications import send_airflow_failure_notification

configure_airflow_runtime(MODELOS_ML_DIR)


def ejecutar_recordatorios_diarios():
    from src.daily_lottery_reminder import DailyLotteryReminder
    DailyLotteryReminder().run()


default_args = {
    "owner": "eterlotto",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=10),
    "execution_timeout": timedelta(minutes=20),
    "on_failure_callback": send_airflow_failure_notification,
}


with DAG(
    "eterlotto_recordatorios_sorteos_diarios",
    default_args=default_args,
    description="Envía un recordatorio diario por usuario con los sorteos de su país",
    # Configurable para DEV/PRD. Si no se define, 13:00 UTC (~08:00 Colombia).
    schedule=os.getenv("DAILY_REMINDER_CRON", "0 13 * * *"),
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["eterlotto", "notifications", "reminders"],
) as dag:
    recordar_sorteos = PythonOperator(
        task_id="enviar_recordatorios_sorteos_hoy",
        python_callable=ejecutar_recordatorios_diarios,
    )
