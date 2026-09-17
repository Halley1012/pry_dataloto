import asyncio
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from app.core import config
from app.domain.ports import (
    NotificationRepositoryPort,
    PushNotificationPort,
    UserRepositoryPort,
)


logger = logging.getLogger(__name__)


class NotificationUseCases:
    def __init__(
        self,
        notification_repo: NotificationRepositoryPort,
        user_repo: UserRepositoryPort,
        push_service: PushNotificationPort,
    ):
        self.notification_repo = notification_repo
        self.user_repo = user_repo
        self.push_service = push_service

    async def obtener_notificaciones(
        self,
        user_id: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        return await self.notification_repo.list_notifications(user_id)

    async def marcar_como_leida(
        self,
        notification_id: int,
        user_id: int,
    ) -> bool:
        return await self.notification_repo.mark_as_read(notification_id, user_id)

    async def eliminar_notificacion(
        self,
        notification_id: int,
        user_id: int,
    ) -> bool:
        return await self.notification_repo.delete_notification(
            notification_id,
            user_id,
        )

    async def _send_pushes(
        self,
        *,
        notification_id: int,
        loteria_id: Optional[int],
        mensaje: str,
        tipo: str,
        user_id: Optional[int],
    ) -> Dict[str, Any]:
        targets = await self.notification_repo.list_push_targets(
            loteria_id=loteria_id,
            user_id=user_id,
        )

        if not targets:
            logger.info(
                "[NOTIFICATIONS] event=PUSH_NO_TARGETS notification_id=%s loteria_id=%s user_id=%s",
                notification_id,
                loteria_id,
                user_id,
            )
            return {
                "targets": 0,
                "sent": 0,
                "failed": 0,
                "invalid_tokens": 0,
            }

        logger.info(
            "[NOTIFICATIONS] event=PUSH_SEND_STARTED notification_id=%s targets=%s loteria_id=%s user_id=%s",
            notification_id,
            len(targets),
            loteria_id,
            user_id,
        )

        semaphore = asyncio.Semaphore(20)

        async def send_one(target: Dict[str, Any]) -> Dict[str, Any]:
            async with semaphore:
                token = str(target["fcm_token"])
                result = await self.push_service.send(
                    token=token,
                    title=config.PUSH_NOTIFICATION_TITLE,
                    body=mensaje,
                    data={
                        "notification_id": notification_id,
                        "loteria_id": loteria_id,
                        "tipo": tipo,
                        "route": "/notifications",
                    },
                )
                if result.get("invalid_token"):
                    await self.user_repo.clear_fcm_token(
                        int(target["user_id"]),
                        expected_token=token,
                    )
                return result

        results = await asyncio.gather(
            *(send_one(target) for target in targets),
            return_exceptions=True,
        )

        sent = 0
        failed = 0
        invalid = 0
        for result in results:
            if isinstance(result, Exception):
                failed += 1
                logger.warning(
                    "[NOTIFICATIONS] event=PUSH_SEND_EXCEPTION error=%s",
                    type(result).__name__,
                )
                continue
            if result.get("success"):
                sent += 1
            else:
                failed += 1
                if result.get("invalid_token"):
                    invalid += 1

        logger.info(
            "[NOTIFICATIONS] event=PUSH_BATCH_COMPLETED notification_id=%s targets=%s sent=%s failed=%s invalid_tokens=%s",
            notification_id,
            len(targets),
            sent,
            failed,
            invalid,
        )
        return {
            "targets": len(targets),
            "sent": sent,
            "failed": failed,
            "invalid_tokens": invalid,
        }

    async def crear_notificacion(
        self,
        *,
        loteria_id: Optional[int],
        fecha: Optional[datetime],
        mensaje: str,
        tipo: str,
        user_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        created = await self.notification_repo.create_notification(
            loteria_id=loteria_id,
            fecha_sorteo=fecha,
            mensaje=mensaje,
            tipo=tipo,
            user_id=user_id,
        )

        notification = created.get("notification") or {}
        notification_id = int(notification["id"])

        logger.info(
            "[NOTIFICATIONS] event=NOTIFICATION_CREATED notification_id=%s loteria_id=%s user_id=%s tipo=%s",
            notification_id,
            loteria_id,
            user_id,
            tipo,
        )

        try:
            push = await self._send_pushes(
                notification_id=notification_id,
                loteria_id=loteria_id,
                mensaje=mensaje,
                tipo=tipo,
                user_id=user_id,
            )
        except Exception as exc:
            # El buzón interno nunca se pierde porque FCM esté temporalmente caído.
            logger.error(
                "[NOTIFICATIONS] event=PUSH_BATCH_ERROR notification_id=%s error=%s",
                notification_id,
                type(exc).__name__,
            )
            push = {
                "targets": 0,
                "sent": 0,
                "failed": 1,
                "invalid_tokens": 0,
                "error": type(exc).__name__,
            }

        return {
            **created,
            "push": push,
        }

    async def crear_notificacion_ia(
        self,
        loteria_id: int,
        fecha: datetime,
        mensaje: str,
        tipo: str,
    ) -> Dict[str, Any]:
        # Firma legacy conservada para predictores/DAGs existentes.
        return await self.crear_notificacion(
            loteria_id=loteria_id,
            fecha=fecha,
            mensaje=mensaje,
            tipo=tipo,
            user_id=None,
        )
