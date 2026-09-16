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

def ejecutar_kabala():
    from main_kabala import main as main_kabala
    main_kabala()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Kábala ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Kábala (Perú) finalizada con éxito</h3>\n    <p>El proceso de scraping, predicción y notificaciones en <b>main_kabala.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_kabala',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Kábala usando main_kabala.py',
    schedule='0 3 * * *', # Miércoles, Viernes y Domingos a las 3:00 AM (tras sorteos de Martes, Jueves y Sábados)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'kabala', 'peru', 'pe', 'ml']
) as dag:

    tarea_ejecutar_kabala = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_kabala',
        python_callable=ejecutar_kabala
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_kabala >> tarea_notificar_exito
