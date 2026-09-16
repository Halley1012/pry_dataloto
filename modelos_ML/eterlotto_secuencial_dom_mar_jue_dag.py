import sys
import traceback
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

def enviar_notificacion_error(context):
    return send_airflow_failure_notification(context)

def ejecutar_bloto():
    from main_bloto import main as main_bloto
    main_bloto()

def ejecutar_double_play():
    from main_double_play import main as main_double_play
    main_double_play()

def ejecutar_lotto_america():
    from main_lotto_america import main as main_lotto_america
    main_lotto_america()

def ejecutar_powerball():
    from main_powerball import main as main_powerball
    main_powerball()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Secuencial (Dom, Mar, Jue) ejecutado exitosamente',
        html_body='\n    <h3>Ejecución Secuencial Finalizada con Éxito</h3>\n    <p>Las loterías <b>Baloto, Double Play, Lotto America y Powerball</b> concluyeron su procesamiento secuencial correctamente.</p>\n    ',
    )

# Configuración por defecto para las tareas del DAG
default_args = {
    'owner': 'eterlotto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(minutes=20),
    'on_failure_callback': enviar_notificacion_error,
}

# Definición del DAG Secuencial para Domingos, Martes y Jueves
with DAG(
    'eterlotto_ejecucion_secuencial_dom_mar_jue',
    default_args=default_args,
    description='Ejecuta secuencialmente scraping y predicción de Baloto, Double Play, Lotto America y Powerball',
    schedule='0 3 * * *',  # Domingos, Martes y Jueves a las 3:00 AM
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['eterlotto', 'ml', 'secuencial', 'dom_mar_jue'],
) as dag:

    tarea_ejecutar_bloto = PythonOperator(
        task_id='ejecutar_baloto',
        python_callable=ejecutar_bloto,
    )

    tarea_ejecutar_double_play = PythonOperator(
        task_id='ejecutar_double_play',
        python_callable=ejecutar_double_play,
    )

    tarea_ejecutar_lotto_america = PythonOperator(
        task_id='ejecutar_lotto_america',
        python_callable=ejecutar_lotto_america,
    )

    tarea_ejecutar_powerball = PythonOperator(
        task_id='ejecutar_powerball',
        python_callable=ejecutar_powerball,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_bloto >> tarea_ejecutar_double_play >> tarea_ejecutar_lotto_america >> tarea_ejecutar_powerball >> tarea_notificar_exito
