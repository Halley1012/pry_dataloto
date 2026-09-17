from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from app.api import schemas, dependencies
from app.application.auth_use_cases import AuthUseCases
from app.core import security

router = APIRouter()

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
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import logging
        logging.error(f"Internal error: {e}")
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


