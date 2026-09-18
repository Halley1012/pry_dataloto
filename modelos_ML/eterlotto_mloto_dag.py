import sys
from pathlib import Path
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

# Aseguramos que la carpeta modelos_ML esté en el sys.path
MODELOS_ML_DIR = str(Path(__file__).resolve().parent)
if MODELOS_ML_DIR not in sys.path:
    sys.path.insert(0, MODELOS_ML_DIR)

from config.airflow_runtime import configure_airflow_runtime
from config.airflow_notifications import (
    send_airflow_failure_notification,
    send_email_notification,
)

configure_airflow_runtime(MODELOS_ML_DIR)

def ejecutar_mloto():
    from main_mloto import main as main_mloto
    main_mloto()
    # ETERLOTTO_CACHE_INVALIDATION_V1
    from config.backend_cache_invalidation import invalidar_cache_backend
    invalidar_cache_backend()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG MiLoto ejecutado exitosamente',
        html_body='\n    <h3>Ejecución de MiLoto finalizada con éxito</h3>\n    <p>El proceso de scraping y predicción en <b>main_mloto.py</b> concluyó correctamente.</p>\n    ',
    )

def enviar_notificacion_error(context):
    return send_airflow_failure_notification(context)

# Configuración por defecto para las tareas del DAG
default_args = {
    'owner': 'eterlotto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(minutes=20),
    'on_failure_callback': enviar_notificacion_error,
}

# Definición del DAG para MiLoto
with DAG(
    'eterlotto_ejecucion_mloto',
    default_args=default_args,
    description='Ejecuta scraping y predicción de MiLoto usando main_mloto.py',
    schedule='0 3 * * *',  # Martes a Sábado a las 3:00 AM (2=Martes, 6=Sábado)
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['eterlotto', 'ml', 'miloto'],
) as dag:

    tarea_ejecutar_mloto = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_mloto',
        python_callable=ejecutar_mloto,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_mloto >> tarea_notificar_exito
