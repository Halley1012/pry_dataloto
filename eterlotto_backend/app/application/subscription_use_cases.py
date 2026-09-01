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

    async def get_subscription_status(self, user_id: int) -> Dict[str, Any]:
        user = await self.user_repo.find_by_id(user_id)
        if not user:
            raise ValueError("Usuario no encontrado")

        is_premium = user.get("is_premium", False)
        expires_at = user.get("premium_expires_at")

        if is_premium and expires_at:
            now_tz = datetime.now(expires_at.tzinfo) if expires_at.tzinfo else datetime.utcnow()
            if expires_at < now_tz:
                is_premium = False
                # En un diseño puro, un GET no altera estado, pero mantenemos compatibilidad por ahora
                await self.user_repo.set_premium(
                    user_id=user_id,
                    is_premium=False,
                    expires_at=expires_at
                )

        return {
            "success": True,
            "user_id": user_id,
            "is_premium": is_premium,
            "expires_at": expires_at.isoformat() if isinstance(expires_at, datetime) else expires_at
        }
