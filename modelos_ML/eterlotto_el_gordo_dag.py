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

def ejecutar_el_gordo():
    from main_el_gordo import main as main_el_gordo
    main_el_gordo()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG El Gordo de la Primitiva ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de El Gordo de la Primitiva (España) finalizada con éxito</h3>\n    <p>El proceso de scraping, predicción y notificaciones en <b>main_el_gordo.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_el_gordo',
    default_args=default_args,
    description='Ejecuta scraping y predicción de El Gordo de la Primitiva usando main_el_gordo.py',
    schedule='0 3 * * *', # Lunes a las 3:00 AM (tras sorteo de Domingos)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'el_gordo', 'spain', 'ml']
) as dag:

    tarea_ejecutar_el_gordo = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_el_gordo',
        python_callable=ejecutar_el_gordo
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_el_gordo >> tarea_notificar_exito
