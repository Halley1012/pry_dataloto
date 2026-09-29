# Eterlotto ML — crear instalación PRD

Este paquete crea una instalación física separada de `modelos_ML` para producción.
No crea copias `*_dev.py` / `*_prd.py`: el código sigue siendo el mismo y cambia
solo la configuración del ambiente.

## Resultado

```text
D:\pry_dataloto\modelos_ML          <- DEV actual
D:\pry_eterlotto_prd\modelos_ML    <- PRD nueva
```

La instalación PRD se genera excluyendo automáticamente:

- `.env`, `.env.dev`, `.env.prd` anteriores
- `.secrets/`
- `firebase_credentials.json`
- `.venv*`
- `__pycache__/` y `.pytest_cache/`
- `.git/`

El instalador crea un `.env.prd` nuevo y usa como marcador de seguridad el
Supabase PRD de Eterlotto:

```text
ybgbttlosafenytdavci
```

También bloquea el conocido project ref de DEV:

```text
plrgbnzsvenpbibrqyqw
```

## Cómo ejecutarlo

La opción más sencilla es copiar estos tres archivos dentro de:

```text
D:\pry_dataloto\modelos_ML
```

Luego en PowerShell:

```powershell
cd D:\pry_dataloto\modelos_ML
.\CREAR_PRD.ps1
```

El script pedirá la contraseña de la base PRD sin mostrarla. Los valores por
defecto están preparados para el pooler de Supabase usado por el proyecto:

```text
PGHOST=aws-0-sa-east-1.pooler.supabase.com
PGDATABASE=postgres
PGUSER=postgres.ybgbttlosafenytdavci
DATABASE_ENV_MARKER=ybgbttlosafenytdavci
```

Pulsa Enter para aceptar un valor por defecto si coincide con la pantalla de
conexión de tu Supabase PRD.

Al terminar hace únicamente:

```sql
SELECT current_database(), current_user;
```

para comprobar que PRD conecta. No inserta, actualiza ni elimina registros.

## SMTP y Firebase

Por seguridad, PRD nace con:

```env
SMTP_ENABLED=false
```

No se copia la contraseña SMTP de DEV ni la credencial Firebase. Se habilitarán
después de comprobar el segundo Airflow PRD.

## Volver a validar

Dentro de la nueva carpeta PRD:

```powershell
cd D:\pry_eterlotto_prd\modelos_ML
python validar_prd.py --connect
```

## Importante para Airflow PRD

`settings.py` exige que el proceso de Airflow PRD arranque explícitamente con:

```text
APP_ENV=prd
```

No basta con que exista `.env.prd`. Esta protección es intencional para impedir
que una instalación PRD arranque accidentalmente como DEV.

El siguiente paso es crear un segundo `docker-compose`/proyecto de Airflow con:

- nombre de proyecto Docker distinto;
- puertos host distintos a DEV;
- base de metadatos de Airflow separada;
- `APP_ENV=prd`;
- volumen apuntando a `D:\pry_eterlotto_prd\modelos_ML`;
- DAGs de la versión estable.

Para generar ese archivo sin adivinar tu configuración actual, se debe partir de
tu `docker-compose.yaml` que ya está funcionando en DEV.
