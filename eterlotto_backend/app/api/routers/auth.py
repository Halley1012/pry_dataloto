from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query, BackgroundTasks
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
            terms_accepted_at=new_user.terms_accepted_at
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al registrar usuario: {str(e)}")

@router.put("/users/{user_id}")
async def update_user(user_id: int, user_update: schemas.UpdateUser, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
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
            terms_accepted_at=user_update.terms_accepted_at
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al actualizar usuario: {str(e)}")

@router.delete("/users/{user_id}")
async def delete_user(user_id: int, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.delete_user(user_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al eliminar usuario: {str(e)}")

@router.post("/login")
async def login(req: schemas.User, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.login_user(req.email, req.password)
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/refresh")
async def refresh(
    request: Optional[schemas.RefreshTokenRequest] = None,
    refresh_token: Optional[str] = Query(None),
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    token = request.refresh_token if (request and request.refresh_token) else refresh_token
    if not token:
        raise HTTPException(status_code=400, detail="Token de refresco no proporcionado")
    try:
        from jose import jwt, JWTError
        from app.core import config
        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[config.ALGORITHM])
        user_id = payload.get("sub")
        email = payload.get("email")
        if not user_id or not email:
            raise HTTPException(status_code=401, detail="Token de refresco inválido")
        
        # Generar nuevo access token y refresh token
        new_access_token = security.create_access_token(data={"sub": str(user_id), "email": email})
        new_refresh_token = security.create_refresh_token(data={"sub": str(user_id), "email": email})
        return {
            "success": True,
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer"
        }
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Error decodificando token: {str(e)}")

@router.post("/auth/forgot-password")
async def forgot_password(
    request: schemas.ForgotPasswordRequest, 
    background_tasks: BackgroundTasks,
    use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)
):
    try:
        # 1. Generar token y guardarlo en DB (Operación rápida)
        token = await use_cases.request_password_reset(request.email)
        
        # 2. Programar envío de email en segundo plano (Operación lenta)
        background_tasks.add_task(use_cases.send_password_reset_email_task, request.email, token)
        
        return {"success": True, "msg": f"Correo de recuperación enviado a {request.email}"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al procesar solicitud: {str(e)}")

@router.post("/users/fcm_token")
async def update_fcm_token(data: schemas.FCMTokenUpdate, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.update_user_profile(
            user_id=data.user_id,
            fcm_token=data.fcm_token
        )
        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/auth/social-login")
async def social_login(request: schemas.SocialLoginRequest, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = await use_cases.social_login(request.provider, request.token)
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en inicio de sesión social: {str(e)}")
