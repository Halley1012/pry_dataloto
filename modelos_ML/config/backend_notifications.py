"""Cliente interno para publicar notificaciones desde modelos/Airflow.

Los procesos ML NO envían FCM directamente. Publican el evento al backend
Eterlotto, que guarda el buzón y se encarga de la entrega push.
"""

from __future__ import annotations

import os
from datetime import date, datetime
from typing import Any

import requests

# Importar settings carga .env.dev/.env.prd según APP_ENV.
from config.settings import settings  # noqa: F401


class BackendNotificationClient:
    def __init__(self) -> None:
        self.base_url = (
            os.getenv("ETERLOTTO_API_BASE_URL", "").strip().rstrip("/")
        )
        self.internal_key = os.getenv(
            "NOTIFICATION_INTERNAL_KEY", ""
        ).strip()
        raw_timeout = os.getenv("NOTIFICATION_HTTP_TIMEOUT", "15").strip()
        try:
            self.timeout = max(3, int(raw_timeout))
        except ValueError:
            self.timeout = 15

    @property
    def configured(self) -> bool:
        return bool(self.base_url and self.internal_key)

    def publish(
        self,
        *,
        loteria_id: int,
        fecha_sorteo: date | datetime | str | None,
        mensaje: str,
        tipo: str,
        user_id: int | None = None,
    ) -> dict[str, Any]:
        if not self.configured:
            missing = []
            if not self.base_url:
                missing.append("ETERLOTTO_API_BASE_URL")
            if not self.internal_key:
                missing.append("NOTIFICATION_INTERNAL_KEY")
            raise RuntimeError(
                "Notificaciones backend no configuradas. Faltan: "
                + ", ".join(missing)
            )

        if isinstance(fecha_sorteo, (date, datetime)):
            fecha_value = fecha_sorteo.isoformat()
        elif fecha_sorteo is None:
            fecha_value = None
        else:
            fecha_value = str(fecha_sorteo)

        payload = {
            "loteria_id": int(loteria_id),
            "fecha_sorteo": fecha_value,
            "mensaje": mensaje,
            "tipo": tipo,
            "user_id": user_id,
        }

        response = requests.post(
            f"{self.base_url}/notifications/publish",
            headers={
                "X-Notification-Key": self.internal_key,
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=self.timeout,
        )

        if response.status_code != 200:
            detail = response.text[:300].replace("\n", " ")
            raise RuntimeError(
                "Backend rechazó la notificación "
                f"(HTTP {response.status_code}): {detail}"
            )

        try:
            data = response.json()
        except ValueError as exc:
            raise RuntimeError(
                "Backend devolvió una respuesta no JSON al publicar notificación"
            ) from exc

        return data
