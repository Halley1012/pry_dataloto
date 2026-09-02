from typing import Optional
from fastapi import APIRouter, HTTPException, Depends
from app.api import schemas, dependencies
from app.application.subscription_use_cases import SubscriptionUseCases

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])

@router.post("/confirm")
async def confirm_subscription(
    req: schemas.SubscriptionConfirmRequest,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: SubscriptionUseCases = Depends(dependencies.get_subscription_use_cases)
):
    try:
        user_id = int(current_user["user_id"])
        
        return await use_cases.confirm_subscription(
            user_id=user_id,
            order_id=req.order_id,
            purchase_token=req.purchase_token,
            product_id=req.product_id
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.get("/status/{user_id}")
async def get_subscription_status(
    user_id: int,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: SubscriptionUseCases = Depends(dependencies.get_subscription_use_cases)
):
    if str(user_id) != str(current_user["user_id"]):
        raise HTTPException(status_code=403, detail="No autorizado para ver este estado")
    try:
        return await use_cases.get_subscription_status(user_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")
