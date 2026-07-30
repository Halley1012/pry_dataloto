import os
from sqlalchemy import create_engine
from dotenv import load_dotenv

# Cargar variables de entorno desde el archivo .env
# Buscaremos el .env en el directorio actual o en la raíz de modelos_ML
base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dotenv_path = os.path.join(base_dir, ".env")
load_dotenv(dotenv_path)

PGHOST = os.getenv("PGHOST")
PGDATABASE = os.getenv("PGDATABASE")
PGUSER = os.getenv("PGUSER")
PGPASSWORD = os.getenv("PGPASSWORD")
PGPORT = os.getenv("PGPORT", "5432")
PGSSLMODE = os.getenv("PGSSLMODE", "require")

# Validación estricta para no dejar credenciales expuestas por defecto en el código
if not all([PGHOST, PGDATABASE, PGUSER, PGPASSWORD]):
    raise RuntimeError(
        "❌ Faltan configurar variables de entorno críticas en el archivo .env (PGHOST, PGDATABASE, PGUSER, PGPASSWORD)"
    )

connection_string = f'postgresql+psycopg2://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}?sslmode={PGSSLMODE}'
engine = create_engine(
    connection_string,
    pool_pre_ping=True,      # Verifica si la conexión sigue viva antes de usarla
    pool_recycle=300         # Recicla conexiones cada 5 minutos
)

def get_engine():
    return engine
