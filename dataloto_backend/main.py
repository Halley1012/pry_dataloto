import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core import config
from app.infrastructure import db_connection
from app.api.routers import auth, jugadas, posts, publicidad, transacciones, metadata, notifications

app = FastAPI(title="Dataloto Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    await db_connection.init_pool()

@app.on_event("shutdown")
async def shutdown():
    await db_connection.close_pool()

# Ruta raíz para verificar el estado de la API
@app.get("/")
def root():
    return {
        "message": "Backend Miloto funcionando 🚀",
        "endpoints": ["/healthz", "/mloto", "/mloto/historico", "/login", "/register", "/test"]
    }

# Endpoint de prueba solicitado por el usuario
@app.get("/test")
def test_endpoint():
    return {"message": "hola mundo michael"}

# Registrar los routers del adaptador de entrada (API)
app.include_router(auth.router)
app.include_router(posts.router)
app.include_router(publicidad.router)
app.include_router(transacciones.router)
app.include_router(metadata.router)
app.include_router(notifications.router)
app.include_router(jugadas.router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
