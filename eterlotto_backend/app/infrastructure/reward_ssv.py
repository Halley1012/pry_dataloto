"""Verify Google AdMob Rewarded SSV signatures before any credit is granted.

Google signs the raw callback query (up to &signature=...&key_id=...). NEVER
rebuild/normalize the signed string or trust an unverified client callback.
"""

from __future__ import annotations

import asyncio
import base64
import logging
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import parse_qsl
from uuid import UUID

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException

KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json"
PUBLIC_KEY_CACHE_SECONDS = 6 * 60 * 60  # Google's maximum is 24h.
_cache: dict[int, ec.EllipticCurvePublicKey] = {}
_cache_expires_at: float = 0.0
_cache_lock = asyncio.Lock()
_logger = logging.getLogger(__name__)


async def _fetch_google_keys(force: bool = False) -> dict[int, ec.EllipticCurvePublicKey]:
    global _cache, _cache_expires_at
    if _cache and time.monotonic() < _cache_expires_at and not force:
        return _cache
    async with _cache_lock:
        if _cache and time.monotonic() < _cache_expires_at and not force:
            return _cache
        try:
            async with httpx.AsyncClient(timeout=6.0, follow_redirects=False) as client:
                response = await client.get(KEYS_URL)
                response.raise_for_status()
                data = response.json()
            keys: dict[int, ec.EllipticCurvePublicKey] = {}
            for entry in data["keys"]:
                key = serialization.load_pem_public_key(entry["pem"].encode("utf-8"))
                if isinstance(key, ec.EllipticCurvePublicKey):
                    keys[int(entry["keyId"])] = key
            if not keys:
                raise ValueError("Empty signing keys")
            _cache = keys
            _cache_expires_at = time.monotonic() + PUBLIC_KEY_CACHE_SECONDS
        except Exception:
            _logger.exception("[REWARDS] Unable to fetch Google SSV verifying keys")
            raise HTTPException(status_code=503, detail="Verificación de Google no disponible")
        return _cache


def _parse_signed_query(raw_query: bytes) -> tuple[bytes, bytes, int, dict[str, str]]:
    # SSV guarantees signature and key_id are the final parameters in that order.
    if len(raw_query) > 8192 or b"&signature=" not in raw_query:
        raise HTTPException(status_code=400, detail="Callback inválido")
    signed_data, separator, tail = raw_query.rpartition(b"&signature=")
    if not separator or b"&key_id=" not in tail or not signed_data:
        raise HTTPException(status_code=400, detail="Callback inválido")
    signature_text, sep, key_id_text = tail.partition(b"&key_id=")
    if not sep or not signature_text or not key_id_text.isdigit():
        raise HTTPException(status_code=400, detail="Callback inválido")
    if b"&" in key_id_text or b"&" in signature_text:
        raise HTTPException(status_code=400, detail="Callback inválido")
    try:
        # Google uses URL-safe Base64 without padding for an ECDSA DER signature.
        signature = base64.urlsafe_b64decode(
            signature_text + b"=" * (-len(signature_text) % 4)
        )
        values = parse_qsl(signed_data.decode("utf-8"), keep_blank_values=True,
                           strict_parsing=True)
    except (UnicodeDecodeError, ValueError, base64.binascii.Error):
        raise HTTPException(status_code=400, detail="Callback inválido")
    params = dict(values)
    if len(params) != len(values):
        raise HTTPException(status_code=400, detail="Parámetros duplicados")
    return signed_data, signature, int(key_id_text), params


async def verify_admob_callback(raw_query: bytes, allowed_units: set[str]) -> dict:
    signed_data, signature, key_id, params = _parse_signed_query(raw_query)
    keys = await _fetch_google_keys()
    if key_id not in keys:
        keys = await _fetch_google_keys(force=True)
    key = keys.get(key_id)
    if key is None:
        raise HTTPException(status_code=403, detail="Clave SSV desconocida")
    try:
        key.verify(signature, signed_data, ec.ECDSA(hashes.SHA256()))
    except (InvalidSignature, ValueError):
        raise HTTPException(status_code=403, detail="Firma SSV inválida")

    # Only interpret parameters *after* cryptographically verifying the raw bytes.
    unit = params.get("ad_unit", "").split("/")[-1]
    if not unit or unit not in allowed_units:
        _logger.warning("[REWARDS] SSV unexpected ad unit")
        raise HTTPException(status_code=403, detail="Unidad publicitaria no autorizada")
    try:
        session_id = UUID(params["custom_data"])
        user_id = int(params["user_id"])
        transaction_id = params["transaction_id"]
        timestamp_ms = int(params["timestamp"])
        rewarded_at = datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc)
    except (KeyError, ValueError, OverflowError):
        raise HTTPException(status_code=400, detail="Datos SSV inválidos")
    if (user_id <= 0 or not transaction_id or len(transaction_id) > 256
            or len(transaction_id) < 8):
        raise HTTPException(status_code=400, detail="Datos SSV inválidos")
    if rewarded_at > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise HTTPException(status_code=403, detail="Fecha SSV inválida")
    return {
        "session_id": session_id, "user_id": user_id,
        "transaction_id": transaction_id, "ad_unit": unit,
        "rewarded_at": rewarded_at,
    }
