from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from app.api import schemas, dependencies
from app.application.publicidad_use_cases import PublicidadUseCases
from app.core.cache import memory_cache

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
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

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
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

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
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

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
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

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
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

@router.get("/loterias", response_model=List[schemas.LoteriaOut])
def listar_loterias(pais_id: Optional[int] = None, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    cache_key = f"metadata:loterias:{pais_id or 'all'}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        res = use_cases.listar_loterias(pais_id)
        if res is not None:
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor"))

