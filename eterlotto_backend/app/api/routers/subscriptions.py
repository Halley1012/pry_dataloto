import base64
import json
import logging
import os
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Request
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token

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


PUBSUB_PUSH_SERVICE_ACCOUNT = "eterlotto-play-billing@dataloto.iam.gserviceaccount.com"
PUBSUB_OIDC_AUDIENCE = os.getenv(
    "PUBSUB_OIDC_AUDIENCE",
    "https://pry-dataloto.onrender.com/subscriptions/rtdn",
)

def _verify_pubsub_oidc(request: Request) -> dict:
    authorization = request.headers.get("Authorization")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Pub/Sub OIDC token")

    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing Pub/Sub OIDC token")

    try:
        claims = id_token.verify_oauth2_token(
            token,
            GoogleAuthRequest(),
            audience=PUBSUB_OIDC_AUDIENCE,
        )
    except Exception:
        logging.exception("Invalid Pub/Sub OIDC token")
        raise HTTPException(status_code=401, detail="Invalid Pub/Sub OIDC token")

    if claims.get("iss") not in {"accounts.google.com", "https://accounts.google.com"}:
        raise HTTPException(status_code=401, detail="Invalid OIDC issuer")

    if claims.get("email") != PUBSUB_PUSH_SERVICE_ACCOUNT:
        raise HTTPException(status_code=403, detail="Invalid Pub/Sub service account")

    if claims.get("email_verified") is not True:
        raise HTTPException(status_code=403, detail="Unverified Pub/Sub service account")

    return claims


@router.post("/rtdn")
async def receive_rtdn(
    request: Request,
    use_cases: SubscriptionUseCases = Depends(dependencies.get_subscription_use_cases)
):
    _verify_pubsub_oidc(request)

    try:
        body = await request.json()
        message = body.get("message")
        if not message:
            raise HTTPException(status_code=400, detail="Missing Pub/Sub message")

        encoded_data = message.get("data")
        if not encoded_data:
            raise HTTPException(status_code=400, detail="Missing Pub/Sub message data")

        try:
            decoded_data = base64.b64decode(encoded_data, validate=True).decode("utf-8")
            notification = json.loads(decoded_data)
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HTTPException(status_code=400, detail="Invalid Pub/Sub message data") from exc

        logging.info("RTDN received")

        subscription_notification = notification.get("subscriptionNotification")
        if not subscription_notification:
            return {
                "success": True,
                "ignored": True,
                "reason": "No subscriptionNotification found"
            }

        purchase_token = subscription_notification.get("purchaseToken")
        product_id = subscription_notification.get("subscriptionId")
        notification_type = subscription_notification.get("notificationType")

        if not purchase_token:
            raise HTTPException(status_code=400, detail="Missing purchaseToken")

        logging.info(
            "RTDN subscription event: type=%s product=%s",
            notification_type,
            product_id
        )

        return await use_cases.process_rtdn_notification(
            purchase_token=purchase_token,
            product_id=product_id
        )

    except HTTPException:
        raise
    except Exception:
        logging.exception("Error processing Google Play RTDN")
        raise HTTPException(status_code=500, detail="Error procesando RTDN")
