from __future__ import annotations

import argparse
import getpass
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

DEV_PROJECT_REF = "plrgbnzsvenpbibrqyqw"
PRD_PROJECT_REF = "ybgbttlosafenytdavci"
DEFAULT_PGHOST = "aws-0-sa-east-1.pooler.supabase.com"
DEFAULT_PGDATABASE = "postgres"


def ask(label: str, default: str | None = None) -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{label}{suffix}: ").strip()
    return value or (default or "")


def quote_env(value: str) -> str:
    # Los valores habituales de Supabase/Gmail no requieren comillas; si algún
    # valor tiene espacios o #, lo protegemos de forma compatible con dotenv.
    if any(ch.isspace() for ch in value) or "#" in value:
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return value


def ignore_copy(directory: str, names: list[str]) -> set[str]:
    ignored: set[str] = set()
    for name in names:
        if name in {".env", ".env.dev", ".env.prd", ".secrets", ".pytest_cache", "__pycache__", ".git"}:
            ignored.add(name)
        elif name.startswith(".venv"):
            ignored.add(name)
        elif name.endswith((".pyc", ".pyo")):
            ignored.add(name)
        elif name == "firebase_credentials.json":
            ignored.add(name)
    return ignored


def validate_python_syntax(root: Path) -> None:
    import ast

    failures: list[str] = []
    for path in root.rglob("*.py"):
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except Exception as exc:  # pragma: no cover - diagnostic path
            failures.append(f"{path.relative_to(root)}: {exc}")
    if failures:
        raise RuntimeError("Errores de sintaxis:\n" + "\n".join(failures))


def run_validation(prd_modelos: Path, prd_ref: str) -> None:
    env = os.environ.copy()
    env["APP_ENV"] = "prd"
    command = [
        sys.executable,
        str(prd_modelos / "validar_prd.py"),
        "--project-ref",
        prd_ref,
        "--connect",
    ]
    result = subprocess.run(command, cwd=prd_modelos, env=env)
    if result.returncode != 0:
        raise RuntimeError(
            "La instalación fue creada, pero la validación PRD falló. "
            "Corrige .env.prd y vuelve a ejecutar validar_prd.py."
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Crea una instalación PRD segura de modelos_ML a partir de DEV."
    )
    parser.add_argument(
        "--dev-modelos",
        default=None,
        help="Ruta de modelos_ML DEV. Por defecto usa la carpeta que contiene este script si corresponde, o D:\\pry_dataloto\\modelos_ML.",
    )
    parser.add_argument("--prd-root", default=r"D:\pry_eterlotto_prd")
    parser.add_argument("--project-ref", default=PRD_PROJECT_REF)
    parser.add_argument("--force", action="store_true", help="Recrear el destino si ya existe.")
    parser.add_argument("--no-connect", action="store_true", help="No probar conexión a PRD al finalizar.")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    if args.dev_modelos:
        dev_modelos = Path(args.dev_modelos).expanduser().resolve()
    elif (script_dir / "config" / "settings.py").is_file():
        dev_modelos = script_dir
    else:
        dev_modelos = Path(r"D:\pry_dataloto\modelos_ML")

    prd_root = Path(args.prd_root).expanduser()
    prd_modelos = prd_root / "modelos_ML"
    prd_ref = args.project_ref.strip()

    print("\n=== Eterlotto: creación de instalación PRD ===")
    print(f"DEV: {dev_modelos}")
    print(f"PRD: {prd_modelos}")
    print(f"Supabase PRD ref: {prd_ref}")

    required = [
        dev_modelos / "config" / "settings.py",
        dev_modelos / "config" / "database.py",
        dev_modelos / "requirements.txt",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        print("ERROR: la carpeta DEV no parece ser modelos_ML válido:")
        for path in missing:
            print(" -", path)
        return 2

    if prd_ref == DEV_PROJECT_REF:
        print("ERROR: el project ref de PRD coincide con DEV. Operación cancelada.")
        return 3

    if prd_modelos.exists():
        if not args.force:
            print(f"ERROR: ya existe {prd_modelos}")
            print("No se sobrescribe PRD automáticamente. Usa --force solo si realmente quieres recrearla.")
            return 4
        print("AVISO: --force activo; se eliminará la instalación PRD existente.")
        shutil.rmtree(prd_modelos)

    prd_root.mkdir(parents=True, exist_ok=True)
    shutil.copytree(dev_modelos, prd_modelos, ignore=ignore_copy)

    # Nunca arrastrar utilidades exclusivas de migración DEV a la instalación PRD.
    for local_only in ["APLICAR_CAMBIOS_DEV.ps1", "aplicar_cambios_dev.sh"]:
        candidate = prd_modelos / local_only
        if candidate.exists():
            candidate.unlink()

    (prd_modelos / ".secrets").mkdir(exist_ok=True)

    # El validador viaja dentro de la instalación PRD para poder re-ejecutarlo.
    validator_source = script_dir / "validar_prd.py"
    if validator_source.is_file() and validator_source.resolve() != (prd_modelos / "validar_prd.py").resolve():
        shutil.copy2(validator_source, prd_modelos / "validar_prd.py")

    print("\nConfiguración de Supabase PRD")
    pg_host = ask("PGHOST", DEFAULT_PGHOST)
    pg_database = ask("PGDATABASE", DEFAULT_PGDATABASE)
    pg_user = ask("PGUSER", f"postgres.{prd_ref}")
    pg_password = getpass.getpass("PGPASSWORD PRD (no se mostrará): ").strip()
    if not pg_password:
        print("ERROR: PGPASSWORD no puede quedar vacío.")
        shutil.rmtree(prd_modelos, ignore_errors=True)
        return 5

    target_preview = f"{pg_host}/{pg_database}/{pg_user}"
    if prd_ref.casefold() not in target_preview.casefold():
        print("ERROR: el destino no contiene el project ref de PRD. Operación cancelada.")
        shutil.rmtree(prd_modelos, ignore_errors=True)
        return 6
    if DEV_PROJECT_REF.casefold() in target_preview.casefold():
        print("ERROR: se detectó el project ref de DEV en el destino PRD. Operación cancelada.")
        shutil.rmtree(prd_modelos, ignore_errors=True)
        return 7

    env_lines = [
        "# Eterlotto ML - PRODUCCION",
        "# Generado localmente. NO versionar.",
        "APP_ENV=prd",
        "",
        f"PGHOST={quote_env(pg_host)}",
        f"PGDATABASE={quote_env(pg_database)}",
        f"PGUSER={quote_env(pg_user)}",
        f"PGPASSWORD={quote_env(pg_password)}",
        "PGPORT=5432",
        "PGSSLMODE=require",
        f"DATABASE_ENV_MARKER={prd_ref}",
        "",
        "# SMTP queda apagado durante la primera validación PRD.",
        "# Actívalo después de validar Airflow PRD y usa contraseña de aplicación.",
        "SMTP_ENABLED=false",
        "SMTP_HOST=smtp.gmail.com",
        "SMTP_PORT=587",
        "SMTP_STARTTLS=true",
        "SMTP_USER=",
        "SMTP_PASSWORD=",
        "SMTP_FROM=",
        "SMTP_TO=",
        "",
        "# Firebase PRD: coloca una credencial apropiada en .secrets si la necesitas.",
        "FIREBASE_CREDENTIALS_FILE=.secrets/firebase_credentials.json",
        "",
        "# Opcionales",
        "# MODEL_ROOT=models",
        "# MODEL_VERSION=v1",
        "",
    ]
    (prd_modelos / ".env.prd").write_text("\n".join(env_lines), encoding="utf-8")

    manifest = (
        "ETERLOTTO PRD INSTALLATION\n"
        f"created_utc={datetime.now(timezone.utc).isoformat()}\n"
        f"source_dev={dev_modelos}\n"
        f"prd_root={prd_root}\n"
        f"supabase_project_ref={prd_ref}\n"
        "secrets_copied=false\n"
    )
    (prd_modelos / "PRD_INSTALLATION.txt").write_text(manifest, encoding="utf-8")

    validate_python_syntax(prd_modelos)
    print("OK: código PRD copiado sin secretos DEV.")
    print("OK: .env.prd creado.")
    print("OK: validación sintáctica de Python superada.")

    if not args.no_connect:
        run_validation(prd_modelos, prd_ref)
    else:
        print("AVISO: se omitió la prueba de conexión (--no-connect).")

    print("\n=== PRD de modelos_ML creada correctamente ===")
    print(f"Ruta: {prd_modelos}")
    print("No arranques todavía el segundo Airflow hasta configurarlo con APP_ENV=prd.")
    print("Siguiente paso: preparar docker-compose PRD con puertos/volúmenes separados.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
