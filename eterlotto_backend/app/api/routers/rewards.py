"""Rewards API. New, isolated module: no changes to existing adverts/routes.

Flutter creates a session, sets SSV userId & customData on RewardedAd, and
then polls /rewards/status. The ONLY way to credit a video is signed Google SSV.
"""

from __future__ import annotations

import logging
import os
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.api.dependencies import get_current_user
from app.infrastructure.reward_repository import (
    RewardRejected, activate_pass, credit_verified_video,
    get_reward_status, get_video_session_status, start_video_session,
)
from app.infrastructure.reward_ssv import ADMOB_URL_VERIFICATION_UNIT, verify_admob_callback

router = APIRouter(prefix="/rewards", tags=["Rewards"])
_logger = logging.getLogger(__name__)


class RewardVideoSessionRequest(BaseModel):
    origen: Literal["regalo", "funcion"]
    funcion_clave: str | None = Field(default=None, max_length=128)
    ad_unit_id: str | None = Field(default=None, max_length=128)


def _allowed_ssv_units() -> set[str]:
    return {unit.strip().split("/")[-1]
            for unit in os.getenv("REWARDS_SSV_AD_UNIT_IDS", "").split(",")
            if unit.strip() and unit.strip().split("/")[-1] != ADMOB_URL_VERIFICATION_UNIT}


@router.get("/status")
async def status(current_user: dict = Depends(get_current_user)):
    return await get_reward_status(int(current_user["user_id"]))


@router.post("/video-session", status_code=201)
async def video_session(
    payload: RewardVideoSessionRequest,
    current_user: dict = Depends(get_current_user),
):
    feature = payload.funcion_clave.strip() if payload.funcion_clave else None
    if (payload.origen == "funcion" and not feature) or (
        payload.origen == "regalo" and feature is not None
    ):
        raise HTTPException(status_code=422, detail="Origen o función inválida")
    # New clients check the actual unit BEFORE asking the user to watch.
    # Google's shared demo units cannot be configured with our callback URL.
    if payload.ad_unit_id and payload.ad_unit_id.startswith("ca-app-pub-3940256099942544/"):
        raise HTTPException(status_code=409, detail="SSV_DEMO_AD_UNIT")
    units = _allowed_ssv_units()
    if not units or (payload.ad_unit_id is not None
                     and payload.ad_unit_id.split("/")[-1] not in units):
        raise HTTPException(status_code=503, detail="SSV_AD_UNIT_NOT_CONFIGURED")
    try:
        return await start_video_session(int(current_user["user_id"]), payload.origen, feature)
    except RewardRejected as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.get("/video-session/{session_id}")
async def video_session_status(
    session_id: UUID,
    current_user: dict = Depends(get_current_user),
):
    result = await get_video_session_status(int(current_user["user_id"]), session_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Sesión no encontrada")
    return result


@router.post("/pass/activate")
async def pass_activate(current_user: dict = Depends(get_current_user)):
    try:
        return await activate_pass(int(current_user["user_id"]))
    except RewardRejected as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.get("/admob/ssv")
async def admob_ssv(request: Request):
    # Set REWARDS_SSV_AD_UNIT_IDS explicitly per environment: e.g. numeric
    # suffix of the PRD rewarded unit. Unconfigured backend fails CLOSED.
    units = _allowed_ssv_units()
    if not units:
        raise HTTPException(status_code=503, detail="SSV no configurado")
    # AdMob's "Verify URL" probe uses a synthetic unit, not our real DEV unit.
    # Opt in only on an explicitly configured DEV service; never issue credit.
    accept_verify_test = (
        os.getenv("APP_ENV", "").strip().lower() == "dev"
        and os.getenv("REWARDS_SSV_ACCEPT_VERIFY_TEST", "false").strip().lower()
        in {"true", "1", "yes"}
    )
    allowed_units = units | ({ADMOB_URL_VERIFICATION_UNIT} if accept_verify_test else set())
    verified = await verify_admob_callback(
        request.scope["query_string"], allowed_units,
        allow_verification_test=accept_verify_test,
    )
    if verified["ad_unit"] == ADMOB_URL_VERIFICATION_UNIT:
        _logger.info("[REWARDS] Signed AdMob URL verification accepted; no credit issued")
        return {"ok": True, "verification_test": True}
    try:
        result = await credit_verified_video(**verified)
    except RewardRejected as exc:
        _logger.warning("[REWARDS] Rejected verified SSV event: %s", str(exc))
        raise HTTPException(status_code=409, detail=str(exc))
    # AdMob expects HTTP 200 to mark delivery successful; duplicates return 200.
    return {"ok": True, **result}
