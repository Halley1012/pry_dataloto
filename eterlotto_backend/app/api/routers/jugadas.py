from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional, Dict, Any
from app.api import schemas, dependencies
from app.application.jugada_use_cases import JugadaUseCases

from app.core.cache import memory_cache

router = APIRouter()

# --- MLoto endpoints ---
@router.get("/mloto")
def get_mloto_prediction(fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = f"mloto:prediccion:{fecha or 'latest'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_prediccion_mloto(fecha)
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
    return await use_cases.guardar_jugada("mloto", int(jugada.user_id), jugada.numeros, fecha_sorteo=jugada.fecha_sorteo or jugada.fecha)

@router.get("/jugadas_mloto", response_model=List[schemas.JugadaOut])
async def listar_jugadas_mloto(user_id: int, fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.listar_jugadas("mloto", user_id, fecha)

@router.delete("/jugadas_mloto/{jugada_id}")
async def borrar_jugada_mloto(jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    success = await use_cases.borrar_jugada("mloto", jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}

@router.get("/mis_loterias_activas", response_model=List[str])
async def get_active_lotteries(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_con_jugadas(user_id)

@router.get("/mis_loterias_con_conteo", response_model=Dict[str, int])
async def get_active_lotteries_with_count(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_con_conteo(user_id)

@router.get("/mis_loterias_info", response_model=Dict[str, Dict[str, Any]])
async def get_active_lotteries_info(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_info(user_id)


# --- Bloto endpoints ---
@router.get("/bloto")
def get_bloto_prediction(fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    cache_key = f"bloto:prediccion:{fecha or 'latest'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_prediccion_bloto(fecha)
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
    return await use_cases.guardar_jugada("bloto", int(jugada.user_id), jugada.numeros, fecha_sorteo=jugada.fecha_sorteo or jugada.fecha)

@router.get("/jugadas_bloto", response_model=List[schemas.JugadaOut])
async def listar_jugadas_bloto(user_id: int, fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    # En la implementación original, esta ruta estaba duplicada. 
    # Mapearemos a listar jugadas de bloto para mantener la lógica.
    return await use_cases.listar_jugadas("bloto", user_id, fecha)

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
    return await use_cases.guardar_jugada("colorloto", int(jugada.user_id), jugada.numeros, fecha_sorteo=jugada.fecha_sorteo or jugada.fecha)

@router.get("/jugadas_cloto", response_model=List[schemas.JugadaOut])
async def listar_jugadas_cloto(user_id: int, fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    # Proveemos el endpoint correcto para cloto también
    return await use_cases.listar_jugadas("colorloto", user_id, fecha)

@router.delete("/jugadas_cloto/{jugada_id}")
async def borrar_jugada_cloto(jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    success = await use_cases.borrar_jugada("colorloto", jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada de ColorLoto eliminada"}


# --- Endpoints Genéricos Universales para Cualquier Lotería Actual o Futura ---

RESERVED_ROUTES = {
    "login", "register", "auth", "refresh", "users", "loterias", 
    "paises", "departamentos", "ciudades", "categorias", "publicidad", 
    "posts", "comments", "notifications", "transacciones", "healthz", 
    "docs", "openapi.json", "test", "mis_loterias_activas", "mis_loterias_con_conteo", "mis_loterias_info"
}

@router.get("/{r_name}/ultimos5", name="get_loteria_ultimos5_dinamico")
def get_ultimos5_dinamico(r_name: str, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    cache_key = f"{clean_route}:ultimos5"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    display_name = clean_route.replace('_', ' ').title()
    res = use_cases.obtener_ultimos5_generico(clean_route, display_name)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/{r_name}/ultimos50", name="get_loteria_ultimos50_dinamico")
def get_ultimos50_dinamico(r_name: str, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    cache_key = f"{clean_route}:ultimos50"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    display_name = clean_route.replace('_', ' ').title()
    res = use_cases.obtener_ultimos50_generico(clean_route, display_name)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.get("/{r_name}/historico_completo", name="get_loteria_historico_completo_dinamico")
def get_historico_completo_dinamico(r_name: str, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    cache_key = f"{clean_route}:historico_completo"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    display_name = clean_route.replace('_', ' ').title()
    res = use_cases.obtener_historico_completo_generico(clean_route, display_name)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res

@router.post("/jugadas", response_model=schemas.JugadaOut, name="crear_jugada_unificada")
async def crear_jugada_unificada(jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (jugada.loteria_route or "mloto").strip().lower()
    return await use_cases.guardar_jugada(clean_route, int(jugada.user_id), jugada.numeros, fecha_sorteo=jugada.fecha_sorteo or jugada.fecha)

@router.get("/jugadas", response_model=List[schemas.JugadaOut], name="listar_jugadas_unificada")
async def listar_jugadas_unificada(user_id: int, loteria: Optional[str] = None, fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (loteria or "").strip().lower()
    return await use_cases.listar_jugadas(clean_route, user_id, fecha)

@router.delete("/jugadas/{jugada_id}", name="borrar_jugada_unificada")
async def borrar_jugada_unificada(jugada_id: int, user_id: int, loteria: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (loteria or "").strip().lower()
    success = await use_cases.borrar_jugada(clean_route, jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}

@router.put("/jugadas/{jugada_id}", response_model=schemas.JugadaOut, name="actualizar_jugada_unificada")
async def actualizar_jugada_unificada(jugada_id: int, jugada: schemas.JugadaUpdate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (jugada.loteria_route or "").strip().lower()
    res = await use_cases.actualizar_jugada(clean_route, jugada_id, int(jugada.user_id), jugada.numeros)
    if not res:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return res

@router.post("/jugadas_{r_name}", response_model=schemas.JugadaOut, name="crear_jugada_dinamico")
async def crear_jugada_dinamico(r_name: str, jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    return await use_cases.guardar_jugada(clean_route, int(jugada.user_id), jugada.numeros, fecha_sorteo=jugada.fecha_sorteo or jugada.fecha)

@router.get("/jugadas_{r_name}", response_model=List[schemas.JugadaOut], name="listar_jugadas_dinamico")
async def listar_jugadas_dinamico(r_name: str, user_id: int, fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    return await use_cases.listar_jugadas(clean_route, user_id, fecha)

@router.delete("/jugadas_{r_name}/{jugada_id}", name="borrar_jugada_dinamico")
async def borrar_jugada_dinamico(r_name: str, jugada_id: int, user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    success = await use_cases.borrar_jugada(clean_route, jugada_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}

@router.put("/jugadas_{r_name}/{jugada_id}", response_model=schemas.JugadaOut, name="actualizar_jugada_dinamico")
async def actualizar_jugada_dinamico(r_name: str, jugada_id: int, jugada: schemas.JugadaUpdate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    res = await use_cases.actualizar_jugada(clean_route, jugada_id, int(jugada.user_id), jugada.numeros)
    if not res:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return res

@router.get("/{r_name}/predicciones_historico", name="get_loteria_predicciones_historico_dinamico")
def get_predicciones_historico_dinamico(r_name: str, limit: int = 50, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    if clean_route in RESERVED_ROUTES:
        raise HTTPException(status_code=404, detail="Ruta no encontrada")
    cache_key = f"{clean_route}:predicciones_historico:{limit}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_predicciones_historico_generico(clean_route, limit)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=180)
    return res

@router.get("/{r_name}", name="get_loteria_prediccion_dinamico")
def get_prediccion_dinamico(r_name: str, fecha: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = r_name.strip().lower()
    if clean_route in RESERVED_ROUTES:
        raise HTTPException(status_code=404, detail="Ruta no encontrada")
    cache_key = f"{clean_route}:prediccion:{fecha or 'latest'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = use_cases.obtener_prediccion_generico(clean_route, fecha)
    if "error" not in res:
        memory_cache.set(cache_key, res, ttl=300)
    return res



