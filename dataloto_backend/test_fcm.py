import firebase_admin
from firebase_admin import credentials, messaging
from pathlib import Path
import os
import sys

# Ruta al archivo de credenciales
# Ajustar según donde lo pusiste
CRED_PATH = Path("D:/pry_dataloto/modelos_ML/config/firebase_credentials.json")

def test_push(token):
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(str(CRED_PATH))
            firebase_admin.initialize_app(cred)
        
        message = messaging.Message(
            notification=messaging.Notification(
                title='🚀 Prueba DataLoto',
                body='Si ves esto, las notificaciones push están funcionando correctamente.',
            ),
            token=token,
        )
        
        response = messaging.send(message)
        print('✅ Mensaje enviado exitosamente:', response)
    except Exception as e:
        print('❌ Error enviando mensaje:', str(e))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python test_fcm.py <FCM_TOKEN>")
        sys.exit(1)
    
    target_token = sys.argv[1]
    test_push(target_token)
