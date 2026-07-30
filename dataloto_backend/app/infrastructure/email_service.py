import smtplib
from email.message import EmailMessage
from app.domain.ports import EmailSenderPort
from app.core import config

class SMTPEmailSender(EmailSenderPort):
    def send_reset_password_email(self, email: str, reset_link: str) -> bool:
        msg = EmailMessage()
        msg['Subject'] = "Recuperación de contraseña"
        msg['From'] = config.EMAIL_FROM or config.EMAIL_USER
        msg['To'] = email
        msg.set_content(f"Haz clic aquí para resetear tu contraseña:\n{reset_link}")

        try:
            with smtplib.SMTP("smtp.sendgrid.net", 587) as smtp:
                smtp.ehlo()
                smtp.starttls()
                smtp.ehlo()
                smtp.login(config.EMAIL_USER, config.EMAIL_PASS)
                smtp.send_message(msg)
            return True
        except smtplib.SMTPException as e:
            # En producción deberíamos registrar este error
            raise e
