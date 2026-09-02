from typing import Optional, Dict, Any, Tuple
from datetime import datetime
from app.domain.ports import UserRepositoryPort
from app.infrastructure import db_connection

class PostgresUserRepository(UserRepositoryPort):
    _schema_ensured: bool = False

    @classmethod
    async def ensure_schema(cls, conn):
        if cls._schema_ensured:
            return
        try:
            # 1. Asegurar columnas de suscripción y perfil en users
            await conn.execute("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMP WITH TIME ZONE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS google_order_id VARCHAR(255);
                ALTER TABLE users ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS rol VARCHAR(20) DEFAULT 'user';
                ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(30) DEFAULT 'email';
                ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500);
                ALTER TABLE users ADD COLUMN IF NOT EXISTS telefono VARCHAR(30);
                ALTER TABLE users ADD COLUMN IF NOT EXISTS idioma VARCHAR(10) DEFAULT 'es';
                ALTER TABLE users ADD COLUMN IF NOT EXISTS notificaciones_activas BOOLEAN DEFAULT TRUE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP WITH TIME ZONE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS is_adult BOOLEAN DEFAULT TRUE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS app_version VARCHAR(20);
                ALTER TABLE users ADD COLUMN IF NOT EXISTS plataforma VARCHAR(20);

                -- Columnas para Horario y Estado en Publicidad
                ALTER TABLE publicidad ADD COLUMN IF NOT EXISTS es_24_7 BOOLEAN DEFAULT TRUE;
                ALTER TABLE publicidad ADD COLUMN IF NOT EXISTS hora_apertura VARCHAR(10) DEFAULT '00:00';
                ALTER TABLE publicidad ADD COLUMN IF NOT EXISTS hora_cierre VARCHAR(10) DEFAULT '23:59';
                ALTER TABLE publicidad ADD COLUMN IF NOT EXISTS dias_atencion VARCHAR(50) DEFAULT 'Todos los días';
                ALTER TABLE publicidad ADD COLUMN IF NOT EXISTS estado_texto VARCHAR(50) DEFAULT 'Abierto 24/7';
            """)

            # Crear tabla de calificaciones / likes de publicidad
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS publicidad_calificaciones (
                    id SERIAL PRIMARY KEY,
                    publicidad_id INT NOT NULL REFERENCES publicidad(id) ON DELETE CASCADE,
                    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    estrellas INT DEFAULT 5,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(publicidad_id, user_id)
                );
                CREATE INDEX IF NOT EXISTS idx_pub_calificaciones_pub_id ON publicidad_calificaciones (publicidad_id);
            """)

            # 2. Crear tabla histórica de suscripciones / compras
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS user_subscriptions (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    product_id VARCHAR(100) NOT NULL,
                    purchase_token TEXT,
                    order_id VARCHAR(255),
                    status VARCHAR(50) DEFAULT 'active',
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    expires_at TIMESTAMP WITH TIME ZONE
                );
                CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions (user_id);
            """)

            # 3. Crear tabla de tokens / códigos de recuperación de contraseña
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS password_reset_tokens (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    token VARCHAR(255) NOT NULL,
                    expires TIMESTAMP WITH TIME ZONE NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens (token);
                CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens (user_id);
            """)

            # 4. Crear tabla de códigos de verificación de correo
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS email_verification_codes (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    code VARCHAR(10) NOT NULL,
                    expires TIMESTAMP WITH TIME ZONE NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_email_verification_codes_user ON email_verification_codes (user_id);
                CREATE INDEX IF NOT EXISTS idx_email_verification_codes_code ON email_verification_codes (code);
            """)
            cls._schema_ensured = True
        except Exception as e:
            print(f"⚠️ Error en ensure_schema de PostgresUserRepository: {e}")

    async def _ensure_table(self, conn):
        if not PostgresUserRepository._schema_ensured:
            await PostgresUserRepository.ensure_schema(conn)

    async def find_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            row = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email, u.password as password_hashed,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token,
                    COALESCE(u.is_premium, FALSE) AS is_premium,
                    u.premium_expires_at,
                    u.google_order_id,
                    COALESCE(u.activo, TRUE) AS activo,
                    COALESCE(u.auth_provider, 'email') AS auth_provider,
                    COALESCE(u.email_verified, FALSE) AS email_verified,
                    u.avatar_url,
                    u.telefono,
                    COALESCE(u.idioma, 'es') AS idioma,
                    COALESCE(u.notificaciones_activas, TRUE) AS notificaciones_activas,
                    u.app_version,
                    u.plataforma,
                    u.terms_accepted_at,
                    COALESCE(u.is_adult, TRUE) AS is_adult,
                    u.created_at,
                    u.updated_at,
                    u.last_login_at
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE u.id = $1
            """, user_id)
            return dict(row) if row else None

    async def find_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            # Buscar por email (case insensitive)
            row = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email, u.password as password_hashed,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token,
                    COALESCE(u.is_premium, FALSE) AS is_premium,
                    u.premium_expires_at,
                    u.google_order_id,
                    COALESCE(u.activo, TRUE) AS activo,
                    COALESCE(u.auth_provider, 'email') AS auth_provider,
                    COALESCE(u.email_verified, FALSE) AS email_verified,
                    u.avatar_url,
                    u.telefono,
                    COALESCE(u.idioma, 'es') AS idioma,
                    COALESCE(u.notificaciones_activas, TRUE) AS notificaciones_activas,
                    u.app_version,
                    u.plataforma,
                    u.terms_accepted_at,
                    COALESCE(u.is_adult, TRUE) AS is_adult,
                    u.created_at,
                    u.updated_at,
                    u.last_login_at
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE LOWER(u.email) = $1
            """, email.strip().lower())
            return dict(row) if row else None

    async def create(
        self,
        name: str,
        email: str,
        password_hashed: Optional[str],
        pais_id: Optional[int],
        departamento_id: Optional[int],
        auth_provider: str = 'email',
        email_verified: bool = False,
        avatar_url: Optional[str] = None,
        terms_accepted_at: Optional[datetime] = None,
        is_adult: bool = True
    ) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            normalized_email = email.strip().lower()
            normalized_name = name.strip().title()

            await conn.execute("""
                INSERT INTO users (
                    name, email, password, pais_id, departamento_id,
                    is_premium, auth_provider, email_verified, avatar_url,
                    activo, terms_accepted_at, is_adult, created_at, updated_at, last_login_at
                )
                VALUES ($1, $2, $3, $4, $5, FALSE, $6, $7, $8, TRUE, $9, $10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """, normalized_name, normalized_email, password_hashed, pais_id, departamento_id, auth_provider, email_verified, avatar_url, terms_accepted_at, is_adult)

            return await self.find_by_email(normalized_email) or {}

    async def update(self, user_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            fields = []
            values = []
            for k, v in updates.items():
                fields.append(f"{k} = ${len(values) + 1}")
                values.append(v)

            # Actualizar siempre updated_at
            fields.append("updated_at = CURRENT_TIMESTAMP")

            values.append(user_id)
            query = f"""
                UPDATE users
                SET {', '.join(fields)}
                WHERE id = ${len(values)}
                RETURNING id;
            """
            await conn.execute(query, *values)

            return await self.find_by_id(user_id) or {}

    async def update_last_login(self, user_id: int) -> None:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            await conn.execute("UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1", user_id)

    async def set_premium(
        self,
        user_id: int,
        is_premium: bool,
        expires_at: Optional[datetime] = None,
        order_id: Optional[str] = None,
        purchase_token: Optional[str] = None,
        product_id: Optional[str] = None
    ) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            async with conn.transaction():
                # 1. Actualizar usuario
                await conn.execute("""
                    UPDATE users
                    SET is_premium = $1, premium_expires_at = $2, google_order_id = $3
                    WHERE id = $4
                """, is_premium, expires_at, order_id, user_id)

                # 2. Registrar/actualizar el historial de suscripciones.
                #    Si Google/Flutter reenvía el mismo purchase_token, no duplicamos filas.
                if product_id:
                    existing = None
                    if purchase_token:
                        existing = await conn.fetchrow(
                            """
                            SELECT id
                            FROM user_subscriptions
                            WHERE purchase_token = $1
                            ORDER BY created_at DESC
                            LIMIT 1
                            """,
                            purchase_token
                        )

                    if existing:
                        await conn.execute(
                            """
                            UPDATE user_subscriptions
                            SET user_id = $1,
                                product_id = $2,
                                order_id = COALESCE($3, order_id),
                                status = $4,
                                expires_at = COALESCE($5, expires_at)
                            WHERE id = $6
                            """,
                            user_id,
                            product_id,
                            order_id,
                            'active' if is_premium else 'expired',
                            expires_at,
                            existing["id"]
                        )
                    else:
                        await conn.execute(
                            """
                            INSERT INTO user_subscriptions (
                                user_id,
                                product_id,
                                purchase_token,
                                order_id,
                                status,
                                expires_at
                            )
                            VALUES ($1, $2, $3, $4, $5, $6)
                            """,
                            user_id,
                            product_id,
                            purchase_token,
                            order_id,
                            'active' if is_premium else 'expired',
                            expires_at
                        )

            return {
                "success": True,
                "user_id": user_id,
                "is_premium": is_premium,
                "expires_at": expires_at.isoformat() if expires_at else None
            }

    async def find_user_id_by_purchase_token(self, purchase_token: str) -> Optional[int]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            row = await conn.fetchrow(
                """
                SELECT user_id
                FROM user_subscriptions
                WHERE purchase_token = $1
                ORDER BY created_at DESC
                LIMIT 1
                """,
                purchase_token
            )
            return int(row["user_id"]) if row else None

    async def update_subscription_state(
        self,
        user_id: int,
        is_premium: bool,
        expires_at: Optional[datetime] = None,
        purchase_token: Optional[str] = None,
        product_id: Optional[str] = None,
        order_id: Optional[str] = None,
        status: Optional[str] = None
    ) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE users
                    SET is_premium = $1,
                        premium_expires_at = $2,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = $3
                    """,
                    is_premium, expires_at, user_id
                )

                if purchase_token:
                    await conn.execute(
                        """
                        UPDATE user_subscriptions
                        SET status = COALESCE($1, status),
                            expires_at = COALESCE($2, expires_at),
                            product_id = COALESCE($3, product_id),
                            order_id = COALESCE($4, order_id)
                        WHERE purchase_token = $5
                        """,
                        status, expires_at, product_id, order_id, purchase_token
                    )

            return {
                "success": True,
                "user_id": user_id,
                "is_premium": is_premium,
                "expires_at": expires_at.isoformat() if expires_at else None,
                "status": status
            }

    async def mark_expired_subscriptions(self, user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE users
                    SET is_premium = FALSE,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = $1
                      AND (
                          is_premium = TRUE
                          OR premium_expires_at IS NOT NULL
                      )
                      AND premium_expires_at IS NOT NULL
                      AND premium_expires_at <= CURRENT_TIMESTAMP
                    """,
                    user_id
                )

                # Marcar como expiradas solo las suscripciones que ya superaron
                # su expiry real. Esto es una reconciliación defensiva y no crea filas.
                result = await conn.execute(
                    """
                    UPDATE user_subscriptions
                    SET status = 'expired'
                    WHERE user_id = $1
                      AND status IN ('active', 'canceled', 'grace_period')
                      AND expires_at IS NOT NULL
                      AND expires_at <= CURRENT_TIMESTAMP
                    """,
                    user_id
                )

                # asyncpg devuelve "UPDATE <n>"
                try:
                    updated_count = int(result.split()[-1])
                except (ValueError, IndexError):
                    updated_count = 0

                return updated_count > 0

    async def delete(self, user_id: int) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            existing = await conn.fetchrow("SELECT id, name, email FROM users WHERE id = $1", user_id)
            if not existing:
                raise ValueError("Usuario no encontrado")
            await conn.execute("DELETE FROM users WHERE id = $1", user_id)
            return dict(existing)

    async def save_password_reset_token(self, user_id: int, token: str, expires: datetime) -> None:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO password_reset_tokens(user_id, token, expires) VALUES ($1, $2, $3)",
                user_id, token, expires
            )

    async def find_password_reset_token(self, token: str) -> Optional[Tuple[int, datetime]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow("SELECT user_id, expires FROM password_reset_tokens WHERE token = $1", token)
            return (row['user_id'], row['expires']) if row else None

    async def update_password(self, user_id: int, new_password_hashed: str) -> None:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            # Usar una transacción para asegurar que ambas operaciones ocurran o ninguna
            async with conn.transaction():
                await conn.execute("UPDATE users SET password = $1 WHERE id = $2", new_password_hashed, user_id)
                await conn.execute("DELETE FROM password_reset_tokens WHERE user_id = $1", user_id)

    async def save_email_verification_code(self, user_id: int, code: str, expires: datetime) -> None:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            # Eliminar códigos previos no usados
            await conn.execute("DELETE FROM email_verification_codes WHERE user_id = $1", user_id)
            await conn.execute(
                "INSERT INTO email_verification_codes(user_id, code, expires) VALUES ($1, $2, $3)",
                user_id, code, expires
            )

    async def find_email_verification_code(self, user_id: int, code: str) -> Optional[datetime]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT expires FROM email_verification_codes WHERE user_id = $1 AND code = $2",
                user_id, code
            )
            return row['expires'] if row else None

    async def verify_user_email(self, user_id: int) -> None:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute("UPDATE users SET email_verified = TRUE WHERE id = $1", user_id)
                await conn.execute("DELETE FROM email_verification_codes WHERE user_id = $1", user_id)
