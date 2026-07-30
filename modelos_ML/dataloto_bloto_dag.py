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

def ejecutar_bloto():
    from main_bloto import main as main_bloto
    main_bloto()

def enviar_notificacion_exito():
    sender = "michaelhalleydelgado@gmail.com"
    password = "gukpxpfvpjutysmv"
    receiver = "michaelhalleydelgado@gmail.com"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "DAG Baloto ejecutado exitosamente"
    msg["From"] = sender
    msg["To"] = receiver

    html = """
    <h3>Ejecución de Baloto finalizada con éxito</h3>
    <p>El proceso de scraping y predicción en <b>main_bloto.py</b> concluyó correctamente.</p>
    """
    msg.attach(MIMEText(html, "html"))

    # Conexión directa y confiable por SMTP con STARTTLS (Puerto 587)
    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(sender, password)
        server.sendmail(sender, receiver, msg.as_string())
    
    print("📧 Correo de notificación enviado exitosamente a", receiver)

# Configuración por defecto para las tareas del DAG
default_args = {
    'owner': 'dataloto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Definición del DAG para Baloto
with DAG(
    'dataloto_ejecucion_bloto',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Baloto usando main_bloto.py',
    schedule='0 3 * * 0,2,4',  # Domingos, Martes y Jueves a las 3:00 AM (0=Domingo, 2=Martes, 4=Jueves)
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['dataloto', 'ml', 'baloto'],
) as dag:

    tarea_ejecutar_bloto = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_bloto',
        python_callable=ejecutar_bloto,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_bloto >> tarea_notificar_exito
