import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core import config
from app.infrastructure import db_connection
from app.infrastructure.repositories.jugada_repository import PostgresJugadaRepository
from app.infrastructure.repositories.user_repository import PostgresUserRepository
from app.api.routers import auth, jugadas, posts, publicidad, metadata, notifications, subscriptions

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

import uuid
from starlette.requests import Request
from app.core.logger import setup_logging, request_id_ctx_var

setup_logging()

@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    # Generar un ID corto de 8 caracteres para trazabilidad
    req_id = str(uuid.uuid4())[:8]
    token = request_id_ctx_var.set(req_id)
    try:
        response = await call_next(request)
        response.headers["X-Request-ID"] = req_id
        return response
    finally:
        request_id_ctx_var.reset(token)
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Liveness Probe
@app.get("/healthz")
def healthz():
    return {"status": "ok"}

# Comprehensive Health Check (Phase 6.5)
@app.get("/health")
async def health():
    status_db = "OK"
    status_google = "OK"
    overall_status = "OK"

    # 1. Check PostgreSQL
    try:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await conn.execute("SELECT 1")
    except Exception as e:
        status_db = f"ERROR: {e}"
        overall_status = "ERROR"

    # 2. Check Google Play
    try:
        import httpx
        # A simple check to see if we can reach Googleapis (network level check)
        # Note: We aren't doing an authenticated call to avoid quota/billing issues for a health check.
        async with httpx.AsyncClient() as client:
            resp = await client.get("https://androidpublisher.googleapis.com/$discovery/rest?version=v3", timeout=3.0)
            if resp.status_code != 200:
                status_google = f"ERROR: HTTP {resp.status_code}"
                overall_status = "ERROR"
    except Exception as e:
        status_google = f"ERROR: {e}"
        overall_status = "ERROR"

    result = {
        "status": overall_status,
        "components": {
            "postgresql": status_db,
            "google_play_api": status_google,
            "rtdn_endpoint": "OK" # If this code executes, the FastAPI router and event loop are healthy
        }
    }
    
    from fastapi import HTTPException
    if overall_status != "OK":
        raise HTTPException(status_code=503, detail=result)
    return result


# Registrar los routers del adaptador de entrada (API)
app.include_router(auth.router)
app.include_router(posts.router)
app.include_router(publicidad.router)
app.include_router(metadata.router)
app.include_router(notifications.router)
app.include_router(jugadas.router)
app.include_router(subscriptions.router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
