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


def ejecutar_totoloto():
    from main_totoloto import main as main_totoloto
    main_totoloto()


def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Totoloto ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de Totoloto (Portugal) finalizada con éxito</h3>\n    <p>El proceso de scraping, predicción y notificaciones en <b>main_totoloto.py</b> concluyó correctamente.</p>\n    ',
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
    'eterlotto_ejecucion_totoloto',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Totoloto (Portugal) usando main_totoloto.py',
    schedule='0 3 * * 4,0',  # Jueves y Domingos a las 3:00 AM (tras sorteos de Miércoles y Sábados)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'totoloto', 'portugal', 'scml', 'ml']
) as dag:

    tarea_ejecutar_totoloto = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_totoloto',
        python_callable=ejecutar_totoloto
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_totoloto >> tarea_notificar_exito
