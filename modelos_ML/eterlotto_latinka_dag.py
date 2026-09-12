import sys
import glob
import site
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

venv_sites = glob.glob("/opt/airflow/pry_dataloto/modelos_ML/.venv_airflow/lib/python*/site-packages")
for venv_site in venv_sites:
    site.addsitedir(venv_site)

MODELOS_ML_DIR = str(Path(__file__).resolve().parent)
if MODELOS_ML_DIR not in sys.path:
    sys.path.insert(0, MODELOS_ML_DIR)

if "/opt/airflow/pry_dataloto/modelos_ML" not in sys.path:
    sys.path.insert(0, "/opt/airflow/pry_dataloto/modelos_ML")

def ejecutar_latinka():
    from main_latinka import main as main_latinka
    main_latinka()

def enviar_notificacion_exito():
    sender = "michaelhalleydelgado@gmail.com"
    password = "gukpxpfvpjutysmv"
    receiver = "michaelhalleydelgado@gmail.com"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "DAG La Tinka ejecutado exitosamente"
    msg["From"] = sender
    msg["To"] = receiver

    html = """
    <h3>Ejecución de La Tinka (Perú) finalizada con éxito</h3>
    <p>El proceso de scraping, predicción y notificaciones en <b>main_latinka.py</b> concluyó correctamente.</p>
    """
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.starttls()
            server.login(sender, password)
            server.sendmail(sender, receiver, msg.as_string())
        print("📧 Correo de notificación enviado exitosamente a", receiver)
    except Exception as e:
        print(f"⚠️ Error enviando correo de éxito: {e}")

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
    <h3>⚠️ Alerta de Ejecución en Airflow - La Tinka</h3>
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

default_args = {
    'owner': 'eterlotto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(minutes=20),
    'on_failure_callback': enviar_notificacion_error,
}

with DAG(
    'eterlotto_ejecucion_latinka',
    default_args=default_args,
    description='Ejecuta scraping y predicción de La Tinka usando main_latinka.py',
    schedule='0 3 * * *', # Jueves y Lunes a las 3:00 AM (tras sorteos de Miércoles y Domingo)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['eterlotto', 'latinka', 'tinka', 'peru', 'pe', 'ml']
) as dag:

    tarea_ejecutar_latinka = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_latinka',
        python_callable=ejecutar_latinka
    )

    tarea_notificar_exito = PythonOperator(
        task_id='enviar_notificacion_exito',
        python_callable=enviar_notificacion_exito
    )

    tarea_ejecutar_latinka >> tarea_notificar_exito
