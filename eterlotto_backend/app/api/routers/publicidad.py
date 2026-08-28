from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional, Dict, Any
from app.api import schemas, dependencies
from app.application.publicidad_use_cases import PublicidadUseCases

router = APIRouter()

@router.get("/publicidad")
async def listar_publicidad(
    query: schemas.PublicidadQuery = Depends(),
    current_user: Optional[dict] = Depends(dependencies.get_optional_current_user),
    use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)
):
    user_id = None
    if current_user and current_user.get("user_id"):
        try:
            user_id = int(current_user["user_id"])
        except (ValueError, TypeError):
            pass

    filters = {
        "pais_id": query.pais_id,
        "departamento_id": query.departamento_id,
        "ciudad_id": query.ciudad_id,
        "categoria_id": query.categoria_id,
        "titulo": query.titulo,
        "user_id": user_id
    }
    try:
        return await use_cases.listar_publicidad(filters, query.limit, query.offset)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al listar la publicidad: {str(e)}")

@router.post("/publicidad")
async def crear_publicidad(request: dict, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.crear_publicidad(user_id, request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/publicidad/{publicidad_id}")
async def eliminar_publicidad(publicidad_id: int, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.eliminar_publicidad(publicidad_id, user_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.put("/publicidad/{publicidad_id}/aprobar")
async def aprobar_publicidad(publicidad_id: int, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return await use_cases.aprobar_publicidad(publicidad_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al aprobar anuncio: {str(e)}")

@router.get("/mis_publicidades")
async def listar_mis_publicidades(current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = current_user.get("user_id")
    try:
        user_id = int(user_id)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="ID de usuario inválido")
    try:
        return await use_cases.listar_mis_publicidades(user_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/publicidad/{id}")
async def actualizar_publicidad(id: int, request: dict, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.actualizar_publicidad(id, user_id, request)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/publicidad/{id}/favorito")
async def toggle_favorito_publicidad(id: int, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    try:
        return await use_cases.toggle_favorito(user_id, id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/publicidad/{id}/calificar")
async def calificar_publicidad(id: int, request: dict, current_user: dict = Depends(dependencies.get_current_user), use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    user_id = int(current_user["user_id"])
    estrellas = int(request.get("estrellas", 5))
    try:
        return await use_cases.calificar_publicidad(user_id, id, estrellas)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

