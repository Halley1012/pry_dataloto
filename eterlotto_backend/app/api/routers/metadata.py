from app.core import config
from fastapi import APIRouter, Depends, Header, HTTPException
from typing import List, Optional
import secrets
from app.api import schemas, dependencies
from app.application.publicidad_use_cases import PublicidadUseCases
from app.core.cache import memory_cache, invalidate_cache, get_data_version, bump_data_version

router = APIRouter()

@router.get("/categorias")
def listar_categorias(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    cache_key = "metadata:categorias"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        res = use_cases.listar_categorias()
        if res and res.get("success"):
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/paises")
def listar_paises(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    cache_key = "metadata:paises"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        res = use_cases.listar_paises()
        if res and res.get("success"):
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/departamentos/{pais_id}")
def listar_departamentos_por_pais(pais_id: int, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    cache_key = f"metadata:departamentos:{pais_id}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        res = use_cases.listar_departamentos_por_pais(pais_id)
        if res and res.get("success"):
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/departamentos1")
def listar_departamentos(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    cache_key = "metadata:departamentos:all"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        res = use_cases.listar_departamentos()
        if res and res.get("success"):
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/ciudades")
def listar_ciudades(departamento_id: Optional[int] = None, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    cache_key = f"metadata:ciudades:{departamento_id or 'all'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        res = use_cases.listar_ciudades(departamento_id)
        if res and res.get("success"):
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/loterias", response_model=List[schemas.LoteriaOut])
def listar_loterias(
    pais_id: Optional[int] = None,
    force_refresh: bool = False,
    use_cases: PublicidadUseCases = Depends(
        dependencies.get_publicidad_use_cases
        ),
    ):
    cache_key = f"metadata:loterias:{pais_id or 'all'}"

    # Navegación normal:
    # usar caché backend si todavía está disponible.
    #
    # Pull-to-refresh:
    # force_refresh=True ignora la caché y consulta nuevamente la BD.
    if not force_refresh:
        cached = memory_cache.get(cache_key)
        if cached is not None:
            return cached

    try:
        res = use_cases.listar_loterias(pais_id)

        # Tanto una consulta normal como un force_refresh exitoso
        # reemplazan la caché con los datos más recientes de la BD.
        if res is not None:
            memory_cache.set(cache_key, res, ttl=300)

        return res

    except Exception as e:
        import logging

        logging.error(
            f"Error listando loterías "
            f"(pais_id={pais_id}, force_refresh={force_refresh}): {e}"
        )
        raise HTTPException(
            status_code=500,
            detail="Error interno del servidor",
        )


@router.get("/metadata/data-version")
def get_dynamic_data_version():
    """Marca liviana para que Flutter detecte publicaciones nuevas sin tocar BD."""
    return {"version": get_data_version()}


@router.post("/internal/cache/invalidate")
def invalidate_dynamic_cache(
    x_internal_key: Optional[str] = Header(None, alias="X-Internal-Key"),
):
    """Invalidación interna llamada por Airflow al terminar un modelo."""
    expected = config.NOTIFICATION_INTERNAL_KEY
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="Clave interna no configurada",
        )

    if not x_internal_key or not secrets.compare_digest(
        x_internal_key,
        expected,
    ):
        raise HTTPException(status_code=403, detail="Clave interna inválida")

    # Las ejecuciones de modelos son poco frecuentes. Limpiar la caché RAM
    # completa aquí evita inconsistencias entre catálogo, resultados,
    # predicciones y jackpot; se vuelve a poblar de forma natural.
    invalidate_cache()
    version = bump_data_version()
    return {
        "success": True,
        "version": version,
    }


import os

@router.get("/metadata/app-config")
def get_app_config():
    try:
        min_build = int(os.getenv("MIN_BUILD_NUMBER", "22"))
    except (ValueError, TypeError):
        min_build = 22

    return {
        "success": True,
        "min_build_number": min_build,
        "store_url_android": config.STORE_URL_ANDROID,
        "store_url_ios": config.STORE_URL_IOS,
    }
