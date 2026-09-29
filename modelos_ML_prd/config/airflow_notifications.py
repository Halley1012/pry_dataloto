"""Notificaciones de Airflow sin credenciales codificadas en los DAGs."""

from __future__ import annotations

import html
import os
import smtplib
from dataclasses import dataclass
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Importar settings carga el archivo .env del ambiente seleccionado.
from config.settings import settings  # noqa: F401


def _as_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on", "si", "sí"}


@dataclass(frozen=True)
class SmtpConfig:
    enabled: bool
    host: str
    port: int
    starttls: bool
    username: str | None
    password: str | None
    sender: str | None
    receiver: str | None

    @property
    def configured(self) -> bool:
        return bool(self.username and self.password and self.sender and self.receiver)


def load_smtp_config() -> SmtpConfig:
    username = os.getenv("SMTP_USER", "").strip() or None
    sender = os.getenv("SMTP_FROM", "").strip() or username
    receiver = os.getenv("SMTP_TO", "").strip() or sender

    raw_port = os.getenv("SMTP_PORT", "587").strip()
    try:
        port = int(raw_port)
    except ValueError:
        port = 587

    return SmtpConfig(
        enabled=_as_bool("SMTP_ENABLED", True),
        host=os.getenv("SMTP_HOST", "smtp.gmail.com").strip() or "smtp.gmail.com",
        port=port,
        starttls=_as_bool("SMTP_STARTTLS", True),
        username=username,
        password=os.getenv("SMTP_PASSWORD", "").strip() or None,
        sender=sender,
        receiver=receiver,
    )


def send_email_notification(*, subject: str, html_body: str) -> bool:
    """Envía una notificación. Si SMTP no está configurado, no rompe el DAG."""
    cfg = load_smtp_config()

    if not cfg.enabled:
        print("ℹ️ Notificación SMTP deshabilitada (SMTP_ENABLED=false).")
        return False

    if not cfg.configured:
        print(
            "⚠️ Notificación SMTP omitida: configura SMTP_USER, SMTP_PASSWORD "
            "y opcionalmente SMTP_FROM/SMTP_TO."
        )
        return False

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = cfg.sender
    msg["To"] = cfg.receiver
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        with smtplib.SMTP(cfg.host, cfg.port, timeout=30) as server:
            if cfg.starttls:
                server.starttls()
            if cfg.username and cfg.password:
                server.login(cfg.username, cfg.password)
            server.sendmail(cfg.sender, [cfg.receiver], msg.as_string())
        print(f"📧 Notificación enviada a {cfg.receiver}")
        return True
    except Exception as exc:
        # Las notificaciones son observabilidad; no deben ocultar el estado real
        # del scraping/predictor ni provocar un segundo fallo en el callback.
        print(f"⚠️ No se pudo enviar la notificación SMTP: {exc}")
        return False


def send_airflow_failure_notification(context: dict) -> bool:
    task_instance = context.get("task_instance")
    task_id = task_instance.task_id if task_instance else "Desconocida"
    dag = context.get("dag")
    dag_id = dag.dag_id if dag else "Desconocido"
    exception = context.get("exception", "Error desconocido o timeout")
    execution_date = context.get("logical_date") or context.get("execution_date") or "Desconocida"

    safe_task = html.escape(str(task_id))
    safe_dag = html.escape(str(dag_id))
    safe_exception = html.escape(str(exception))
    safe_date = html.escape(str(execution_date))

    return send_email_notification(
        subject=f"⚠️ ALERTA: Fallo en DAG {dag_id} (Tarea: {task_id})",
        html_body=f"""
        <h3>⚠️ Alerta de ejecución en Airflow</h3>
        <p>Se detectó un fallo o timeout en la tarea <b>{safe_task}</b>
        del DAG <b>{safe_dag}</b>.</p>
        <ul>
            <li><b>Fecha de ejecución:</b> {safe_date}</li>
            <li><b>Tarea:</b> {safe_task}</li>
            <li><b>Detalle / excepción:</b> {safe_exception}</li>
        </ul>
        <p>Revisa los logs de Airflow para más información.</p>
        """,
    )
