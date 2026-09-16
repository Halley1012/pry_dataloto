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

def ejecutar_megasena():
    from main_megasena import main as main_megasena
    main_megasena()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Mega-Sena ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Mega-Sena (Brasil) finalizada con éxito</h3>\n    <p>El proceso de scraping, predicción y notificaciones en <b>main_megasena.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_megasena',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Mega-Sena usando main_megasena.py',
    schedule='0 3 * * *', # Domingos, Miércoles y Viernes a las 3:00 AM (tras sorteos de Sáb, Mar y Jue)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'megasena', 'brasil', 'brazil', 'ml']
) as dag:

    tarea_ejecutar_megasena = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_megasena',
        python_callable=ejecutar_megasena
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_megasena >> tarea_notificar_exito
