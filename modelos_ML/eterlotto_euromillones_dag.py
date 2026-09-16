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

def ejecutar_euromillones():
    from main_euromillones import main as main_euromillones
    main_euromillones()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Euromillones ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Euromillones (España) finalizada con éxito</h3>\n    <p>El proceso de scraping, predicción y notificaciones en <b>main_euromillones.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_euromillones',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Euromillones usando main_euromillones.py',
    schedule='0 3 * * *', # Miércoles y Sábados a las 3:00 AM (tras sorteos de Martes y Viernes)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'euromillones', 'spain', 'ml']
) as dag:

    tarea_ejecutar_euromillones = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_euromillones',
        python_callable=ejecutar_euromillones
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_euromillones >> tarea_notificar_exito
