from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from app.api import schemas, dependencies
from app.application.jugada_use_cases import JugadaUseCases

from app.core.cache import memory_cache

router = APIRouter()

# --- MLoto endpoints ---
@router.get("/mloto")
def get_mloto_prediction(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = "mloto:prediccion"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_prediccion_mloto()
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/mloto/ultimos5")
def get_mloto_ultimos5(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = "mloto:ultimos5"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_ultimos5_mloto()
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/mloto/historico_completo")
def get_mloto_historico_completo(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = "mloto:historico_completo"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_historico_completo_mloto()
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/mloto/historico")
def get_mloto_historico(limit: int = 10, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return use_cases.obtener_historico("mloto", limit)

@router.post("/jugadas_mloto", response_model=schemas.JugadaOut)
async def crear_jugada_mloto(jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.guardar_jugada("mloto", int(jugada.user_id), jugada.numeros)

@router.get("/jugadas_mloto", response_model=List[schemas.JugadaOut])
async def listar_jugadas_mloto(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.listar_jugadas("mloto", user_id)

@router.delete("/jugadas_mloto/{jugada_id}")
async def borrar_jugada_mloto(jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    success = await use_cases.borrar_jugada("mloto", jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}

@router.get("/mis_loterias_activas", response_model=List[str])
async def get_active_lotteries(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_con_jugadas(user_id)


# --- Bloto endpoints ---
@router.get("/bloto")
def get_bloto_prediction(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = "bloto:prediccion"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_prediccion_bloto()
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/bloto/ultimos5")
def get_bloto_ultimos5(sorteo: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = f"bloto:ultimos5:{sorteo or 'todos'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_ultimos5_bloto(sorteo=sorteo)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/bloto/historico_completo")
def get_bloto_historico_completo(sorteo: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = f"bloto:historico_completo:{sorteo or 'todos'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_historico_completo_bloto(sorteo=sorteo)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.post("/jugadas_bloto", response_model=schemas.JugadaOut)
async def crear_jugada_bloto(jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.guardar_jugada("bloto", int(jugada.user_id), jugada.numeros)

@router.get("/jugadas_bloto", response_model=List[schemas.JugadaOut])
async def listar_jugadas_bloto(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    # En la implementación original, esta ruta estaba duplicada. 
    # Mapearemos a listar jugadas de bloto para mantener la lógica.
    return await use_cases.listar_jugadas("bloto", user_id)

@router.delete("/jugadas_bloto/{jugada_id}")
async def borrar_jugada_bloto(jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    success = await use_cases.borrar_jugada("bloto", jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}


# --- Cloto (ColorLoto) endpoints ---
@router.get("/cloto")
def get_cloto_prediction(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_prediccion_colorloto("colorloto")
    if "error" in res:
        return res
    return res

@router.get("/cloto/ultimos5")
def get_cloto_ultimos5(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_ultimos5("colorloto")
    if "error" in res:
        return res
    return res

@router.post("/jugadas_cloto", response_model=schemas.JugadaOut)
async def crear_jugada_cloto(jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.guardar_jugada("colorloto", int(jugada.user_id), jugada.numeros)

@router.get("/jugadas_cloto", response_model=List[schemas.JugadaOut])
async def listar_jugadas_cloto(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    # Proveemos el endpoint correcto para cloto también
    return await use_cases.listar_jugadas("colorloto", user_id)

@router.delete("/jugadas_cloto/{jugada_id}")
async def borrar_jugada_cloto(jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    success = await use_cases.borrar_jugada("colorloto", jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada de ColorLoto eliminada"}


# --- Endpoints Genéricos para Loterías de EE.UU. ---
LOTERIAS_EEUU = [
    ("powerball", "Powerball"),
    ("lotto_america", "Lotto America"),
    ("double_play", "Double Play"),
    ("millionaire_life", "Millionaire for Life"),
    ("megamillions", "Mega Millions")
]

for route_name, display_name in LOTERIAS_EEUU:
    def _make_endpoints(r_name, d_name):
        @router.get(f"/{r_name}", name=f"get_{r_name}_prediccion")
        def get_prediccion(fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
            cache_key = f"{r_name}:prediccion:{fecha or 'latest'}"
            cached = memory_cache.get(cache_key)
            if cached is not None:
                return cached
            res = use_cases.obtener_prediccion_generico(r_name, fecha)
            if "error" not in res:
                memory_cache.set(cache_key, res, ttl=300)
            return res

        @router.get(f"/{r_name}/ultimos5", name=f"get_{r_name}_ultimos5")
        def get_ultimos5(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
            cache_key = f"{r_name}:ultimos5"
            cached = memory_cache.get(cache_key)
            if cached is not None:
                return cached
            res = use_cases.obtener_ultimos5_generico(r_name, d_name)
            if "error" not in res:
                memory_cache.set(cache_key, res, ttl=300)
            return res

        @router.get(f"/{r_name}/historico_completo", name=f"get_{r_name}_historico_completo")
        def get_historico_completo(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
            cache_key = f"{r_name}:historico_completo"
            cached = memory_cache.get(cache_key)
            if cached is not None:
                return cached
            res = use_cases.obtener_historico_completo_generico(r_name, d_name)
            if "error" not in res:
                memory_cache.set(cache_key, res, ttl=300)
            return res

        @router.post(f"/jugadas_{r_name}", response_model=schemas.JugadaOut, name=f"crear_jugada_{r_name}")
        async def crear_jugada(jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
            return await use_cases.guardar_jugada(r_name, int(jugada.user_id), jugada.numeros)

        @router.get(f"/jugadas_{r_name}", response_model=List[schemas.JugadaOut], name=f"listar_jugadas_{r_name}")
        async def listar_jugadas(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
            return await use_cases.listar_jugadas(r_name, user_id)

        @router.delete(f"/jugadas_{r_name}/{{jugada_id}}", name=f"borrar_jugada_{r_name}")
        async def borrar_jugada(jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
            success = await use_cases.borrar_jugada(r_name, jugada_id, user_id)
            if not success:
                raise HTTPException(status_code=404, detail="Jugada no encontrada")
            return {"message": "Jugada eliminada"}

    _make_endpoints(route_name, display_name)

