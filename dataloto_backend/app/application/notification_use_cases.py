from typing import List, Dict, Any, Optional
from datetime import datetime
from app.domain.ports import NotificationRepositoryPort

class NotificationUseCases:
    def __init__(self, notification_repo: NotificationRepositoryPort):
        self.notification_repo = notification_repo

    async def obtener_notificaciones(self, user_id: Optional[int] = None) -> List[Dict[str, Any]]:
        return await self.notification_repo.list_notifications(user_id)

    async def marcar_como_leida(self, notification_id: int) -> bool:
        return await self.notification_repo.mark_as_read(notification_id)

    async def crear_notificacion_ia(self, loteria_id: int, fecha: datetime, mensaje: str, tipo: str) -> Dict[str, Any]:
        return await self.notification_repo.create_notification(
            loteria_id=loteria_id,
            fecha_sorteo=fecha,
            mensaje=mensaje,
            tipo=tipo
        )
