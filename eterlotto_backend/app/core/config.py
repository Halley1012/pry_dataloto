import os
from dotenv import load_dotenv

load_dotenv()

FRONTEND_URL = os.getenv("FRONTEND_URL")
RESEND_API_KEY = os.getenv("RESEND_API_KEY")
EMAIL_USER = os.getenv("EMAIL_USER")
EMAIL_PASS = os.getenv("EMAIL_PASS")
EMAIL_FROM = os.getenv("EMAIL_FROM", "Eterlotto <no-reply@lumieter.com>")
DATABASE_URL = os.getenv("DATABASE_URL")

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY no está definida en las variables de entorno")

ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "5256000")) # 10 años
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "3650")) # 10 años

EPAYCO_PUBLIC_KEY = os.getenv("EPAYCO_PUBLIC_KEY")
EPAYCO_PRIVATE_KEY = os.getenv("EPAYCO_PRIVATE_KEY")
EPAYCO_URL = "https://secure.epayco.co/"
APP_BASE_URL = os.getenv("APP_BASE_URL", "https://pry-dataloto.onrender.com")
CORS_ORIGINS = [os.getenv("FRONTEND_URL", "http://localhost:3000"), "https://pry-dataloto.onrender.com"]
if os.getenv("CORS_ORIGINS"):
    CORS_ORIGINS.extend(os.getenv("CORS_ORIGINS").split(","))

PACKAGE_NAME = os.getenv("PACKAGE_NAME", "com.lumieter.eterlotto")
_products = os.getenv("ALLOWED_PRODUCTS", "eterlotto_monthly_sub")
ALLOWED_PRODUCTS = set(_products.split(",")) if _products else {"eterlotto_monthly_sub"}

# Firebase Cloud Messaging (HTTP v1)
# Se recomienda una cuenta de servicio del mismo proyecto Firebase que usa
# android/app/google-services.json. Si no se define, el servicio push queda
# deshabilitado sin afectar el buzón interno.
FIREBASE_CREDENTIALS_B64 = os.getenv("FIREBASE_CREDENTIALS_B64")
FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")
PUSH_NOTIFICATION_TITLE = os.getenv("PUSH_NOTIFICATION_TITLE", "Eterlotto")

# Endpoint interno para que Airflow/predictores publiquen una notificación y
# disparen el push. Debe ser un secreto distinto a SECRET_KEY.
NOTIFICATION_INTERNAL_KEY = os.getenv("NOTIFICATION_INTERNAL_KEY")

# Mantener desactivado en PRD. Activarlo sólo temporalmente en DEV permite
# probar un push privado con POST /notifications/test-push.
ENABLE_NOTIFICATION_TEST_ENDPOINT = (
    os.getenv("ENABLE_NOTIFICATION_TEST_ENDPOINT", "false").strip().lower()
    in {"1", "true", "yes", "on"}
)

