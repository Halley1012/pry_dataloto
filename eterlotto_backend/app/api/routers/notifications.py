import secrets
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException

from app.api import dependencies, schemas
from app.application.notification_use_cases import NotificationUseCases
from app.core import config


router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/")
async def list_notifications(
    current_user: Optional[dict] = Depends(dependencies.get_optional_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases),
):
    try:
        user_id = (
            int(current_user["user_id"])
            if current_user and current_user.get("user_id")
            else None
        )
        return await use_cases.obtener_notificaciones(user_id)
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(
            "[NOTIFICATIONS] event=LIST_ERROR error=%s",
            type(e).__name__,
        )
        raise HTTPException(status_code=500, detail="Error interno del servidor")


@router.post("/publish")
async def publish_notification(
    payload: schemas.NotificationPublishRequest,
    x_notification_key: Optional[str] = Header(None, alias="X-Notification-Key"),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases),
):
    expected = config.NOTIFICATION_INTERNAL_KEY
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="Publicación interna de notificaciones no configurada",
        )
    if not x_notification_key or not secrets.compare_digest(
        x_notification_key,
        expected,
    ):
        raise HTTPException(status_code=403, detail="Clave de notificación inválida")

    return await use_cases.crear_notificacion(
        loteria_id=payload.loteria_id,
        fecha=payload.fecha_sorteo,
        mensaje=payload.mensaje,
        tipo=payload.tipo,
        user_id=payload.user_id,
    )


@router.post("/test-push")
async def test_push(
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases),
):
    if not config.ENABLE_NOTIFICATION_TEST_ENDPOINT:
        raise HTTPException(status_code=404, detail="Endpoint no disponible")

    return await use_cases.crear_notificacion(
        loteria_id=None,
        fecha=None,
        mensaje="Prueba de notificaciones Eterlotto",
        tipo="test",
        user_id=int(current_user["user_id"]),
    )


@router.patch("/{notification_id}/read")
@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: int,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases),
):
    user_id = int(current_user["user_id"])
    success = await use_cases.marcar_como_leida(notification_id, user_id)
    if not success:
        raise HTTPException(
            status_code=404,
            detail="Notificación no encontrada o acceso denegado",
        )
    return {"success": True}


@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: int,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: NotificationUseCases = Depends(dependencies.get_notification_use_cases),
):
    user_id = int(current_user["user_id"])
    success = await use_cases.eliminar_notificacion(notification_id, user_id)
    if not success:
        raise HTTPException(
            status_code=404,
            detail="Notificación no encontrada o acceso denegado",
        )
    return {"success": True, "message": "Notificación eliminada exitosamente"}
