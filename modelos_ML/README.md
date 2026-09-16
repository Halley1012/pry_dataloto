# Ambientes de modelos ML

Los scrapers, predictores, entrypoints y DAGs comparten un único código. El
ambiente se selecciona en tiempo de ejecución con `APP_ENV`, por lo que no se
deben crear copias `*_dev.py` y `*_prd.py`.

## Configuración local

1. Copia [`.env.dev.example`](../.env.dev.example) a `.env.dev` en la raíz del
   repositorio y completa las credenciales de la base de desarrollo.
2. Ejecuta con `APP_ENV=dev`. Si `APP_ENV` no está definido, se conserva de
   forma temporal el comportamiento heredado: se usa `dev` y, si existe,
   `modelos_ML/.env`.
3. Para producción, crea `.env.prd` sólo en la infraestructura de producción
   y arranca Airflow con `APP_ENV=prd` inyectado explícitamente.

Las variables del proceso (Docker, Airflow o CI) tienen prioridad sobre los
archivos `.env.*`. Se acepta `DATABASE_URL` o el bloque `PGHOST`, `PGDATABASE`,
`PGUSER`, `PGPASSWORD`, `PGPORT`, `PGSSLMODE`, pero no los dos a la vez.

## Protección de base de datos

Cuando `APP_ENV=prd`, `DATABASE_ENV_MARKER` es obligatorio y debe aparecer en
el host, nombre de base o usuario configurado (por ejemplo, `prd` en
`db-eterlotto-prd`). Una coincidencia incorrecta detiene el proceso antes de
que el scraper o predictor escriba datos.

## Airflow

DEV y PRD deben ser instalaciones Airflow distintas. Pueden montar los mismos
DAGs y código, siempre que cada una inyecte su propio `APP_ENV` y secretos y se
conecte únicamente a su propia base. Este repositorio aún no contiene el
Docker/Compose de Airflow, así que no se incluyó una configuración de despliegue
inventada.

Antes de publicar, migra las credenciales SMTP que hoy están en los DAGs a una
Airflow Connection o gestor de secretos y rota la contraseña expuesta.
