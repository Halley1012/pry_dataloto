"""Rewards API. New, isolated module: no changes to existing adverts/routes.

Flutter creates a session, sets SSV userId & customData on RewardedAd, and
then polls /rewards/status. The ONLY way to credit a video is signed Google SSV.
"""

from __future__ import annotations

import logging
import os
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.api.dependencies import get_current_user
from app.infrastructure.reward_repository import (
    RewardRejected, activate_pass, credit_verified_video,
    get_reward_status, start_video_session,
)
from app.infrastructure.reward_ssv import verify_admob_callback

router = APIRouter(prefix="/rewards", tags=["Rewards"])
_logger = logging.getLogger(__name__)


class RewardVideoSessionRequest(BaseModel):
    origen: Literal["regalo", "funcion"]
    funcion_clave: str | None = Field(default=None, max_length=128)


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
    try:
        return await start_video_session(int(current_user["user_id"]), payload.origen, feature)
    except RewardRejected as exc:
        raise HTTPException(status_code=409, detail=str(exc))


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
    raw = os.getenv("REWARDS_SSV_AD_UNIT_IDS", "")
    units = {u.strip().split("/")[-1] for u in raw.split(",") if u.strip()}
    if not units:
        raise HTTPException(status_code=503, detail="SSV no configurado")
    verified = await verify_admob_callback(request.scope["query_string"], units)
    try:
        result = await credit_verified_video(**verified)
    except RewardRejected as exc:
        _logger.warning("[REWARDS] Rejected verified SSV event: %s", str(exc))
        raise HTTPException(status_code=409, detail=str(exc))
    # AdMob expects HTTP 200 to mark delivery successful; duplicates return 200.
    return {"ok": True, **result}
