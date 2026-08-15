import smtplib
import asyncio
from email.message import EmailMessage
from app.domain.ports import EmailSenderPort
from app.core import config

class SMTPEmailSender(EmailSenderPort):
    async def send_reset_password_email(self, email: str, reset_link: str) -> bool:
        msg = EmailMessage()
        msg['Subject'] = "Recuperación de contraseña"
        msg['From'] = config.EMAIL_FROM or config.EMAIL_USER
        msg['To'] = email
        msg.set_content(f"Haz clic aquí para resetear tu contraseña:\n{reset_link}")

        def _send_sync():
            try:
                with smtplib.SMTP("smtp.sendgrid.net", 587) as smtp:
                    smtp.ehlo()
                    smtp.starttls()
                    smtp.ehlo()
                    smtp.login(config.EMAIL_USER, config.EMAIL_PASS)
                    smtp.send_message(msg)
                return True
            except smtplib.SMTPException as e:
                raise e

        # Ejecutar en un hilo separado para no bloquear el event loop
        return await asyncio.to_thread(_send_sync)
