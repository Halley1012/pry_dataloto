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

def ejecutar_millionaire_life():
    from main_millionaire_life import main as main_millionaire_life
    main_millionaire_life()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Millionaire for Life ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Millionaire for Life finalizada con éxito</h3>\n    <p>El proceso de scraping y predicción en <b>main_millionaire_life.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_millionaire_life',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Millionaire for Life usando main_millionaire_life.py',
    schedule='0 3 * * *', # Diario a las 3:00 AM
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['eterlotto', 'ml', 'millionaire_life'],
) as dag:

    tarea_ejecutar_millionaire_life = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_millionaire_life',
        python_callable=ejecutar_millionaire_life,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_millionaire_life >> tarea_notificar_exito
