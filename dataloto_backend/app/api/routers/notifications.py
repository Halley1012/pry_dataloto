from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any
from app.api import dependencies
from app.application.notification_use_cases import NotificationUseCases

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("/")
async def list_notifications(
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases)
):
    try:
        # Por ahora mostramos todas las generales + las del usuario
        return await use_cases.obtener_notificaciones(int(current_user["user_id"]))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/{notification_id}/read")
@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: int,
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases)
):
    success = await use_cases.marcar_como_leida(notification_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notificación no encontrada")
    return {"success": True}
