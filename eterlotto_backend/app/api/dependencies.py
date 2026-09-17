from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from app.core import config
from app.application.subscription_use_cases import SubscriptionUseCases
from app.infrastructure.postgres_repository import (
    PostgresUserRepository, PostgresJugadaRepository, PostgresPostRepository,
    PostgresPublicidadRepository, PostgresNotificationRepository
)
from app.infrastructure.email_service import SMTPEmailSender
from app.application.auth_use_cases import AuthUseCases
from app.application.jugada_use_cases import JugadaUseCases
from app.application.post_use_cases import PostUseCases
from app.application.publicidad_use_cases import PublicidadUseCases
from app.application.notification_use_cases import NotificationUseCases
from app.infrastructure.firebase_push_service import FirebasePushService

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/login", auto_error=False)

async def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    try:
        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[config.ALGORITHM])
        user_id: str = payload.get("sub")
        email: str = payload.get("email")
        token_type: str = payload.get("token_type")
        if user_id is None or email is None or token_type != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token inválido",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return {"user_id": user_id, "email": email}
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_optional_current_user(token: Optional[str] = Depends(oauth2_scheme_optional)) -> Optional[dict]:
    if not token:
        return None
    try:
        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[config.ALGORITHM])
        user_id: str = payload.get("sub")
        email: str = payload.get("email")
        token_type: str = payload.get("token_type")
        if user_id is None or email is None or token_type != "access":
            return None
        return {"user_id": user_id, "email": email}
    except JWTError:
        return None

# Inyección de dependencias para Casos de Uso
def get_auth_use_cases() -> AuthUseCases:
    user_repo = PostgresUserRepository()
    email_sender = SMTPEmailSender()
    return AuthUseCases(user_repo, email_sender)

def get_jugada_use_cases() -> JugadaUseCases:
    jugada_repo = PostgresJugadaRepository()
    return JugadaUseCases(jugada_repo)

def get_post_use_cases() -> PostUseCases:
    post_repo = PostgresPostRepository()
    return PostUseCases(post_repo)

def get_publicidad_use_cases() -> PublicidadUseCases:
    publicidad_repo = PostgresPublicidadRepository()
    return PublicidadUseCases(publicidad_repo)


def get_notification_use_cases() -> NotificationUseCases:
    return NotificationUseCases(
        notification_repo=PostgresNotificationRepository(),
        user_repo=PostgresUserRepository(),
        push_service=FirebasePushService(),
    )


from app.infrastructure.google_play_service import GooglePlayService

def get_subscription_use_cases() -> SubscriptionUseCases:
    return SubscriptionUseCases(
        user_repo=PostgresUserRepository(),
        google_play=GooglePlayService()
    )

