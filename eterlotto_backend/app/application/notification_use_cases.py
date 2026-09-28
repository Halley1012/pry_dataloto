import asyncio
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from app.core.notification_i18n import notification_i18n
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

    @staticmethod
    def _params(value: Any) -> Dict[str, Any]:
        return dict(value) if isinstance(value, dict) else {}

    def _localize_notification(self, item: Dict[str, Any]) -> Dict[str, Any]:
        result = dict(item)
        locale = result.pop("usuario_idioma", None)
        key = result.get("message_key")
        params = self._params(result.get("message_params"))
        result["mensaje"] = notification_i18n.render(
            key,
            params,
            locale,
            fallback_text=str(result.get("mensaje") or ""),
        )
        # El cliente móvil no necesita conocer la estructura interna de i18n.
        result.pop("message_key", None)
        result.pop("message_params", None)
        return result

    async def obtener_notificaciones(
        self,
        user_id: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        rows = await self.notification_repo.list_notifications(user_id)
        return [self._localize_notification(row) for row in rows]

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
        message_key: Optional[str],
        message_params: Optional[Dict[str, Any]],
        tipo: str,
        user_id: Optional[int],
        fecha_sorteo: Optional[datetime],
    ) -> Dict[str, Any]:
        targets = await self.notification_repo.list_push_targets(
            loteria_id=loteria_id,
            user_id=user_id,
            fecha_sorteo=fecha_sorteo,
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
                locale = target.get("idioma")
                localized_body = notification_i18n.render(
                    message_key,
                    message_params,
                    locale,
                    fallback_text=mensaje,
                )
                result = await self.push_service.send(
                    token=token,
                    title=notification_i18n.title(locale),
                    body=localized_body,
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
        mensaje: Optional[str],
        tipo: str,
        user_id: Optional[int] = None,
        message_key: Optional[str] = None,
        message_params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        params = dict(message_params or {})
        fallback_message = str(mensaje or "").strip()
        if not fallback_message and message_key:
            fallback_message = notification_i18n.render(
                message_key,
                params,
                notification_i18n.fallback_locale,
                fallback_text=message_key,
            )
        if not fallback_message:
            fallback_message = "Eterlotto"

        created = await self.notification_repo.create_notification(
            loteria_id=loteria_id,
            fecha_sorteo=fecha,
            mensaje=fallback_message,
            tipo=tipo,
            user_id=user_id,
            message_key=message_key,
            message_params=params,
        )

        notification = created.get("notification") or {}

        if not created.get("created", True) or not notification:
            logger.info(
                "[NOTIFICATIONS] event=NOTIFICATION_DUPLICATE_SKIPPED loteria_id=%s user_id=%s tipo=%s fecha=%s",
                loteria_id,
                user_id,
                tipo,
                fecha,
            )
            return {
                **created,
                "push": {
                    "targets": 0,
                    "sent": 0,
                    "failed": 0,
                    "invalid_tokens": 0,
                    "skipped_duplicate": True,
                },
            }

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
                mensaje=fallback_message,
                message_key=message_key,
                message_params=params,
                tipo=tipo,
                user_id=user_id,
                fecha_sorteo=fecha,
            )
        except Exception as exc:
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
