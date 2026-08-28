import secrets
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from app.domain.ports import UserRepositoryPort, EmailSenderPort
from app.core import security, config

class AuthUseCases:
    def __init__(self, user_repo: UserRepositoryPort, email_sender: Optional[EmailSenderPort] = None):
        self.user_repo = user_repo
        self.email_sender = email_sender

    async def register_user(
        self,
        name: str,
        email: str,
        password: str,
        pais_id: int,
        departamento_id: int,
        terms_accepted_at: Optional[datetime] = None,
        is_adult: bool = True
    ) -> Dict[str, Any]:
        existing = await self.user_repo.find_by_email(email)
        if existing:
            raise ValueError("El correo ya está registrado")

        hashed_pwd = security.hash_password(password)
        terms_dt = terms_accepted_at or datetime.utcnow()
        user_record = await self.user_repo.create(
            name=name,
            email=email,
            password_hashed=hashed_pwd,
            pais_id=pais_id,
            departamento_id=departamento_id,
            terms_accepted_at=terms_dt,
            is_adult=is_adult
        )
        return {
            "success": True,
            "message": "Usuario registrado correctamente",
            "user": user_record
        }

    async def login_user(self, email: str, password: str) -> Dict[str, Any]:
        user = await self.user_repo.find_by_email(email)
        if not user or not security.verify_password(password, user["password_hashed"]):
            raise ValueError("Credenciales inválidas")

        # 🔒 Validar si el usuario está activo
        if user.get("activo") is False:
            raise ValueError("Tu cuenta ha sido desactivada o suspendida. Por favor contacta a soporte.")

        # 🔒 Auto-migrar la contraseña a Bcrypt si estaba guardada en texto plano
        if user["password_hashed"] == password:
            new_hash = security.hash_password(password)
            await self.user_repo.update(user["id"], {"password_hashed": new_hash})

        # 🕒 Actualizar último inicio de sesión
        await self.user_repo.update_last_login(user["id"])

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
                "is_premium": user.get("is_premium", False),
                "premium_expires_at": user.get("premium_expires_at").isoformat() if user.get("premium_expires_at") else None,
                "activo": user.get("activo", True),
                "auth_provider": user.get("auth_provider", "email"),
                "avatar_url": user.get("avatar_url"),
                "telefono": user.get("telefono"),
                "idioma": user.get("idioma", "es"),
                "notificaciones_activas": user.get("notificaciones_activas", True),
                "terms_accepted_at": user.get("terms_accepted_at").isoformat() if user.get("terms_accepted_at") else None,
                "is_adult": user.get("is_adult", True),
            }
        }

    async def update_user_profile(
        self,
        user_id: int,
        name: Optional[str] = None,
        email: Optional[str] = None,
        pais_id: Optional[int] = None,
        departamento_id: Optional[int] = None,
        fcm_token: Optional[str] = None,
        telefono: Optional[str] = None,
        idioma: Optional[str] = None,
        notificaciones_activas: Optional[bool] = None,
        app_version: Optional[str] = None,
        plataforma: Optional[str] = None,
        avatar_url: Optional[str] = None,
        terms_accepted_at: Optional[datetime] = None,
        is_adult: Optional[bool] = None
    ) -> Dict[str, Any]:
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

        if telefono is not None:
            updates["telefono"] = telefono

        if idioma is not None:
            updates["idioma"] = idioma

        if notificaciones_activas is not None:
            updates["notificaciones_activas"] = notificaciones_activas

        if app_version is not None:
            updates["app_version"] = app_version

        if plataforma is not None:
            updates["plataforma"] = plataforma

        if avatar_url is not None:
            updates["avatar_url"] = avatar_url

        if terms_accepted_at is not None:
            updates["terms_accepted_at"] = terms_accepted_at

        if is_adult is not None:
            updates["is_adult"] = is_adult

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
            raise ValueError("No existe una cuenta registrada con este correo electrónico")

        # Generar código numérico de 6 dígitos seguro
        code = str(secrets.randbelow(900000) + 100000)
        expires = datetime.utcnow() + timedelta(minutes=15)

        await self.user_repo.save_password_reset_token(user["id"], code, expires)
        return code

    async def send_password_reset_email_task(self, email: str, code: str) -> None:
        if not self.email_sender:
            return
        try:
            await self.email_sender.send_reset_password_code(email, code)
        except Exception as e:
            print(f"❌ Error en Background Task (email de recuperación): {e}")

    async def reset_password_with_code(self, email: str, code: str, new_password: str) -> Dict[str, Any]:
        user = await self.user_repo.find_by_email(email)
        if not user:
            raise ValueError("Usuario no encontrado")

        token_info = await self.user_repo.find_password_reset_token(code.strip())
        if not token_info or token_info[0] != user["id"]:
            raise ValueError("El código de 6 dígitos es incorrecto o no existe")

        user_id, expires = token_info
        now = datetime.utcnow()
        if expires.tzinfo is not None:
            from datetime import timezone
            now = datetime.now(timezone.utc)

        if now > expires:
            raise ValueError("El código de recuperación ha expirado. Por favor solicita uno nuevo.")

        hashed_pwd = security.hash_password(new_password)
        await self.user_repo.update_password(user_id, hashed_pwd)

        return {
            "success": True,
            "message": "Contraseña actualizada exitosamente. Ya puedes iniciar sesión con tu nueva contraseña."
        }

    async def social_login(self, provider: str, token: str) -> Dict[str, Any]:
        if provider.lower() != "google":
            raise ValueError(f"Proveedor '{provider}' no soportado")

        import httpx
        # Call Google tokeninfo to verify the ID token
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"https://oauth2.googleapis.com/tokeninfo?id_token={token}")
            if resp.status_code != 200:
                raise ValueError("Token de Google inválido o expirado")
            payload = resp.json()

        email = payload.get("email")
        name = payload.get("name") or email.split("@")[0]
        picture = payload.get("picture")
        email_verified = payload.get("email_verified") in [True, "true", "True"]

        if not email:
            raise ValueError("El token de Google no contiene correo electrónico")

        # Find user by email
        user = await self.user_repo.find_by_email(email)
        if not user:
            # Register new user with Null values for location
            user = await self.user_repo.create(
                name=name,
                email=email,
                password_hashed=None,
                pais_id=None,
                departamento_id=None,
                auth_provider="google",
                email_verified=email_verified,
                avatar_url=picture
            )
        else:
            # Validar si el usuario está activo
            if user.get("activo") is False:
                raise ValueError("Tu cuenta ha sido desactivada o suspendida. Por favor contacta a soporte.")

            # Actualizar foto si no tenía o cambió
            if picture and (not user.get("avatar_url") or user.get("avatar_url") != picture):
                user = await self.user_repo.update(user["id"], {"avatar_url": picture})

            # Actualizar último inicio de sesión
            await self.user_repo.update_last_login(user["id"])

        # Generate JWT tokens
        from app.core import security
        access_token = security.create_access_token(data={"sub": str(user["id"]), "email": user["email"]})
        refresh_token = security.create_refresh_token(data={"sub": str(user["id"]), "email": user["email"]})

        return {
            "success": True,
            "access_token": access_token,
            "refresh_token": refresh_token,
            "user": {
                "id": user["id"],
                "name": user["name"],
                "email": user["email"],
                "pais_id": user.get("pais_id"),
                "pais_nombre": user.get("pais_nombre"),
                "departamento_id": user.get("departamento_id"),
                "departamento_nombre": user.get("departamento_nombre"),
                "is_premium": user.get("is_premium", False),
                "premium_expires_at": user.get("premium_expires_at").isoformat() if user.get("premium_expires_at") else None,
                "activo": user.get("activo", True),
                "auth_provider": user.get("auth_provider", "google"),
                "avatar_url": user.get("avatar_url"),
                "telefono": user.get("telefono"),
                "idioma": user.get("idioma", "es"),
                "notificaciones_activas": user.get("notificaciones_activas", True),
            }
        }
