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

def ejecutar_lotto_america():
    from main_lotto_america import main as main_lotto_america
    main_lotto_america()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Lotto America ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Lotto America finalizada con éxito</h3>\n    <p>El proceso de scraping y predicción en <b>main_lotto_america.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_lotto_america',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Lotto America usando main_lotto_america.py',
    schedule='0 3 * * *', # Martes, Jueves y Domingos
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['eterlotto', 'ml', 'lotto_america'],
) as dag:

    tarea_ejecutar_lotto_america = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_lotto_america',
        python_callable=ejecutar_lotto_america,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_lotto_america >> tarea_notificar_exito
