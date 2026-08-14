import os
import psycopg2
import psycopg2.extras
import asyncpg
from typing import Optional
from app.core import config

pool: Optional[asyncpg.Pool] = None

def get_connection():
    dsn = config.DATABASE_URL
    if dsn:
        return psycopg2.connect(dsn, sslmode="require")

    host = os.getenv("PGHOST")
    port = os.getenv("PGPORT", "5432")
    db = os.getenv("PGDATABASE")
    user = os.getenv("PGUSER")
    pwd = os.getenv("PGPASSWORD")

    missing = [k for k, v in {
        "PGHOST": host, "PGPORT": port, "PGDATABASE": db,
        "PGUSER": user, "PGPASSWORD": pwd
    }.items() if not v]
    if missing:
        raise RuntimeError(f"Faltan variables de entorno para DB: {', '.join(missing)}")

    return psycopg2.connect(
        host=host, port=port, dbname=db, user=user, password=pwd,
        sslmode="require"
    )

async def init_pool():
    global pool
    if not config.DATABASE_URL:
        raise RuntimeError("DATABASE_URL no configurada en variables de entorno")
    
    # Optimización del pool para entornos como Onrender
    pool = await asyncpg.create_pool(
        dsn=config.DATABASE_URL,
        min_size=1,
        max_size=10,
        max_queries=50000,
        max_inactive_connection_lifetime=300,
        command_timeout=60
    )

async def close_pool():
    global pool
    if pool:
        await pool.close()

def get_pool() -> asyncpg.Pool:
    global pool
    if pool is None:
        raise RuntimeError("El pool de base de datos no ha sido inicializado")
    return pool
