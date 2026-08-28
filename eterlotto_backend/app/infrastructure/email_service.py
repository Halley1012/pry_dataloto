import smtplib
import asyncio
import logging
from email.message import EmailMessage
import httpx
from app.domain.ports import EmailSenderPort
from app.core import config

logger = logging.getLogger(__name__)

RESET_PASSWORD_HTML = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recuperación de Contraseña</title>
</head>
<body style="margin: 0; padding: 20px; background-color: #121212; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #1E1E1E; border-radius: 16px; border: 1px solid #2E2E2E; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.5);">
    <!-- Header -->
    <tr>
      <td align="center" style="padding: 35px 20px 20px 20px;">
        <h1 style="margin: 0; font-size: 26px; font-weight: 800; color: #FFC107; letter-spacing: 2px;">✦ ETERLOTTO ✦</h1>
        <p style="margin: 5px 0 0 0; font-size: 13px; color: #888888; text-transform: uppercase; letter-spacing: 1px;">Inteligencia Artificial para Loterías</p>
      </td>
    </tr>
    <!-- Content -->
    <tr>
      <td style="padding: 10px 30px 30px 30px; text-align: center;">
        <h2 style="margin: 0 0 15px 0; font-size: 20px; color: #FFFFFF; font-weight: 600;">Código de Recuperación</h2>
        <p style="margin: 0 0 25px 0; font-size: 15px; color: #CCCCCC; line-height: 1.6;">
          Has solicitado restablecer la contraseña de tu cuenta. Ingresa el siguiente código de 6 dígitos en la aplicación:
        </p>
        
        <!-- Code Display -->
        <div style="background-color: #2C2F38; border: 2px dashed #FFC107; border-radius: 12px; padding: 18px 24px; display: inline-block; margin-bottom: 25px;">
          <span style="font-family: monospace, 'Courier New', Courier; font-size: 34px; font-weight: 900; color: #FFC107; letter-spacing: 10px;">{code}</span>
        </div>
        
        <p style="margin: 0; font-size: 13px; color: #999999; line-height: 1.5;">
          ⏱️ Este código es válido durante <strong>15 minutos</strong>.<br>
          Si no solicitaste este cambio, puedes ignorar este mensaje de forma segura.
        </p>
      </td>
    </tr>
    <!-- Footer -->
    <tr>
      <td align="center" style="background-color: #181818; padding: 20px; border-top: 1px solid #2E2E2E;">
        <p style="margin: 0; font-size: 12px; color: #666666;">
          © Lumieter • Todos los derechos reservados.<br>
          <a href="https://lumieter.com" style="color: #FFC107; text-decoration: none;">lumieter.com</a>
        </p>
      </td>
    </tr>
  </table>
</body>
</html>
"""

VERIFICATION_HTML = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verificación de Correo</title>
</head>
<body style="margin: 0; padding: 20px; background-color: #121212; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #FFFFFF;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #1E1E1E; border-radius: 16px; border: 1px solid #2E2E2E; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.5);">
    <!-- Header -->
    <tr>
      <td align="center" style="padding: 35px 20px 20px 20px;">
        <h1 style="margin: 0; font-size: 26px; font-weight: 800; color: #FFC107; letter-spacing: 2px;">✦ ETERLOTTO ✦</h1>
        <p style="margin: 5px 0 0 0; font-size: 13px; color: #888888; text-transform: uppercase; letter-spacing: 1px;">Inteligencia Artificial para Loterías</p>
      </td>
    </tr>
    <!-- Content -->
    <tr>
      <td style="padding: 10px 30px 30px 30px; text-align: center;">
        <h2 style="margin: 0 0 15px 0; font-size: 20px; color: #FFFFFF; font-weight: 600;">¡Bienvenido a Eterlotto!</h2>
        <p style="margin: 0 0 25px 0; font-size: 15px; color: #CCCCCC; line-height: 1.6;">
          Para validar tu cuenta y verificar tu correo electrónico, ingresa el siguiente código en la app:
        </p>
        
        <!-- Code Display -->
        <div style="background-color: #2C2F38; border: 2px dashed #FFC107; border-radius: 12px; padding: 18px 24px; display: inline-block; margin-bottom: 25px;">
          <span style="font-family: monospace, 'Courier New', Courier; font-size: 34px; font-weight: 900; color: #FFC107; letter-spacing: 10px;">{code}</span>
        </div>
        
        <p style="margin: 0; font-size: 13px; color: #999999; line-height: 1.5;">
          ⏱️ Este código es válido por <strong>24 horas</strong>.
        </p>
      </td>
    </tr>
    <!-- Footer -->
    <tr>
      <td align="center" style="background-color: #181818; padding: 20px; border-top: 1px solid #2E2E2E;">
        <p style="margin: 0; font-size: 12px; color: #666666;">
          © Lumieter • Todos los derechos reservados.<br>
          <a href="https://lumieter.com" style="color: #FFC107; text-decoration: none;">lumieter.com</a>
        </p>
      </td>
    </tr>
  </table>
</body>
</html>
"""

class ResendEmailSender(EmailSenderPort):
    """
    Servicio de envío de correos que utiliza Resend API (HTTP REST) como proveedor principal,
    con fallback a SMTP estándar si no se ha configurado RESEND_API_KEY.
    """

    async def _send_via_resend(self, to_email: str, subject: str, html_content: str, text_content: str) -> bool:
        url = "https://api.resend.com/emails"
        from_email = config.EMAIL_FROM or "Eterlotto <no-reply@lumieter.com>"
        headers = {
            "Authorization": f"Bearer {config.RESEND_API_KEY.strip()}",
            "Content-Type": "application/json"
        }
        payload = {
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "html": html_content,
            "text": text_content
        }

        print(f"📧 [Resend] Enviando correo a {to_email} desde '{from_email}'...")
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code in [200, 201]:
                res_data = response.json()
                print(f"✅ [Resend] Correo enviado exitosamente a {to_email} (id: {res_data.get('id')})")
                return True
            else:
                print(f"❌ [Resend Error {response.status_code}]: {response.text}")
                logger.error(f"❌ Error al enviar correo vía Resend ({response.status_code}): {response.text}")
                return False

    async def _send_via_smtp(self, to_email: str, subject: str, html_content: str, text_content: str) -> bool:
        msg = EmailMessage()
        msg['Subject'] = subject
        msg['From'] = config.EMAIL_FROM or config.EMAIL_USER
        msg['To'] = to_email
        msg.set_content(text_content)
        msg.add_alternative(html_content, subtype='html')

        def _send_sync():
            try:
                smtp_server = "smtp.sendgrid.net"
                with smtplib.SMTP(smtp_server, 587, timeout=10.0) as smtp:
                    smtp.ehlo()
                    smtp.starttls()
                    smtp.ehlo()
                    smtp.login(config.EMAIL_USER, config.EMAIL_PASS)
                    smtp.send_message(msg)
                print(f"✅ [SMTP] Correo enviado a {to_email}")
                return True
            except Exception as e:
                print(f"❌ [SMTP Error]: {e}")
                logger.error(f"❌ Error al enviar correo vía SMTP: {e}")
                return False

        return await asyncio.to_thread(_send_sync)

    async def _send_email(self, to_email: str, subject: str, html_content: str, text_content: str) -> bool:
        if config.RESEND_API_KEY:
            return await self._send_via_resend(to_email, subject, html_content, text_content)
        elif config.EMAIL_USER and config.EMAIL_PASS:
            return await self._send_via_smtp(to_email, subject, html_content, text_content)
        else:
            print(f"⚠️ [Resend/Email Warning] No se encontró RESEND_API_KEY ni credenciales SMTP en las variables de entorno.")
            print(f"📧 [SIMULADO] Para: {to_email} | Asunto: {subject}\n{text_content}")
            return True

    async def send_reset_password_code(self, email: str, code: str) -> bool:
        subject = f"Tu código de recuperación de contraseña: {code} - Eterlotto"
        html = RESET_PASSWORD_HTML.replace("{code}", code)
        text = f"Eterlotto - Recuperación de Contraseña\n\nTu código de recuperación es: {code}\nEste código es válido durante 15 minutos.\n\n© Lumieter"
        return await self._send_email(email, subject, html, text)

    async def send_verification_code(self, email: str, code: str) -> bool:
        subject = f"Tu código de verificación de Eterlotto: {code}"
        html = VERIFICATION_HTML.replace("{code}", code)
        text = f"Eterlotto - Verificación de Correo\n\nTu código de verificación es: {code}\nEste código es válido por 24 horas.\n\n© Lumieter"
        return await self._send_email(email, subject, html, text)

    async def send_reset_password_email(self, email: str, reset_link: str) -> bool:
        subject = "Recuperación de contraseña - Eterlotto"
        html = RESET_PASSWORD_HTML.replace("{code}", "ENLACE").replace("Ingresa el siguiente código de 6 dígitos en la aplicación:", f"<a href='{reset_link}' style='color:#FFC107;'>Haz clic aquí para restablecer tu contraseña</a>")
        text = f"Eterlotto - Recuperación de contraseña:\nHaz clic aquí: {reset_link}"
        return await self._send_email(email, subject, html, text)

# Alias para compatibilidad con código existente
SMTPEmailSender = ResendEmailSender
