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

def enviar_notificacion_error(context):
    return send_airflow_failure_notification(context)

def ejecutar_megamillions():
    from main_megamillions import main as main_megamillions
    main_megamillions()

def ejecutar_mloto():
    from main_mloto import main as main_mloto
    main_mloto()

def ejecutar_millionaire_life():
    from main_millionaire_life import main as main_millionaire_life
    main_millionaire_life()

def enviar_notificacion_exito():
    return send_email_notification(
        subject='DAG Secuencial (Mié, Sáb) ejecutado exitosamente',
        html_body='\n    <h3>Ejecución Secuencial Finalizada con Éxito</h3>\n    <p>Las loterías <b>Mega Millions, MiLoto y Millionaire for Life</b> concluyeron su procesamiento secuencial correctamente.</p>\n    ',
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

# Definición del DAG Secuencial para Miércoles y Sábados
with DAG(
    'eterlotto_ejecucion_secuencial_mie_sab',
    default_args=default_args,
    description='Ejecuta secuencialmente scraping y predicción de Mega Millions, MiLoto y Millionaire for Life',
    schedule='0 3 * * *',  # Miércoles y Sábados a las 3:00 AM
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['eterlotto', 'ml', 'secuencial', 'mie_sab'],
) as dag:

    tarea_ejecutar_megamillions = PythonOperator(
        task_id='ejecutar_megamillions',
        python_callable=ejecutar_megamillions,
    )

    tarea_ejecutar_mloto = PythonOperator(
        task_id='ejecutar_mloto',
        python_callable=ejecutar_mloto,
    )

    tarea_ejecutar_millionaire_life = PythonOperator(
        task_id='ejecutar_millionaire_life',
        python_callable=ejecutar_millionaire_life,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_megamillions >> tarea_ejecutar_mloto >> tarea_ejecutar_millionaire_life >> tarea_notificar_exito
