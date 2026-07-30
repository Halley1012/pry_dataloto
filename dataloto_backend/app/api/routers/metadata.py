from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from app.api import schemas, dependencies
from app.application.publicidad_use_cases import PublicidadUseCases

router = APIRouter()

@router.get("/categorias")
def listar_categorias(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return use_cases.listar_categorias()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al listar categorías: {str(e)}")

@router.get("/paises")
def listar_paises(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return use_cases.listar_paises()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al listar países: {str(e)}")

@router.get("/departamentos/{pais_id}")
def listar_departamentos_por_pais(pais_id: int, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return use_cases.listar_departamentos_por_pais(pais_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al listar departamentos: {str(e)}")

@router.get("/departamentos1")
def listar_departamentos(use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return use_cases.listar_departamentos()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al listar departamentos: {str(e)}")

@router.get("/ciudades")
def listar_ciudades(departamento_id: Optional[int] = None, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return use_cases.listar_ciudades(departamento_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al listar ciudades: {str(e)}")

@router.get("/loterias", response_model=List[schemas.LoteriaOut])
def listar_loterias(pais_id: int, use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)):
    try:
        return use_cases.listar_loterias(pais_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
