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

def ejecutar_mloto():
    from main_mloto import main as main_mloto
    main_mloto()

def enviar_notificacion_exito():
    sender = "michaelhalleydelgado@gmail.com"
    password = "gukpxpfvpjutysmv"
    receiver = "michaelhalleydelgado@gmail.com"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "DAG MiLoto ejecutado exitosamente"
    msg["From"] = sender
    msg["To"] = receiver

    html = """
    <h3>Ejecución de MiLoto finalizada con éxito</h3>
    <p>El proceso de scraping y predicción en <b>main_mloto.py</b> concluyó correctamente.</p>
    """
    msg.attach(MIMEText(html, "html"))

    # Conexión directa y confiable por SMTP con STARTTLS (Puerto 587)
    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(sender, password)
        server.sendmail(sender, receiver, msg.as_string())
    
    print("📧 Correo de notificación enviado exitosamente a", receiver)

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
