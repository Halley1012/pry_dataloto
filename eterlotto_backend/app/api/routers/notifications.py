from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any, Optional
from app.api import dependencies
from app.application.notification_use_cases import NotificationUseCases

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("/")
async def list_notifications(
    current_user: Optional[dict] = Depends(dependencies.get_optional_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases)
):
    try:
        user_id = int(current_user["user_id"]) if current_user and current_user.get("user_id") else None
        return await use_cases.obtener_notificaciones(user_id)
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.patch("/{notification_id}/read")
@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: int,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases)
):
    user_id = int(current_user["user_id"])
    success = await use_cases.marcar_como_leida(notification_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notificación no encontrada o acceso denegado")
    return {"success": True}

@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: int,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases)
):
    user_id = int(current_user["user_id"])
    success = await use_cases.eliminar_notificacion(notification_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notificación no encontrada o acceso denegado")
    return {"success": True, "message": "Notificación eliminada exitosamente"}



