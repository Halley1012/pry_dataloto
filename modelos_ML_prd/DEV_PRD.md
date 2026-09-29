# Eterlotto ML — DEV y PRD

Esta carpeta usa **un solo código fuente** para DEV y PRD. No crees versiones
`*_dev.py` y `*_prd.py` de scrapers, predictors o DAGs.

## DEV (esta instalación)

1. Usa `.env.dev` local (está ignorado por Git).
2. `APP_ENV=dev`.
3. La base debe ser `db-eterlotto-dev`.
4. Airflow puede montar esta misma carpeta en cualquier ruta; los DAGs ya no
   dependen de `/opt/airflow/pry_dataloto/modelos_ML`.
5. Si la venv no está en `modelos_ML/.venv_airflow`, define
   `ETERLOTTO_VENV_ROOT`.

## PRD

PRD debe salir de un commit/tag probado, no de una copia editada manualmente.
En la instalación de producción:

1. Copia `.env.prd.example` a `.env.prd`.
2. Completa credenciales de `db-eterlotto-prd`.
3. Define `APP_ENV=prd` **en el proceso/Docker/Airflow** antes de arrancar.
4. Define `DATABASE_ENV_MARKER` con el project ref/identificador de PRD.
5. No copies `.env.dev` ni `.secrets/` de DEV a PRD. Inyecta secretos propios.

Ejemplo conceptual:

```text
Git / tag estable
      ├── Airflow DEV -> APP_ENV=dev -> db-eterlotto-dev
      └── Airflow PRD -> APP_ENV=prd -> db-eterlotto-prd
```

## SMTP

Las credenciales ya no viven en los 31 DAGs. Se configuran con:

- `SMTP_ENABLED`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_STARTTLS`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM`
- `SMTP_TO`

La contraseña que estaba escrita en los DAGs debe **rotarse** antes de volver a
habilitar las alertas.

## Firebase

El JSON local fue movido a `.secrets/firebase_credentials.json`, carpeta
ignorada por Git. También puedes apuntar a otra ubicación con
`FIREBASE_CREDENTIALS_FILE` o usar ADC en el entorno de ejecución.

## Si `.env` o Firebase ya estaban versionados

`.gitignore` no elimina archivos que Git ya está siguiendo. Desde la raíz del
repositorio, revisa primero con `git status` y luego deja de trackear únicamente
los secretos (sin borrarlos de tu disco):

```bash
git rm --cached modelos_ML/.env 2>/dev/null || true
git rm --cached modelos_ML/config/firebase_credentials.json 2>/dev/null || true
git add modelos_ML/.gitignore modelos_ML/.env.dev.example modelos_ML/.env.prd.example
git add modelos_ML/config modelos_ML/eterlotto_*_dag.py modelos_ML/src/notification_generator.py modelos_ML/DEV_PRD.md
git status
```

En PowerShell, si `2>/dev/null || true` no aplica, ejecuta cada `git rm --cached`
por separado y continúa si Git informa que el archivo no estaba trackeado.
