import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core import config
from app.infrastructure import db_connection
from app.infrastructure.repositories.jugada_repository import PostgresJugadaRepository
from app.infrastructure.repositories.user_repository import PostgresUserRepository
from app.api.routers import auth, jugadas, posts, publicidad, transacciones, metadata, notifications, subscriptions

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await db_connection.init_pool()
    try:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await PostgresUserRepository.ensure_schema(conn)
            await PostgresJugadaRepository.ensure_schema(conn)
    except Exception as e:
        print(f"⚠️ Advertencia inicializando esquema en startup: {e}")
    yield
    # Shutdown
    await db_connection.close_pool()

app = FastAPI(title="Eterlotto Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Liveness Probe (Proceso vivo)
@app.get("/healthz")
def healthz():
    return {"status": "ok"}

# Readiness Probe (Conexión a BD lista)
@app.get("/readyz")
async def readyz():
    try:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await conn.execute("SELECT 1")
        return {"status": "ready"}
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=503, detail="Database unready")


# Registrar los routers del adaptador de entrada (API)
app.include_router(auth.router)
app.include_router(posts.router)
app.include_router(publicidad.router)
app.include_router(transacciones.router)
app.include_router(metadata.router)
app.include_router(notifications.router)
app.include_router(jugadas.router)
app.include_router(subscriptions.router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
