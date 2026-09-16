from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

DEV_PROJECT_REF = "plrgbnzsvenpbibrqyqw"
DEFAULT_PRD_PROJECT_REF = "ybgbttlosafenytdavci"


def fail(message: str, code: int = 1) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(code)


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida una instalación Eterlotto ML PRD.")
    parser.add_argument("--project-ref", default=DEFAULT_PRD_PROJECT_REF)
    parser.add_argument("--connect", action="store_true", help="Hace SELECT de solo lectura a Supabase PRD.")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    os.environ["APP_ENV"] = "prd"
    sys.path.insert(0, str(root))

    from config.settings import settings

    prd_ref = args.project_ref.strip()
    print(f"AMBIENTE: {settings.environment}")
    print(f"ENV FILE: {settings.env_file}")
    print(f"MARKER: {settings.database_env_marker}")
    print(f"DESTINO: {settings.database_target}")

    if settings.environment != "prd":
        fail("APP_ENV no quedó en prd.", 10)
    if not settings.env_file or settings.env_file.name != ".env.prd":
        fail("PRD no está cargando .env.prd.", 11)
    if settings.database_env_marker != prd_ref:
        fail("DATABASE_ENV_MARKER no coincide con el project ref esperado de PRD.", 12)
    if prd_ref.casefold() not in settings.database_target.casefold():
        fail("El destino de base no contiene el project ref PRD.", 13)
    if DEV_PROJECT_REF.casefold() in settings.database_target.casefold():
        fail("El destino PRD contiene el project ref de DEV. BLOQUEADO.", 14)

    settings.validate_database_configuration()
    print("OK: guardas DEV/PRD superadas.")

    if args.connect:
        from sqlalchemy import text
        from config.database import get_engine

        engine = get_engine()
        with engine.connect() as connection:
            row = connection.execute(text("SELECT current_database(), current_user")).fetchone()
        print(f"DB READ-ONLY CHECK: {row}")
        print("OK: conexión PRD exitosa (solo SELECT).")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
