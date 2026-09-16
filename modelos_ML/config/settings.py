"""Configuración centralizada y segura para los procesos ML.

El código de scrapers, predictores y DAGs es único. El ambiente se elige con
``APP_ENV`` y las credenciales se inyectan en tiempo de ejecución; nunca se
deben codificar en el repositorio.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv


MODELOS_ML_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = MODELOS_ML_ROOT.parent
VALID_ENVIRONMENTS = frozenset({"dev", "prd"})


class ConfigurationError(RuntimeError):
    """Indica una configuración incompleta o insegura."""


def _value(name: str) -> str | None:
    """Obtiene una variable no vacía sin exponer su valor en mensajes."""
    value = os.getenv(name)
    if value is None:
        return None
    value = value.strip()
    return value or None


def _normalise_environment(value: str) -> str:
    environment = value.strip().lower()
    if environment not in VALID_ENVIRONMENTS:
        allowed = ", ".join(sorted(VALID_ENVIRONMENTS))
        raise ConfigurationError(
            f"APP_ENV debe ser uno de: {allowed}. Valor recibido: {value!r}."
        )
    return environment


def _environment_file(environment: str) -> Path | None:
    """Devuelve el archivo del ambiente, sin permitir un fallback de PRD a DEV."""
    explicit_file = _value("ETERLOTTO_ENV_FILE")
    if explicit_file:
        path = Path(explicit_file).expanduser()
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        if not path.is_file():
            raise ConfigurationError(
                "ETERLOTTO_ENV_FILE no apunta a un archivo existente."
            )
        return path

    candidates = [
        PROJECT_ROOT / f".env.{environment}",
        MODELOS_ML_ROOT / f".env.{environment}",
    ]

    # Compatibilidad temporal con la instalación local existente. Nunca se
    # consulta este archivo cuando APP_ENV=prd, para evitar una promoción
    # accidental contra la base de desarrollo.
    if environment == "dev":
        candidates.append(MODELOS_ML_ROOT / ".env")

    return next((path for path in candidates if path.is_file()), None)


def _load_environment_file(environment: str) -> Path | None:
    env_file = _environment_file(environment)
    if env_file:
        # Las variables de Docker, Airflow o CI tienen prioridad sobre el
        # archivo local; así no se sustituyen secretos inyectados en runtime.
        load_dotenv(env_file, override=False)
    return env_file


@dataclass(frozen=True)
class Settings:
    """Valores de configuración no secretos usados por el código ML."""

    environment: str
    env_file: Path | None
    database_url: str | None
    pg_host: str | None
    pg_database: str | None
    pg_user: str | None
    pg_password: str | None
    pg_port: str
    pg_sslmode: str
    database_env_marker: str | None
    model_root: Path
    model_version: str | None

    @property
    def is_production(self) -> bool:
        return self.environment == "prd"

    @property
    def database_target(self) -> str:
        """Identificador no secreto del destino usado para la protección DEV/PRD."""
        if self.database_url:
            parsed = urlparse(self.database_url)
            return f"{parsed.hostname or ''}{parsed.path or ''}/{parsed.username or ''}"
        return f"{self.pg_host or ''}/{self.pg_database or ''}/{self.pg_user or ''}"

    def validate_database_configuration(self) -> None:
        """Comprueba que exista un único destino y que corresponda al ambiente."""
        has_database_url = bool(self.database_url)
        legacy_values = {
            "PGHOST": self.pg_host,
            "PGDATABASE": self.pg_database,
            "PGUSER": self.pg_user,
            "PGPASSWORD": self.pg_password,
        }
        has_legacy_values = any(legacy_values.values())

        if has_database_url and has_legacy_values:
            raise ConfigurationError(
                "Configura DATABASE_URL o las variables PG*, pero no ambos."
            )

        if not has_database_url:
            missing = [name for name, value in legacy_values.items() if not value]
            if missing:
                raise ConfigurationError(
                    "Faltan variables de base de datos: " + ", ".join(missing)
                )

        try:
            port = int(self.pg_port)
        except ValueError as error:
            raise ConfigurationError("PGPORT debe ser un entero válido.") from error
        if not 1 <= port <= 65535:
            raise ConfigurationError("PGPORT debe estar entre 1 y 65535.")

        # PRD debe declarar un marcador que aparezca en el host, nombre de
        # base o usuario. El usuario de poolers de Supabase incluye el ID del
        # proyecto, por lo que también sirve como destino inequívoco.
        if self.is_production and not self.database_env_marker:
            raise ConfigurationError(
                "APP_ENV=prd exige DATABASE_ENV_MARKER para proteger el destino."
            )
        if (
            self.database_env_marker
            and self.database_env_marker.casefold() not in self.database_target.casefold()
        ):
            raise ConfigurationError(
                "DATABASE_ENV_MARKER no coincide con el destino de base configurado."
            )


def load_settings() -> Settings:
    """Carga el ambiente solicitado y devuelve su configuración centralizada.

    Sin ``APP_ENV`` el proceso sigue comportándose como antes: usa ``dev`` y,
    de existir, el archivo legado ``modelos_ML/.env``. PRD requiere declarar
    explícitamente ``APP_ENV=prd`` antes de iniciar el proceso.
    """
    process_database_url = _value("DATABASE_URL")
    process_legacy_values = {
        "PGHOST": _value("PGHOST"),
        "PGDATABASE": _value("PGDATABASE"),
        "PGUSER": _value("PGUSER"),
        "PGPASSWORD": _value("PGPASSWORD"),
    }
    has_process_legacy_values = any(process_legacy_values.values())

    if process_database_url and has_process_legacy_values:
        raise ConfigurationError(
            "El proceso define DATABASE_URL y variables PG* al mismo tiempo."
        )

    requested_environment = _normalise_environment(_value("APP_ENV") or "dev")
    env_file = _load_environment_file(requested_environment)
    configured_environment = _normalise_environment(
        _value("APP_ENV") or requested_environment
    )

    if configured_environment != requested_environment:
        raise ConfigurationError(
            "El APP_ENV del archivo de ambiente no coincide con el ambiente solicitado."
        )

    raw_model_root = _value("MODEL_ROOT")
    if raw_model_root:
        model_root = Path(raw_model_root).expanduser()
        if not model_root.is_absolute():
            model_root = PROJECT_ROOT / model_root
    else:
        model_root = MODELOS_ML_ROOT / "models"

    # Una DATABASE_URL inyectada por Docker/Airflow es un contrato completo.
    # Ignoramos PG* que pudieran venir del archivo local para no mezclar dos
    # conexiones. Si el proceso inyecta PG*, conserva el comportamiento de
    # override individual de python-dotenv y descarta DATABASE_URL del archivo.
    if process_database_url:
        database_url = process_database_url
        pg_host = pg_database = pg_user = pg_password = None
        pg_port = "5432"
        pg_sslmode = "require"
    else:
        database_url = None if has_process_legacy_values else _value("DATABASE_URL")
        pg_host = _value("PGHOST")
        pg_database = _value("PGDATABASE")
        pg_user = _value("PGUSER")
        pg_password = _value("PGPASSWORD")
        pg_port = _value("PGPORT") or "5432"
        pg_sslmode = _value("PGSSLMODE") or "require"

    return Settings(
        environment=configured_environment,
        env_file=env_file,
        database_url=database_url,
        pg_host=pg_host,
        pg_database=pg_database,
        pg_user=pg_user,
        pg_password=pg_password,
        pg_port=pg_port,
        pg_sslmode=pg_sslmode,
        database_env_marker=_value("DATABASE_ENV_MARKER"),
        model_root=model_root,
        model_version=_value("MODEL_VERSION"),
    )


# Se mantiene disponible como una única fuente de verdad para los entrypoints.
# La conexión se valida al importar config.database, no al importar settings.
settings = load_settings()
