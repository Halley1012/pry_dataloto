from app.core import config
from fastapi import APIRouter, Depends, Header, HTTPException
from typing import List, Optional
import secrets
import logging
from threading import Lock
import re
from app.api import schemas, dependencies
from app.application.publicidad_use_cases import PublicidadUseCases
from app.core.cache import memory_cache, invalidate_cache, get_data_version, bump_data_version

router = APIRouter()

# Un solo catálogo compartido para /loterias y /loterias?pais_id=...
# Protege los misses de caché de accesos simultáneos (singleflight por worker).
_LOTERIAS_CACHE_KEY = 'metadata:loterias:all:v3'
_loterias_refresh_lock = Lock()
_loterias_last_good = None


@router.get("/categorias")
def listar_categorias(
    lang: str = "es",
    use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases),
):
    normalized_lang = (lang or "es").strip().lower().split("-")[0]
    if not re.fullmatch(r"[a-z]{2,10}", normalized_lang):
        normalized_lang = "es"

    # La caché debe ser independiente por idioma. Así un catálogo consultado
    # primero en español nunca contamina francés, inglés o portugués.
    cache_key = f"metadata:categorias:v2:{normalized_lang}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached

    try:
        res = use_cases.listar_categorias(lang=normalized_lang)
        if res and res.get("success"):
            memory_cache.set(cache_key, res, ttl=300)
        return res
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/paises", response_model=schemas.PaisesResponse)
def listar_paises(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    # v2 starts a fresh server-side entry after adding country-owned media.
    # This is deliberately public: the same country card must work for free
    # and premium users without depending on entitlement state.
    cache_key = "metadata:paises:v2"
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
    use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases),
):
    """Catálogo seguro frente a reintentos masivos del Home.

    `force_refresh` se conserva por compatibilidad con Flutter, pero desde una
    llamada pública NO evita la caché ni dispara consultas duplicadas.
    Airflow actualiza los datos mediante /internal/cache/invalidate autenticado.
    """
    global _loterias_last_good

    # Se construye siempre el catálogo completo; el filtrado por país se hace
    # en memoria. Dos solicitudes paralelas del Home comparten la misma carga.
    all_loterias = memory_cache.get(_LOTERIAS_CACHE_KEY)
    if all_loterias is None:
        with _loterias_refresh_lock:
            all_loterias = memory_cache.get(_LOTERIAS_CACHE_KEY)
            if all_loterias is None:
                try:
                    # Capturar la versión evita dar por fresca una reconstrucción
                    # cuya fuente fue invalidada durante la consulta.
                    version_at_start = get_data_version()
                    all_loterias = use_cases.listar_loterias(None)
                    if all_loterias is not None:
                        if get_data_version() == version_at_start:
                            memory_cache.set(_LOTERIAS_CACHE_KEY, all_loterias, ttl=300)
                        _loterias_last_good = all_loterias
                except Exception:
                    logging.exception('Error reconstruyendo el catálogo de loterías')
                    if _loterias_last_good is not None:
                        logging.warning('Sirviendo último catálogo válido por fallo temporal de BD')
                        all_loterias = _loterias_last_good
                    else:
                        raise HTTPException(
                            status_code=500, detail='Error interno del servidor'
                        )

    if pais_id is None:
        return all_loterias
    return [lot for lot in all_loterias if lot.get('pais_id') == pais_id]


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

    # Las ejecuciones de modelos y las publicaciones de medios por país son
    # poco frecuentes. Limpiar la caché RAM completa aquí evita
    # inconsistencias entre catálogo, imágenes de país, resultados,
    # predicciones y jackpot; se vuelve a poblar de forma natural.
    # Publicar primero la nueva versión: evita carreras con lectores que
    # estén reconstruyendo el catálogo mientras llega la invalidación.
    version = bump_data_version()
    invalidate_cache()
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
