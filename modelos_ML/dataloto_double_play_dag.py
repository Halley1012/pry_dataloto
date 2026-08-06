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

def ejecutar_double_play():
    from main_double_play import main as main_double_play
    main_double_play()

def enviar_notificacion_exito():
    sender = "michaelhalleydelgado@gmail.com"
    password = "gukpxpfvpjutysmv"
    receiver = "michaelhalleydelgado@gmail.com"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "DAG Double Play ejecutado exitosamente"
    msg["From"] = sender
    msg["To"] = receiver

    html = """
    <h3>Ejecución de Double Play finalizada con éxito</h3>
    <p>El proceso de scraping y predicción en <b>main_double_play.py</b> concluyó correctamente.</p>
    """
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(sender, password)
        server.sendmail(sender, receiver, msg.as_string())
    
    print("📧 Correo de notificación enviado exitosamente a", receiver)

default_args = {
    'owner': 'dataloto',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'dataloto_ejecucion_double_play',
    default_args=default_args,
    description='Ejecuta scraping y predicción de Double Play usando main_double_play.py',
    schedule='0 3 * * 2,4,7', # Martes, Jueves y Domingo
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=['dataloto', 'ml', 'double_play'],
) as dag:

    tarea_ejecutar_double_play = PythonOperator(
        task_id='ejecutar_scraping_y_prediccion_double_play',
        python_callable=ejecutar_double_play,
    )

    tarea_notificar_exito = PythonOperator(
        task_id='notificar_exito',
        python_callable=enviar_notificacion_exito,
    )

    tarea_ejecutar_double_play >> tarea_notificar_exito
