import os
from dotenv import load_dotenv

load_dotenv()

FRONTEND_URL = os.getenv("FRONTEND_URL")
EMAIL_USER = os.getenv("EMAIL_USER")
EMAIL_PASS = os.getenv("EMAIL_PASS")
EMAIL_FROM = os.getenv("EMAIL_FROM")
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
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")
