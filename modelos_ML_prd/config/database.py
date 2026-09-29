"""Fachada compatible para la conexión PostgreSQL de los procesos ML."""

from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from sqlalchemy.pool import NullPool

from config.settings import settings


def _connection_url() -> str | URL:
    """Construye una URL sin interpolar ni exponer la contraseña manualmente."""
    settings.validate_database_configuration()

    if settings.database_url:
        return settings.database_url

    return URL.create(
        "postgresql+psycopg2",
        username=settings.pg_user,
        password=settings.pg_password,
        host=settings.pg_host,
        port=int(settings.pg_port),
        database=settings.pg_database,
        query={"sslmode": settings.pg_sslmode},
    )


# Se conserva el nombre para compatibilidad con cualquier ejecución externa.
connection_string = _connection_url()
engine = create_engine(
    connection_string,
    poolclass=NullPool,
    pool_pre_ping=True,
)


def get_engine():
    """Devuelve el motor SQLAlchemy compartido por scrapers y predictores."""
    return engine
