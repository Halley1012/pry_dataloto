import asyncio
import base64
import hashlib
import json
import logging
from typing import Any, Dict, Optional

import requests
from google.auth.transport.requests import Request
from google.oauth2.service_account import Credentials

from app.core import config
from app.domain.ports import PushNotificationPort


logger = logging.getLogger(__name__)


class FirebasePushService(PushNotificationPort):
    _scope = "https://www.googleapis.com/auth/firebase.messaging"

    def __init__(self) -> None:
        self._credentials: Optional[Credentials] = None
        self._project_id: Optional[str] = None
        self._disabled_reason: Optional[str] = None
        self._load_credentials()

    @property
    def enabled(self) -> bool:
        return self._credentials is not None and bool(self._project_id)

    def _load_credentials(self) -> None:
        encoded = config.FIREBASE_CREDENTIALS_B64
        if not encoded:
            self._disabled_reason = "FIREBASE_CREDENTIALS_B64_not_configured"
            logger.warning(
                "[NOTIFICATIONS] event=PUSH_DISABLED reason=%s",
                self._disabled_reason,
            )
            return

        try:
            raw = base64.b64decode(encoded).decode("utf-8")
            info = json.loads(raw)
            self._project_id = config.FIREBASE_PROJECT_ID or info.get("project_id")
            if not self._project_id:
                raise ValueError("Firebase project_id ausente")
            self._credentials = Credentials.from_service_account_info(
                info,
                scopes=[self._scope],
            )
        except Exception as exc:
            self._disabled_reason = "invalid_firebase_credentials"
            logger.error(
                "[NOTIFICATIONS] event=PUSH_CONFIG_ERROR error=%s",
                type(exc).__name__,
            )
            self._credentials = None
            self._project_id = None

    @staticmethod
    def _token_hash(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()[:12]

    @staticmethod
    def _stringify_data(data: Optional[Dict[str, Any]]) -> Dict[str, str]:
        result: Dict[str, str] = {}
        for key, value in (data or {}).items():
            if value is None:
                continue
            if isinstance(value, bool):
                result[str(key)] = "true" if value else "false"
            else:
                result[str(key)] = str(value)
        return result

    def _send_sync(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        if not self.enabled or self._credentials is None or not self._project_id:
            return {
                "success": False,
                "disabled": True,
                "reason": self._disabled_reason or "firebase_not_configured",
            }

        if not self._credentials.valid:
            self._credentials.refresh(Request())

        endpoint = (
            f"https://fcm.googleapis.com/v1/projects/{self._project_id}/messages:send"
        )
        payload = {
            "message": {
                "token": token,
                "notification": {
                    "title": title,
                    "body": body,
                },
                "data": self._stringify_data(data),
                "android": {
                    "priority": "high",
                    "notification": {
                        "channel_id": "high_importance_channel",
                        "sound": "default",
                    },
                },
            }
        }

        response = requests.post(
            endpoint,
            headers={
                "Authorization": f"Bearer {self._credentials.token}",
                "Content-Type": "application/json; UTF-8",
            },
            json=payload,
            timeout=12,
        )

        token_hash = self._token_hash(token)
        if 200 <= response.status_code < 300:
            response_json = response.json() if response.content else {}
            logger.info(
                "[NOTIFICATIONS] event=PUSH_SEND_SUCCESS token_hash=%s message_id=%s",
                token_hash,
                response_json.get("name"),
            )
            return {
                "success": True,
                "message_id": response_json.get("name"),
                "token_hash": token_hash,
            }

        try:
            error_payload = response.json()
        except Exception:
            error_payload = {}

        error = error_payload.get("error") if isinstance(error_payload, dict) else {}
        details = error.get("details", []) if isinstance(error, dict) else []
        fcm_error_code = None
        for detail in details:
            if isinstance(detail, dict) and detail.get("errorCode"):
                fcm_error_code = detail.get("errorCode")
                break

        api_status = error.get("status") if isinstance(error, dict) else None
        invalid_token = (
            fcm_error_code in {"UNREGISTERED", "INVALID_ARGUMENT"}
            or api_status == "NOT_FOUND"
        )

        logger.warning(
            "[NOTIFICATIONS] event=%s token_hash=%s status_code=%s api_status=%s fcm_error=%s",
            "PUSH_TOKEN_INVALID" if invalid_token else "PUSH_SEND_ERROR",
            token_hash,
            response.status_code,
            api_status,
            fcm_error_code,
        )

        return {
            "success": False,
            "invalid_token": invalid_token,
            "status_code": response.status_code,
            "api_status": api_status,
            "fcm_error_code": fcm_error_code,
            "token_hash": token_hash,
        }

    async def send(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        return await asyncio.to_thread(
            self._send_sync,
            token,
            title,
            body,
            data,
        )
