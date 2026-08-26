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
            # 1. Asegurar columnas de suscripción en users
            await conn.execute("""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMP WITH TIME ZONE;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS google_order_id VARCHAR(255);
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
                    u.google_order_id
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
                    u.google_order_id
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE LOWER(u.email) = $1
            """, email.strip().lower())
            return dict(row) if row else None

    async def create(self, name: str, email: str, password_hashed: Optional[str], pais_id: Optional[int], departamento_id: Optional[int]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            normalized_email = email.strip().lower()
            normalized_name = name.strip().title()

            await conn.execute("""
                INSERT INTO users (name, email, password, pais_id, departamento_id, is_premium)
                VALUES ($1, $2, $3, $4, $5, FALSE)
            """, normalized_name, normalized_email, password_hashed, pais_id, departamento_id)

            row = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token,
                    COALESCE(u.is_premium, FALSE) AS is_premium,
                    u.premium_expires_at
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE LOWER(u.email) = $1
            """, normalized_email)
            return dict(row)

    async def update(self, user_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            fields = []
            values = []
            for k, v in updates.items():
                fields.append(f"{k} = ${len(values) + 1}")
                values.append(v)

            values.append(user_id)
            query = f"""
                UPDATE users
                SET {', '.join(fields)}
                WHERE id = ${len(values)}
                RETURNING id;
            """
            await conn.execute(query, *values)

            updated = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token,
                    COALESCE(u.is_premium, FALSE) AS is_premium,
                    u.premium_expires_at
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE u.id = $1
            """, user_id)
            return dict(updated)

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

                # 2. Registrar en historial de suscripciones si aplica
                if product_id:
                    await conn.execute("""
                        INSERT INTO user_subscriptions (user_id, product_id, purchase_token, order_id, status, expires_at)
                        VALUES ($1, $2, $3, $4, $5, $6)
                    """, user_id, product_id, purchase_token, order_id, 'active' if is_premium else 'expired', expires_at)

            return {
                "success": True,
                "user_id": user_id,
                "is_premium": is_premium,
                "expires_at": expires_at.isoformat() if expires_at else None
            }

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
