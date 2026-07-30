from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
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
            departamento_id=new_user.departamento_id
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
            departamento_id=user_update.departamento_id
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
def forgot_password(request: schemas.ForgotPasswordRequest, use_cases: AuthUseCases = Depends(dependencies.get_auth_use_cases)):
    try:
        res = use_cases.request_password_reset(request.email)
        return res
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error enviando correo: {str(e)}")
