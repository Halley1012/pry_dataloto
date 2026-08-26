from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Depends
from app.api import schemas
from app.infrastructure.repositories.user_repository import PostgresUserRepository

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])
user_repo = PostgresUserRepository()

@router.post("/confirm")
async def confirm_subscription(req: schemas.SubscriptionConfirmRequest):
    """
    Confirma y activa el estado VIP/Premium del usuario en la base de datos tras una compra en Google Play.
    """
    try:
        user = await user_repo.find_by_id(req.user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")

        # Asignar vencimiento de 35 días por defecto para el ciclo mensual (con 5 días de gracia)
        expires_at = datetime.utcnow() + timedelta(days=35)

        res = await user_repo.set_premium(
            user_id=req.user_id,
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
        raise HTTPException(status_code=500, detail=f"Error al registrar suscripción: {str(e)}")

@router.get("/status/{user_id}")
async def get_subscription_status(user_id: int):
    """
    Consulta el estado VIP/Premium del usuario en la base de datos.
    """
    try:
        user = await user_repo.find_by_id(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")

        is_premium = user.get("is_premium", False)
        expires_at = user.get("premium_expires_at")

        # Si tiene fecha de expiración, comprobar que no haya vencido
        if is_premium and expires_at:
            if isinstance(expires_at, datetime) and expires_at < datetime.now(expires_at.tzinfo):
                is_premium = False

        return {
            "success": True,
            "user_id": user_id,
            "is_premium": is_premium,
            "expires_at": expires_at.isoformat() if isinstance(expires_at, datetime) else expires_at
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar estado de suscripción: {str(e)}")
