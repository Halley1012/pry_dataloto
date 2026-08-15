import sys
import glob
import site
import smtplib
import traceback
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

# Cargar las librerías del entorno virtual .venv_airflow si existe
venv_sites = glob.glob("/opt/airflow/pry_dataloto/modelos_ML/.venv_airflow/lib/python*/site-packages")
for venv_site in venv_sites:
    site.addsitedir(venv_site)

# Aseguramos que la carpeta modelos_ML esté en el sys.path
MODELOS_ML_DIR = str(Path(__file__).resolve().parent)
if MODELOS_ML_DIR not in sys.path:
    sys.path.insert(0, MODELOS_ML_DIR)

if "/opt/airflow/pry_dataloto/modelos_ML" not in sys.path:
    sys.path.insert(0, "/opt/airflow/pry_dataloto/modelos_ML")

def enviar_notificacion_error(context):
    sender = "michaelhalleydelgado@gmail.com"
    password = "gukpxpfvpjutysmv"
    receiver = "michaelhalleydelgado@gmail.com"

    task_instance = context.get('task_instance')
    task_id = task_instance.task_id if task_instance else 'Desconocida'
    dag_id = context.get('dag').dag_id if context.get('dag') else 'Desconocido'
    exception = context.get('exception', 'Error desconocido o Timeout (> 20 min)')
    execution_date = context.get('execution_date', datetime.now())

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"⚠️ ALERTA: Fallo o Timeout en DAG {dag_id} (Tarea: {task_id})"
    msg["From"] = sender
    msg["To"] = receiver

    html = f"""
    <h3>⚠️ Alerta de Ejecución en Airflow</h3>
    <p>Se ha detectado un fallo o sobrepaso del tiempo límite (20 minutos) en la tarea <b>{task_id}</b> del DAG <b>{dag_id}</b>.</p>
    <ul>
        <li><b>Fecha de Ejecución:</b> {execution_date}</li>
        <li><b>Tarea:</b> {task_id}</li>
        <li><b>Detalle / Excepción:</b> {exception}</li>
    </ul>
    <p>Por favor, revisa los logs de Airflow para más información.</p>
    """
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.starttls()
            server.login(sender, password)
            server.sendmail(sender, receiver, msg.as_string())
        print(f"📧 Correo de alerta de error enviado a {receiver}")
    except Exception as e:
        print(f"❌ Error enviando correo de alerta: {e}")

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
    sender = "michaelhalleydelgado@gmail.com"
    password = "gukpxpfvpjutysmv"
    receiver = "michaelhalleydelgado@gmail.com"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "DAG Secuencial (Dom, Mar, Jue) ejecutado exitosamente"
    msg["From"] = sender
    msg["To"] = receiver

    html = """
    <h3>Ejecución Secuencial Finalizada con Éxito</h3>
    <p>Las loterías <b>Baloto, Double Play, Lotto America y Powerball</b> concluyeron su procesamiento secuencial correctamente.</p>
    """
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(sender, password)
        server.sendmail(sender, receiver, msg.as_string())
    
    print("📧 Correo de notificación de éxito enviado exitosamente a", receiver)

# Configuración por defecto para las tareas del DAG
default_args = {
    'owner': 'dataloto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(minutes=20),
    'on_failure_callback': enviar_notificacion_error,
}

# Definición del DAG Secuencial para Domingos, Martes y Jueves
with DAG(
    'dataloto_ejecucion_secuencial_dom_mar_jue',
    default_args=default_args,
    description='Ejecuta secuencialmente scraping y predicción de Baloto, Double Play, Lotto America y Powerball',
    schedule='0 3 * * 0,2,4',  # Domingos, Martes y Jueves a las 3:00 AM
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['dataloto', 'ml', 'secuencial', 'dom_mar_jue'],
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
