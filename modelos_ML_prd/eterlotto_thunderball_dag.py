import sys
from pathlib import Path
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

MODELOS_ML_DIR = str(Path(__file__).resolve().parent)
if MODELOS_ML_DIR not in sys.path:
    sys.path.insert(0, MODELOS_ML_DIR)

from config.airflow_runtime import configure_airflow_runtime
from config.airflow_notifications import (
    send_airflow_failure_notification,
    send_email_notification,
)

configure_airflow_runtime(MODELOS_ML_DIR)


def ejecutar_thunderball():
    from main_thunderball import main as main_thunderball
    main_thunderball()
    # ETERLOTTO_CACHE_INVALIDATION_V1
    from config.backend_cache_invalidation import invalidar_cache_backend
    invalidar_cache_backend()


def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Thunderball ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Thunderball (Reino Unido) finalizada con éxito</h3>\n    <p>El proceso de scraping, predicción y notificaciones en <b>main_thunderball.py</b> concluyó correctamente.</p>\n    ',
    )


def enviar_notificacion_error(context):
    return send_airflow_failure_notification(context)


default_args = {
    'owner': 'eterlotto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(minutes=20),
    'on_failure_callback': enviar_notificacion_error,
}

with DAG(
    'eterlotto_ejecucion_thunderball',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Thunderball (Reino Unido) usando main_thunderball.py',
    schedule='0 3 * * 3,4,6,0',  # Miércoles, Jueves, Sábados y Domingos a las 3:00 AM UTC
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'thunderball', 'uk', 'national_lottery', 'ml']
) as dag:

    tarea_ejecutar_thunderball = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_thunderball',
        python_callable=ejecutar_thunderball
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_thunderball >> tarea_notificar_exito
