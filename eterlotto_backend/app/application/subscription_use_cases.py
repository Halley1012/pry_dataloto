from datetime import datetime
from typing import Dict, Any, Optional
from app.domain.ports import UserRepositoryPort, GooglePlayPort

class SubscriptionUseCases:
    ALLOWED_PRODUCTS = {"eterlotto_monthly_sub"}

    def __init__(self, user_repo: UserRepositoryPort, google_play: GooglePlayPort):
        self.user_repo = user_repo
        self.google_play = google_play

    async def confirm_subscription(self, user_id: int, order_id: str, purchase_token: str, product_id: str) -> Dict[str, Any]:
        user = await self.user_repo.find_by_id(user_id)
        if not user:
            raise ValueError("Usuario no encontrado")

        if product_id not in self.ALLOWED_PRODUCTS:
            raise ValueError("Producto de suscripción no autorizado")

        google_result = await self.google_play.verify_subscription_token(
            package_name="com.lumieter.eterlotto",
            product_id=product_id,
            purchase_token=purchase_token
        )

        if not google_result["is_valid"]:
            raise ValueError("La suscripción no es válida para este producto")

        if not google_result["is_active"]:
            raise ValueError("La suscripción no está activa")

        expires_at = google_result["expiry_time"]

        res = await self.user_repo.set_premium(
            user_id=user_id,
            is_premium=True,
            expires_at=expires_at,
            order_id=order_id,
            purchase_token=purchase_token,
            product_id=product_id
        )

        return {
            "success": True,
            "message": "Suscripción activada con éxito en la base de datos",
            "is_premium": True,
            "expires_at": res.get("expires_at") if res else expires_at
        }

    async def process_rtdn_notification(
        self,
        purchase_token: str,
        product_id: Optional[str] = None,
        notification_type: Optional[int] = None
    ) -> Dict[str, Any]:
        import logging
        logger = logging.getLogger(__name__)

        logger.info(
            "RTDN RECEIVED | purchase_token=%s | product_id=%s | notification_type=%s",
            purchase_token,
            product_id,
            notification_type,
        )

        user_id = await self.user_repo.find_user_id_by_purchase_token(purchase_token)
        if not user_id:
            return {
                "success": True,
                "ignored": True,
                "reason": "purchase_token_not_found"
            }

        resolved_product_id = product_id or "eterlotto_monthly_sub"
        if resolved_product_id not in self.ALLOWED_PRODUCTS:
            raise ValueError("Producto de suscripción no autorizado")

        google_data = await self.google_play.verify_subscription_token(
            package_name="com.lumieter.eterlotto",
            product_id=resolved_product_id,
            purchase_token=purchase_token
        )

        raw_state = google_data.get("raw_state")
        if raw_state == "ERROR":
            # No revocar VIP por un fallo temporal de comunicación con Google.
            # Lanzamos error para que Pub/Sub reintente la entrega.
            raise RuntimeError("No fue posible verificar la suscripción con Google Play")

        is_valid = bool(google_data.get("is_valid", False))
        expires_at = google_data.get("expiry_time")
        raw_state = google_data.get("raw_state")
        is_active = bool(google_data.get("is_active", False))
        
        logger.info(
            "RTDN GOOGLE STATE | purchase_token=%s | notification_type=%s | raw_state=%s | is_active=%s | expires_at=%s",
            purchase_token,
            notification_type,
            raw_state,
            is_active,
            expires_at,
        )

        is_premium = False
        status = "expired"

        if is_valid:
            if raw_state == "SUBSCRIPTION_STATE_ACTIVE":
                is_premium = True
                status = "active"
            elif raw_state == "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
                is_premium = True
                status = "grace_period"
            elif raw_state == "SUBSCRIPTION_STATE_CANCELED":
                if expires_at:
                    from datetime import timezone
                    now_utc = datetime.now(timezone.utc)
                    expires_at_utc = expires_at.astimezone(timezone.utc) if expires_at.tzinfo else expires_at.replace(tzinfo=timezone.utc)
                    if expires_at_utc > now_utc:
                        is_premium = True
                        status = "canceled"
                    else:
                        is_premium = False
                        status = "expired"
                else:
                    is_premium = False
                    status = "expired"
            elif raw_state == "SUBSCRIPTION_STATE_ON_HOLD":
                is_premium = False
                status = "on_hold"
            elif raw_state == "SUBSCRIPTION_STATE_PAUSED":
                is_premium = False
                status = "paused"
            elif raw_state == "SUBSCRIPTION_STATE_PENDING":
                is_premium = False
                status = "pending"
            elif raw_state == "SUBSCRIPTION_STATE_EXPIRED":
                is_premium = False
                status = "expired"
            else:
                is_premium = False
                status = "expired"

            # Overrides basados en el RTDN de Google Play si la API no es lo suficientemente explícita
            if notification_type == 12: # SUBSCRIPTION_REVOKED
                is_premium = False
                status = "revoked"

        logger.info(
            "RTDN DB UPDATE | user_id=%s | status=%s | is_premium=%s | expires_at=%s",
            user_id,
            status,
            is_premium,
            expires_at,
        )

        result = await self.user_repo.update_subscription_state(
            user_id=user_id,
            is_premium=is_premium,
            expires_at=expires_at,
            purchase_token=purchase_token,
            product_id=resolved_product_id,
            order_id=None,
            status=status
        )

        return {
            "success": True,
            "user_id": user_id,
            "is_premium": is_premium,
            "status": status,
            "expires_at": expires_at.isoformat() if isinstance(expires_at, datetime) else expires_at,
            "updated": result.get("success", True)
        }

    async def get_subscription_status(self, user_id: int) -> Dict[str, Any]:
        user = await self.user_repo.find_by_id(user_id)
        if not user:
            raise ValueError("Usuario no encontrado")

        is_premium = bool(user.get("is_premium", False))
        expires_at = user.get("premium_expires_at")

        if expires_at:
            now_tz = (
                datetime.now(expires_at.tzinfo)
                if expires_at.tzinfo
                else datetime.utcnow()
            )

            if expires_at <= now_tz:
                is_premium = False
                # Reconciliación defensiva:
                # no crea una fila nueva y no sobrescribe google_order_id.
                await self.user_repo.mark_expired_subscriptions(user_id)
            elif is_premium is False:
                # No reactiva una suscripción solo por una fecha futura.
                # La reactivación debe venir de Google Play mediante /confirm o RTDN.
                pass

        return {
            "success": True,
            "user_id": user_id,
            "is_premium": is_premium,
            "expires_at": (
                expires_at.isoformat()
                if isinstance(expires_at, datetime)
                else expires_at
            )
        }
