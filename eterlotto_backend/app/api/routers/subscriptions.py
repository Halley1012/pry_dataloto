from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends
from app.api import schemas, dependencies
from app.infrastructure.repositories.user_repository import PostgresUserRepository

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])
user_repo = PostgresUserRepository()

@router.post("/confirm")
async def confirm_subscription(
    req: schemas.SubscriptionConfirmRequest,
    current_user: dict = Depends(dependencies.get_current_user)
):
    """
    Confirma y activa el estado VIP/Premium del usuario en la base de datos tras una compra en Google Play.
    El usuario se extrae de forma 100% segura desde su token JWT Bearer.
    """
    try:
        user_id = current_user.get("id") or req.user_id
        if not user_id:
            raise HTTPException(status_code=401, detail="Usuario no autenticado")

        user = await user_repo.find_by_id(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")

        # Asignar vencimiento de 35 días por defecto para el ciclo mensual (con 5 días de gracia)
        expires_at = datetime.utcnow() + timedelta(days=35)

        res = await user_repo.set_premium(
            user_id=user_id,
            is_premium=True,
            expires_at=expires_at,
            order_id=req.order_id,
            purchase_token=req.purchase_token,
            product_id=req.product_id
        )

        return {
            "success": True,
            "message": "Suscripción activada con éxito en la base de datos",
            "is_premium": True,
            "expires_at": res.get("expires_at")
        }
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

@router.get("/status/{user_id}")
async def get_subscription_status(user_id: int):
    """
    Consulta el estado VIP/Premium del usuario en la base de datos.
    Si ya venció, actualiza automáticamente la base de datos a is_premium = False.
    """
    try:
        user = await user_repo.find_by_id(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")

        is_premium = user.get("is_premium", False)
        expires_at = user.get("premium_expires_at")

        # Si tiene fecha de expiración, comprobar si ya venció
        if is_premium and expires_at:
            now_tz = datetime.now(expires_at.tzinfo) if expires_at.tzinfo else datetime.utcnow()
            if expires_at < now_tz:
                is_premium = False
                # Sincronizar en base de datos para que quede en False
                await user_repo.set_premium(
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
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.error("Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")}")

