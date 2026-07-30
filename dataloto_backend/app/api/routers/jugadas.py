from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from app.api import schemas, dependencies
from app.application.jugada_use_cases import JugadaUseCases

router = APIRouter()

# --- MLoto endpoints ---
@router.get("/mloto")
def get_mloto_prediction(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_prediccion_mloto()
    if "error" in res:
        return res
    return res

@router.get("/mloto/ultimos5")
def get_mloto_ultimos5(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_ultimos5_mloto()
    if "error" in res:
        return res
    return res

@router.get("/mloto/historico_completo")
def get_mloto_historico_completo(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_historico_completo_mloto()
    if "error" in res:
        return res
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


# --- Bloto endpoints ---
@router.get("/bloto")
def get_bloto_prediction(use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_prediccion_bloto()
    if "error" in res:
        return res
    return res

@router.get("/bloto/ultimos5")
def get_bloto_ultimos5(sorteo: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_ultimos5_bloto(sorteo=sorteo)
    if "error" in res:
        return res
    return res

@router.get("/bloto/historico_completo")
def get_bloto_historico_completo(sorteo: Optional[str] = None, use_cases: JugadaUseCases = Depends(dependencies.get_jugada_use_cases)):
    res = use_cases.obtener_historico_completo_bloto(sorteo=sorteo)
    if "error" in res:
        return res
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
