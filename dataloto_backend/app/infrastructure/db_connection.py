import os
import psycopg2
import psycopg2.extras
import psycopg2.pool
import asyncpg
from contextlib import contextmanager
from typing import Optional
from app.core import config

pool: Optional[asyncpg.Pool] = None
_sync_pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None

def get_sync_pool() -> Optional[psycopg2.pool.ThreadedConnectionPool]:
    global _sync_pool
    if _sync_pool is None:
        try:
            dsn = config.DATABASE_URL
            if dsn:
                _sync_pool = psycopg2.pool.ThreadedConnectionPool(
                    minconn=1,
                    maxconn=10,
                    dsn=dsn,
                    sslmode="require"
                )
            else:
                host = os.getenv("PGHOST")
                port = os.getenv("PGPORT", "5432")
                db = os.getenv("PGDATABASE")
                user = os.getenv("PGUSER")
                pwd = os.getenv("PGPASSWORD")
                if host and db and user and pwd:
                    _sync_pool = psycopg2.pool.ThreadedConnectionPool(
                        minconn=1,
                        maxconn=10,
                        host=host,
                        port=port,
                        dbname=db,
                        user=user,
                        password=pwd,
                        sslmode="require"
                    )
        except Exception as e:
            print(f"⚠️ No se pudo inicializar ThreadedConnectionPool: {e}")
            _sync_pool = None
    return _sync_pool

@contextmanager
def get_connection():
    """
    Context manager de conexión síncrona optimizado.
    Reutiliza conexiones existentes de ThreadedConnectionPool en ~1-2 ms.
    """
    sync_p = get_sync_pool()
    if sync_p is not None:
        conn = sync_p.getconn()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            sync_p.putconn(conn)
    else:
        # Fallback de conexión directa
        dsn = config.DATABASE_URL
        if dsn:
            conn = psycopg2.connect(dsn, sslmode="require")
        else:
            host = os.getenv("PGHOST")
            port = os.getenv("PGPORT", "5432")
            db = os.getenv("PGDATABASE")
            user = os.getenv("PGUSER")
            pwd = os.getenv("PGPASSWORD")
            conn = psycopg2.connect(
                host=host, port=port, dbname=db, user=user, password=pwd,
                sslmode="require"
            )
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

async def init_pool():
    global pool
    if not config.DATABASE_URL:
        raise RuntimeError("DATABASE_URL no configurada en variables de entorno")
    
    # Optimización del pool asíncrono para entornos como Onrender
    pool = await asyncpg.create_pool(
        dsn=config.DATABASE_URL,
        min_size=1,
        max_size=10,
        max_queries=50000,
        max_inactive_connection_lifetime=300,
        command_timeout=60
    )
    # Inicializar también el pool síncrono
    get_sync_pool()

async def close_pool():
    global pool, _sync_pool
    if pool:
        await pool.close()
    if _sync_pool:
        _sync_pool.closeall()

def get_pool() -> asyncpg.Pool:
    global pool
    if pool is None:
        raise RuntimeError("El pool de base de datos no ha sido inicializado")
    return pool

