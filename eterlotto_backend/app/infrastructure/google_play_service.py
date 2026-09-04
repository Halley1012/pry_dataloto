import os
import json
import base64
from typing import Dict, Any
from datetime import datetime
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from app.domain.ports import GooglePlayPort

class GooglePlayService(GooglePlayPort):
    def __init__(self):
        self.scopes = ["https://www.googleapis.com/auth/androidpublisher"]
        self.credentials = self._load_credentials()

    def _load_credentials(self) -> Credentials:
        b64_creds = os.getenv("GOOGLE_PLAY_CREDENTIALS_B64")
        if not b64_creds:
            raise ValueError("GOOGLE_PLAY_CREDENTIALS_B64 environment variable is not set")
            
        try:
            json_str = base64.b64decode(b64_creds).decode('utf-8')
            creds_info = json.loads(json_str)
            return Credentials.from_service_account_info(creds_info, scopes=self.scopes)
        except Exception as e:
            raise ValueError("Invalid GOOGLE_PLAY_CREDENTIALS_B64 configuration")

    async def verify_subscription_token(self, package_name: str, product_id: str, purchase_token: str) -> Dict[str, Any]:
        """
        Verify the subscription using Google Play Developer API (purchases.subscriptionsv2.get)
        """
        try:
            # Note: googleapiclient is synchronous, so we run it directly or could use asyncio.to_thread
            # For simplicity in this implementation, we run it directly.
            service = build("androidpublisher", "v3", credentials=self.credentials, cache_discovery=False)
            
            response = service.purchases().subscriptionsv2().get(
                packageName=package_name,
                token=purchase_token
            ).execute()
            
            # Response contains: subscriptionState, lineItems (which has productId and expiryTime)
            state = response.get("subscriptionState")
            line_items = response.get("lineItems", [])
            
            is_valid = False
            is_active = False
            expiry_time = None
            
            # Find the exact product we care about
            for item in line_items:
                if item.get("productId") == product_id:
                    is_valid = True
                    expiry_str = item.get("expiryTime")
                    if expiry_str:
                        # RFC 3339 format, e.g., "2026-10-06T14:27:20.843Z"
                        # Python 3.11+ can use datetime.fromisoformat directly with Z
                        # For older versions, replace Z with +00:00
                        expiry_str = expiry_str.replace("Z", "+00:00")
                        expiry_time = datetime.fromisoformat(expiry_str)
                    break
            
            from datetime import timezone
            # Si el estado es ACTIVE o GRACE_PERIOD, es activo. 
            # Si es CANCELED, todavía puede tener días restantes si expiry_time > ahora.
            if state in ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"]:
                is_active = True
            elif state == "SUBSCRIPTION_STATE_CANCELED" and expiry_time:
                now_utc = datetime.now(timezone.utc)
                # Convert expiry_time to utc safely for comparison
                expiry_time_utc = expiry_time.astimezone(timezone.utc) if expiry_time.tzinfo else expiry_time.replace(tzinfo=timezone.utc)
                if expiry_time_utc > now_utc:
                    is_active = True
                    
            return {
                "is_valid": is_valid,
                "is_active": is_active,
                "expiry_time": expiry_time,
                "raw_state": state
            }
            
        except Exception as e:
            import logging
            logging.getLogger(__name__).error("[SUBSCRIPTION] event=GOOGLE_API_ERROR metric=google_api_failure message=Google Play API request failed: %s", type(e).__name__)
            from googleapiclient.errors import HttpError
            if isinstance(e, HttpError):
                raise
            return {
                "is_valid": False,
                "is_active": False,
                "expiry_time": None,
                "raw_state": "ERROR"
            }
