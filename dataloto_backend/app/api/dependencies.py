from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from app.core import config
from app.infrastructure.postgres_repository import (
    PostgresUserRepository, PostgresJugadaRepository, PostgresPostRepository,
    PostgresPublicidadRepository, PostgresTransactionRepository
)
from app.infrastructure.email_service import SMTPEmailSender
from app.application.auth_use_cases import AuthUseCases
from app.application.jugada_use_cases import JugadaUseCases
from app.application.post_use_cases import PostUseCases
from app.application.publicidad_use_cases import PublicidadUseCases
from app.application.transaction_use_cases import TransactionUseCases

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

async def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    try:
        payload = jwt.decode(token, config.SECRET_KEY, algorithms=[config.ALGORITHM])
        user_id: str = payload.get("sub")
        email: str = payload.get("email")
        if user_id is None or email is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token inválido",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return {"user_id": user_id, "email": email}
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido o expirado: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

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

def get_transaction_use_cases() -> TransactionUseCases:
    trans_repo = PostgresTransactionRepository()
    return TransactionUseCases(trans_repo)
