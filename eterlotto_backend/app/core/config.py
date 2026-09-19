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
# Sesiones cortas por defecto. Render puede sobreescribir estos valores por ambiente.
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "90"))

EPAYCO_PUBLIC_KEY = os.getenv("EPAYCO_PUBLIC_KEY")
EPAYCO_PRIVATE_KEY = os.getenv("EPAYCO_PRIVATE_KEY")
EPAYCO_URL = "https://secure.epayco.co/"

# Identidad del ambiente. No se utiliza una URL DEV como fallback de PRD.
APP_ENV = os.getenv("APP_ENV", "dev").strip().lower()
IS_PRODUCTION = APP_ENV in {"prd", "prod", "production"}

def _clean_url(value: str | None) -> str | None:
    if not value:
        return None
    cleaned = value.strip().rstrip("/")
    return cleaned or None

# Render expone RENDER_EXTERNAL_URL automáticamente en servicios web.
# APP_BASE_URL permite sobreescribirlo explícitamente por ambiente.
APP_BASE_URL = _clean_url(
    os.getenv("APP_BASE_URL") or os.getenv("RENDER_EXTERNAL_URL")
)

# CORS aplica a frontends web/navegador. Flutter Android/iOS nativo no necesita
# que la URL del backend figure como origen permitido.
def _cors_origins() -> list[str]:
    values: list[str] = []
    if FRONTEND_URL:
        values.append(FRONTEND_URL)
    raw = os.getenv("CORS_ORIGINS", "")
    values.extend(item for item in raw.split(",") if item.strip())

    result: list[str] = []
    seen: set[str] = set()
    for item in values:
        origin = item.strip().rstrip("/")
        if origin and origin not in seen:
            seen.add(origin)
            result.append(origin)
    return result

CORS_ORIGINS = _cors_origins()

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
# Google Play RTDN / Pub/Sub OIDC.
# La cuenta de servicio no es un secreto, pero sí es configuración del ambiente
# y no debe quedar acoplada al código.
PUBSUB_PUSH_SERVICE_ACCOUNT = os.getenv("PUBSUB_PUSH_SERVICE_ACCOUNT")
PUBSUB_OIDC_AUDIENCE = _clean_url(os.getenv("PUBSUB_OIDC_AUDIENCE"))
if PUBSUB_OIDC_AUDIENCE is None and APP_BASE_URL:
    PUBSUB_OIDC_AUDIENCE = f"{APP_BASE_URL}/subscriptions/rtdn"

# URLs de tiendas para metadata/app-config. La URL iOS puede quedar vacía
# mientras Eterlotto no esté publicada en App Store.
STORE_URL_ANDROID = os.getenv(
    "STORE_URL_ANDROID",
    f"https://play.google.com/store/apps/details?id={PACKAGE_NAME}",
).strip()
STORE_URL_IOS = os.getenv("STORE_URL_IOS", "").strip() or None

