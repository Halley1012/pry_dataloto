import logging
import os
import uuid
from urllib.parse import quote, unquote

import httpx
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, UploadFile, File
from app.api import schemas, dependencies
from app.application.auth_use_cases import AuthUseCases
from app.core import security

router = APIRouter()

_ALLOWED_AVATAR_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "image/heif": ".heif",
}
_MAX_AVATAR_BYTES = 2 * 1024 * 1024


def _profile_storage_settings():
    supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    secret_key = (
        os.getenv("SUPABASE_SECRET_KEY")
        or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or ""
    ).strip()
    bucket = (os.getenv("SUPABASE_PROFILE_BUCKET") or "usuarios").strip()
    return supabase_url, secret_key, bucket


def _profile_storage_object_path(public_url: str):
    if not public_url:
        return None

    supabase_url, _, bucket = _profile_storage_settings()
    if not supabase_url or not bucket:
        return None

    prefix = f"{supabase_url}/storage/v1/object/public/{bucket}/"
    if not public_url.startswith(prefix):
        return None

    value = unquote(public_url[len(prefix):]).lstrip("/")
    return value or None


async def _delete_profile_avatar(public_url: str):
    object_path = _profile_storage_object_path(public_url)
    if not object_path:
        return

    supabase_url, secret_key, bucket = _profile_storage_settings()
    if not supabase_url or not secret_key:
        return

    headers = {
        "apikey": secret_key,
        "Authorization": f"Bearer {secret_key}",
    }
    endpoint = (
        f"{supabase_url}/storage/v1/object/{bucket}/"
        f"{quote(object_path, safe='/')}"
    )

    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.delete(endpoint, headers=headers)
        if response.status_code not in (200, 204):
            logging.warning(
                "[PROFILE_STORAGE] No se pudo eliminar avatar: %s %s",
                response.status_code,
                response.text[:300],
            )
    except httpx.HTTPError as exc:
        logging.warning(
            "[PROFILE_STORAGE] Error eliminando avatar: %s",
            exc,
        )


async def _cleanup_profile_avatar_folder(
    user_id: int,
    keep_public_url: str | None = None,
):
    """
    Elimina avatares huérfanos del propio usuario en Storage.

    Esto corrige archivos históricos que pudieron quedar cuando un login de
    Google sobrescribió avatar_url antes de que el backend pudiera borrar la
    foto personalizada anterior.
    """
    supabase_url, secret_key, bucket = _profile_storage_settings()
    if not supabase_url or not secret_key or not bucket:
        return

    prefix = f"user_{user_id}/perfil"
    keep_path = _profile_storage_object_path((keep_public_url or "").strip())

    headers = {
        "apikey": secret_key,
        "Authorization": f"Bearer {secret_key}",
        "Content-Type": "application/json",
    }
    list_endpoint = f"{supabase_url}/storage/v1/object/list/{bucket}"

    try:
        async with httpx.AsyncClient(timeout=25.0) as client:
            response = await client.post(
                list_endpoint,
                headers=headers,
                json={
                    "prefix": prefix,
                    "limit": 100,
                    "offset": 0,
                    "sortBy": {"column": "name", "order": "asc"},
                },
            )

            if response.status_code != 200:
                logging.warning(
                    "[PROFILE_STORAGE] No se pudo listar avatares: %s %s",
                    response.status_code,
                    response.text[:300],
                )
                return

            objects = response.json()
            if not isinstance(objects, list):
                return

            for item in objects:
                if not isinstance(item, dict):
                    continue

                name = (item.get("name") or "").strip()
                if not name or not name.startswith("avatar_"):
                    continue

                object_path = f"{prefix}/{name}"
                if keep_path and object_path == keep_path:
                    continue

                delete_endpoint = (
                    f"{supabase_url}/storage/v1/object/{bucket}/"
                    f"{quote(object_path, safe='/')}"
                )
                delete_response = await client.delete(
                    delete_endpoint,
                    headers={
                        "apikey": secret_key,
                        "Authorization": f"Bearer {secret_key}",
                    },
                )

                if delete_response.status_code not in (200, 204):
                    logging.warning(
                        "[PROFILE_STORAGE] No se pudo limpiar avatar huérfano %s: %s",
                        object_path,
                        delete_response.status_code,
                    )
    except httpx.HTTPError as exc:
        logging.warning(
            "[PROFILE_STORAGE] Error limpiando avatares huérfanos: %s",
            exc,
        )


async def _upload_profile_avatar(user_id: int, file: UploadFile):
    supabase_url, secret_key, bucket = _profile_storage_settings()
    if not supabase_url or not secret_key or not bucket:
        raise HTTPException(
            status_code=500,
            detail="Storage de perfiles no configurado",
        )

    content_type = (file.content_type or "").lower().strip()
    extension = _ALLOWED_AVATAR_TYPES.get(content_type)

    if extension is None:
        filename = (file.filename or "").lower().strip()
        suffix_map = {
            ".jpg": ("image/jpeg", ".jpg"),
            ".jpeg": ("image/jpeg", ".jpg"),
            ".png": ("image/png", ".png"),
            ".webp": ("image/webp", ".webp"),
            ".heic": ("image/heic", ".heic"),
            ".heif": ("image/heif", ".heif"),
        }
        for suffix, resolved in suffix_map.items():
            if filename.endswith(suffix):
                content_type, extension = resolved
                break

    if extension is None:
        raise HTTPException(
            status_code=400,
            detail="Formato no permitido. Usa JPG, PNG, WEBP, HEIC o HEIF.",
        )

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="La imagen está vacía")
    if len(raw) > _MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=400,
            detail="La foto supera el límite de 2 MB",
        )

    object_path = (
        f"user_{user_id}/perfil/"
        f"avatar_{uuid.uuid4().hex}{extension}"
    )
    endpoint = (
        f"{supabase_url}/storage/v1/object/{bucket}/"
        f"{quote(object_path, safe='/')}"
    )
    headers = {
        "apikey": secret_key,
        "Authorization": f"Bearer {secret_key}",
        "Content-Type": content_type,
        "x-upsert": "false",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            endpoint,
            content=raw,
            headers=headers,
        )

    if response.status_code not in (200, 201):
        raise HTTPException(
            status_code=502,
            detail=f"Storage rechazó la imagen: {response.text[:300]}",
        )

    public_url = (
        f"{supabase_url}/storage/v1/object/public/{bucket}/"
        f"{quote(object_path, safe='/')}"
    )
    return public_url



@router.post("/register")
async def register_user(new_user: schemas.RegisterUser, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.register_user(
            name=new_user.name,
            email=new_user.email,
            password=new_user.password,
            pais_id=new_user.pais_id,
            departamento_id=new_user.departamento_id,
            terms_accepted_at=new_user.terms_accepted_at,
            is_adult=new_user.is_adult
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Error interno: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/users/avatar/upload")
async def upload_user_avatar(
    file: UploadFile = File(...),
    current_user: dict = Depends(dependencies.get_current_user),
):
    user_id = int(current_user["user_id"])
    return {
        "success": True,
        "url": await _upload_profile_avatar(user_id, file),
    }


@router.get("/users/{user_id}")
async def get_user(
    user_id: int, 
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases),
    current_user: dict = Depends(dependencies.get_current_user)
):
    if str(user_id) != str(current_user["user_id"]):
        raise HTTPException(status_code=403, detail="No autorizado para ver este perfil")
    try:
        res = await use_cases.get_user_profile(user_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.put("/users/{user_id}")
async def update_user(
    user_id: int, 
    user_update: schemas.UpdateUser, 
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases),
    current_user: dict = Depends(dependencies.get_current_user)
):
    if str(user_id) != str(current_user["user_id"]):
        raise HTTPException(status_code=403, detail="No autorizado para editar este perfil")
    try:
        previous_profile = await use_cases.get_user_profile(user_id)
        previous_avatar = previous_profile.get("avatar_url")

        res = await use_cases.update_user_profile(
            user_id=user_id,
            name=user_update.name,
            email=user_update.email,
            pais_id=user_update.pais_id,
            departamento_id=user_update.departamento_id,
            fcm_token=user_update.fcm_token,
            telefono=user_update.telefono,
            idioma=user_update.idioma,
            notificaciones_activas=user_update.notificaciones_activas,
            app_version=user_update.app_version,
            plataforma=user_update.plataforma,
            avatar_url=user_update.avatar_url,
            terms_accepted_at=user_update.terms_accepted_at,
            is_adult=user_update.is_adult
        )

        if user_update.avatar_url is not None:
            new_avatar = user_update.avatar_url.strip()
            old_avatar = (previous_avatar or "").strip()

            if old_avatar and old_avatar != new_avatar:
                await _delete_profile_avatar(old_avatar)

            # Limpia también cualquier foto huérfana histórica que haya quedado
            # dentro de la carpeta de este mismo usuario. Si new_avatar es una
            # URL externa (por ejemplo Google) o queda vacío, no conserva
            # archivos viejos del bucket.
            await _cleanup_profile_avatar_folder(
                user_id=user_id,
                keep_public_url=new_avatar,
            )

        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.delete("/users/fcm_token")
async def delete_fcm_token(
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases),
):
    try:
        return await use_cases.clear_fcm_token(int(current_user["user_id"]))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(
            "[NOTIFICATIONS] event=FCM_TOKEN_CLEAR_ERROR error=%s",
            type(e).__name__,
        )
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int, 
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases),
    current_user: dict = Depends(dependencies.get_current_user)
):
    if str(user_id) != str(current_user["user_id"]):
        raise HTTPException(status_code=403, detail="No autorizado para eliminar este perfil")
    try:
        res = await use_cases.delete_user(user_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/login")
async def login(req: schemas.User, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.login_user(req.email, req.password)
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/refresh")
async def refresh(
    request: schemas.RefreshTokenRequest,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    # El refresh token se acepta únicamente en el cuerpo JSON. Nunca en la URL:
    # las URLs pueden terminar en access logs, proxies, historial o trazas.
    token = request.refresh_token.strip()
    if not token:
        raise HTTPException(status_code=400, detail="Token de refresco no proporcionado")

    try:
        from jose import jwt, JWTError
        from app.core import config

        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[config.ALGORITHM])
        user_id = payload.get("sub")
        email = payload.get("email")
        token_type = payload.get("token_type")

        if not user_id or not email or token_type != "refresh":
            raise HTTPException(status_code=401, detail="Token de refresco inválido")

        # Rotación: cada refresh devuelve un par nuevo.
        new_access_token = security.create_access_token(
            data={"sub": str(user_id), "email": email}
        )
        new_refresh_token = security.create_refresh_token(
            data={"sub": str(user_id), "email": email}
        )
        return {
            "success": True,
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
        }
    except JWTError:
        # No exponer detalles criptográficos del decoder al cliente.
        raise HTTPException(status_code=401, detail="Token de refresco inválido o expirado")

@router.post("/auth/forgot-password")
async def forgot_password(
    request: schemas.ForgotPasswordRequest, 
    background_tasks: BackgroundTasks,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    try:
        # 1. Generar token OTP y guardarlo en DB
        code = await use_cases.request_password_reset(request.email)
        
        # 2. Programar envío de email en segundo plano
        background_tasks.add_task(use_cases.send_password_reset_email_task, request.email, code)
        
        return {"success": True, "msg": f"Código de recuperación enviado a {request.email}"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/auth/verify-reset-code")
async def verify_reset_code(
    request: schemas.VerifyResetCodeRequest,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    try:
        res = await use_cases.verify_reset_code(
            email=request.email,
            code=request.code
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/auth/verify-email")
async def verify_email(
    request: schemas.VerifyEmailCodeRequest,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    try:
        res = await use_cases.verify_email(
            email=request.email,
            code=request.code
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/auth/resend-verification-code")
async def resend_verification_code(
    request: schemas.ForgotPasswordRequest,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    try:
        res = await use_cases.resend_verification_code(email=request.email)
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/auth/reset-password")
async def reset_password(
    request: schemas.ResetPasswordWithCodeRequest,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    try:
        res = await use_cases.reset_password_with_code(
            email=request.email,
            code=request.code,
            new_password=request.new_password
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@router.post("/users/fcm_token")
async def update_fcm_token(
    data: schemas.FCMTokenUpdate,
    current_user: dict = Depends(dependencies.get_current_user),
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases),
):
    current_user_id = int(current_user["user_id"])
    if data.user_id is not None and int(data.user_id) != current_user_id:
        raise HTTPException(status_code=403, detail="No autorizado para registrar este dispositivo")

    try:
        return await use_cases.update_fcm_token(
            user_id=current_user_id,
            fcm_token=data.fcm_token,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(
            "[NOTIFICATIONS] event=FCM_TOKEN_SAVE_ERROR error=%s",
            type(e).__name__,
        )
        raise HTTPException(status_code=500, detail="Error interno del servidor")


@router.post("/auth/social-login")
async def social_login(request: schemas.SocialLoginRequest, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.social_login(request.provider, request.token)
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")


