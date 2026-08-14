import secrets
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from app.domain.ports import UserRepositoryPort, EmailSenderPort
from app.core import security, config

class AuthUseCases:
    def __init__(self, user_repo: UserRepositoryPort, email_sender: Optional[EmailSenderPort] = None):
        self.user_repo = user_repo
        self.email_sender = email_sender

    async def register_user(self, name: str, email: str, password: str, pais_id: int, departamento_id: int) -> Dict[str, Any]:
        existing = await self.user_repo.find_by_email(email)
        if existing:
            raise ValueError("El correo ya está registrado")

        hashed_pwd = security.hash_password(password)
        user_record = await self.user_repo.create(name, email, hashed_pwd, pais_id, departamento_id)
        return {
            "success": True,
            "message": "Usuario registrado correctamente",
            "user": user_record
        }

    async def login_user(self, email: str, password: str) -> Dict[str, Any]:
        user = await self.user_repo.find_by_email(email)
        if not user or not security.verify_password(password, user["password_hashed"]):
            raise ValueError("Credenciales inválidas")

        # 🔒 Auto-migrar la contraseña a Bcrypt si estaba guardada en texto plano
        if user["password_hashed"] == password:
            new_hash = security.hash_password(password)
            await self.user_repo.update(user["id"], {"password_hashed": new_hash})

        # Crear tokens
        access_token = security.create_access_token(data={"sub": str(user["id"]), "email": user["email"]})
        refresh_token = security.create_refresh_token(data={"sub": str(user["id"]), "email": user["email"]})

        return {
            "success": True,
            "message": "Inicio de sesión exitoso 🚀",
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user": {
                "id": user["id"],
                "name": user["name"],
                "email": user["email"],
                "pais_id": user["pais_id"],
                "pais_nombre": user["pais_nombre"],
                "departamento_id": user["departamento_id"],
                "departamento_nombre": user["departamento_nombre"],
            }
        }

    async def update_user_profile(self, user_id: int, name: Optional[str] = None, email: Optional[str] = None, pais_id: Optional[int] = None, departamento_id: Optional[int] = None, fcm_token: Optional[str] = None) -> Dict[str, Any]:
        user = await self.user_repo.find_by_id(user_id)
        if not user:
            raise ValueError("Usuario no encontrado")

        updates = {}
        if name is not None:
            updates["name"] = name.strip().title()

        if email is not None:
            normalized_email = email.strip().lower()
            existing = await self.user_repo.find_by_email(normalized_email)
            if existing and existing["id"] != user_id:
                raise ValueError("El correo ya está registrado por otro usuario")
            updates["email"] = normalized_email

        if pais_id is not None:
            updates["pais_id"] = pais_id

        if departamento_id is not None:
            updates["departamento_id"] = departamento_id
            
        if fcm_token is not None:
            updates["fcm_token"] = fcm_token

        if not updates:
            raise ValueError("No se enviaron campos para actualizar")

        updated_user = await self.user_repo.update(user_id, updates)
        return {
            "success": True,
            "message": "Perfil actualizado correctamente",
            "user": updated_user
        }

    async def delete_user(self, user_id: int) -> Dict[str, Any]:
        deleted_info = await self.user_repo.delete(user_id)
        return {
            "success": True,
            "message": f"🗑️ Usuario '{deleted_info['name']}' eliminado correctamente",
            "deleted_user": deleted_info
        }

    async def request_password_reset(self, email: str) -> str:
        user = await self.user_repo.find_by_email(email)
        if not user:
            raise ValueError("Usuario no encontrado")

        token = secrets.token_urlsafe(32)
        expires = datetime.utcnow() + timedelta(hours=1)

        await self.user_repo.save_password_reset_token(user["id"], token, expires)
        return token

    async def send_password_reset_email_task(self, email: str, token: str) -> None:
        if not self.email_sender:
            return
            
        reset_link = f"{config.FRONTEND_URL}/reset-password?token={token}"
        try:
            await self.email_sender.send_reset_password_email(email, reset_link)
        except Exception as e:
            # En tareas de fondo es vital capturar errores para no tumbar el worker
            print(f"❌ Error en Background Task (email): {e}")
