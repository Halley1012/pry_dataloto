from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional, Dict, Any
from app.api import schemas, dependencies
from app.application.jugada_use_cases import JugadaUseCases

from app.core.cache import memory_cache

router = APIRouter()

async def _guardar_jugada_segura(
    use_cases: JugadaUseCases,
    route: str,
    jugada: schemas.JugadaCreate,
):
    try:
        return await use_cases.guardar_jugada(
            route,
            int(jugada.user_id),
            jugada.numeros,
            fecha_sorteo=jugada.fecha_sorteo or jugada.fecha,
            loteria_id=jugada.loteria_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/mis_loterias_activas", response_model=List[str])
async def get_active_lotteries(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_con_jugadas(user_id)

@router.get("/mis_loterias_con_conteo", response_model=Dict[str, int])
async def get_active_lotteries_with_count(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_con_conteo(user_id)

@router.get("/mis_loterias_info", response_model=Dict[str, Dict[str, Any]])
async def get_active_lotteries_info(user_id: int, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.obtener_loterias_info(user_id)

# --- Endpoints universales para cualquier lotería actual o futura ---

RESERVED_ROUTES = {
    "login", "register", "auth", "refresh", "users", "loterias",
    "paises", "departamentos", "ciudades", "categorias", "publicidad",
    "posts", "comments", "notifications", "transacciones", "healthz",
    "docs", "openapi.json", "test", "mis_loterias_activas",
    "mis_loterias_con_conteo", "mis_loterias_info",
}

def _clean_route(r_name: str) -> str:
    clean_route = (r_name or "").strip().lower()
    if not clean_route or clean_route in RESERVED_ROUTES:
        raise HTTPException(status_code=404, detail="Ruta no encontrada")
    return clean_route


def _cache_get(cache_key: str, force_refresh: bool):
    if force_refresh:
        return None
    return memory_cache.get(cache_key)


def _cache_set(cache_key: str, value, ttl: int = 300):
    if isinstance(value, dict) and "error" in value:
        return
    memory_cache.set(cache_key, value, ttl=ttl)


@router.get("/{r_name}/ultimos5", name="get_loteria_ultimos5_dinamico")
def get_ultimos5_dinamico(
    r_name: str,
    sorteo: Optional[str] = None,
    force_refresh: bool = False,
    use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases),
):
    clean_route = _clean_route(r_name)
    cache_key = f"{clean_route}:ultimos5:{(sorteo or 'todos').strip().lower()}"
    cached = _cache_get(cache_key, force_refresh)
    if cached is not None:
        return cached
    res = use_cases.obtener_ultimos5_generico(clean_route, sorteo=sorteo)
    _cache_set(cache_key, res)
    return res


@router.get("/{r_name}/ultimos50", name="get_loteria_ultimos50_dinamico")
def get_ultimos50_dinamico(
    r_name: str,
    sorteo: Optional[str] = None,
    force_refresh: bool = False,
    use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases),
):
    clean_route = _clean_route(r_name)
    cache_key = f"{clean_route}:ultimos50:{(sorteo or 'todos').strip().lower()}"
    cached = _cache_get(cache_key, force_refresh)
    if cached is not None:
        return cached
    res = use_cases.obtener_ultimos50_generico(clean_route, sorteo=sorteo)
    _cache_set(cache_key, res)
    return res


@router.get("/{r_name}/historico_completo", name="get_loteria_historico_completo_dinamico")
def get_historico_completo_dinamico(
    r_name: str,
    sorteo: Optional[str] = None,
    force_refresh: bool = False,
    use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases),
):
    clean_route = _clean_route(r_name)
    cache_key = f"{clean_route}:historico_completo:{(sorteo or 'todos').strip().lower()}"
    cached = _cache_get(cache_key, force_refresh)
    if cached is not None:
        return cached
    res = use_cases.obtener_historico_completo_generico(clean_route, sorteo=sorteo)
    _cache_set(cache_key, res)
    return res


@router.get("/{r_name}/historico", name="get_loteria_historico_dinamico")
def get_historico_dinamico(
    r_name: str,
    limit: int = 10,
    force_refresh: bool = False,
    use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases),
):
    clean_route = _clean_route(r_name)
    safe_limit = max(1, min(int(limit), 200))
    cache_key = f"{clean_route}:historico:{safe_limit}"
    cached = _cache_get(cache_key, force_refresh)
    if cached is not None:
        return cached
    res = use_cases.obtener_historico(clean_route, safe_limit)
    _cache_set(cache_key, res, ttl=180)
    return res


@router.post("/jugadas", response_model=schemas.JugadaOut, name="crear_jugada_unificada")
async def crear_jugada_unificada(jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (jugada.loteria_route or "").strip().lower()
    return await _guardar_jugada_segura(use_cases, clean_route, jugada)


@router.get("/jugadas", response_model=List[schemas.JugadaOut], name="listar_jugadas_unificada")
async def listar_jugadas_unificada(user_id: int, loteria: Optional[str] = None, fecha: Optional[str] = None, loteria_id: Optional[int] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (loteria or "").strip().lower()
    return await use_cases.listar_jugadas(clean_route, user_id, fecha, loteria_id=loteria_id)


@router.delete("/jugadas/{jugada_id}", name="borrar_jugada_unificada")
async def borrar_jugada_unificada(jugada_id: int, user_id: int, loteria: Optional[str] = None, loteria_id: Optional[int] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (loteria or "").strip().lower()
    success = await use_cases.borrar_jugada(clean_route, jugada_id, user_id, loteria_id=loteria_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}


@router.put("/jugadas/{jugada_id}", response_model=schemas.JugadaOut, name="actualizar_jugada_unificada")
async def actualizar_jugada_unificada(jugada_id: int, jugada: schemas.JugadaUpdate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    clean_route = (jugada.loteria_route or "").strip().lower()
    res = await use_cases.actualizar_jugada(clean_route, jugada_id, int(jugada.user_id), jugada.numeros, loteria_id=jugada.loteria_id)
    if not res:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return res


# Compatibilidad con clientes que usan /jugadas_<route>. Sigue siendo 100 % dinámico.
@router.post("/jugadas_{r_name}", response_model=schemas.JugadaOut, name="crear_jugada_dinamico")
async def crear_jugada_dinamico(r_name: str, jugada: schemas.JugadaCreate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await _guardar_jugada_segura(use_cases, _clean_route(r_name), jugada)


@router.get("/jugadas_{r_name}", response_model=List[schemas.JugadaOut], name="listar_jugadas_dinamico")
async def listar_jugadas_dinamico(r_name: str, user_id: int, fecha: Optional[str] = None, loteria_id: Optional[int] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    return await use_cases.listar_jugadas(_clean_route(r_name), user_id, fecha, loteria_id=loteria_id)


@router.delete("/jugadas_{r_name}/{jugada_id}", name="borrar_jugada_dinamico")
async def borrar_jugada_dinamico(r_name: str, jugada_id: int, user_id: int, loteria_id: Optional[int] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    success = await use_cases.borrar_jugada(_clean_route(r_name), jugada_id, user_id, loteria_id=loteria_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return {"message": "Jugada eliminada"}


@router.put("/jugadas_{r_name}/{jugada_id}", response_model=schemas.JugadaOut, name="actualizar_jugada_dinamico")
async def actualizar_jugada_dinamico(r_name: str, jugada_id: int, jugada: schemas.JugadaUpdate, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = await use_cases.actualizar_jugada(_clean_route(r_name), jugada_id, int(jugada.user_id), jugada.numeros, loteria_id=jugada.loteria_id)
    if not res:
        raise HTTPException(status_code=404, detail="Jugada no encontrada")
    return res


@router.get("/{r_name}/predicciones_historico", name="get_loteria_predicciones_historico_dinamico")
def get_predicciones_historico_dinamico(
    r_name: str,
    limit: int = 50,
    force_refresh: bool = False,
    use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases),
):
    clean_route = _clean_route(r_name)
    safe_limit = max(1, min(int(limit), 200))
    cache_key = f"{clean_route}:predicciones_historico:{safe_limit}"
    cached = _cache_get(cache_key, force_refresh)
    if cached is not None:
        return cached
    res = use_cases.obtener_predicciones_historico_generico(clean_route, safe_limit)
    _cache_set(cache_key, res, ttl=180)
    return res


@router.get("/{r_name}", name="get_loteria_prediccion_dinamico")
def get_prediccion_dinamico(
    r_name: str,
    fecha: Optional[str] = None,
    force_refresh: bool = False,
    use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases),
):
    clean_route = _clean_route(r_name)
    cache_key = f"{clean_route}:prediccion:{fecha or 'latest'}"
    cached = _cache_get(cache_key, force_refresh)
    if cached is not None:
        return cached
    res = use_cases.obtener_prediccion_generico(clean_route, fecha)
    _cache_set(cache_key, res)
    return res
