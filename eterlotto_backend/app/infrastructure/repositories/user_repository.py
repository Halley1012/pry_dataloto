from typing import Optional, Dict, Any, Tuple
from datetime import datetime
from app.domain.ports import UserRepositoryPort
from app.infrastructure import db_connection

class PostgresUserRepository(UserRepositoryPort):
    async def find_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email, u.password as password_hashed,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE u.id = $1
            """, user_id)
            return dict(row) if row else None

    async def find_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            # Buscar por email (case insensitive)
            row = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email, u.password as password_hashed,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE LOWER(u.email) = $1
            """, email.strip().lower())
            return dict(row) if row else None

    async def create(self, name: str, email: str, password_hashed: Optional[str], pais_id: Optional[int], departamento_id: Optional[int]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            normalized_email = email.strip().lower()
            normalized_name = name.strip().title()

            await conn.execute("""
                INSERT INTO users (name, email, password, pais_id, departamento_id)
                VALUES ($1, $2, $3, $4, $5)
            """, normalized_name, normalized_email, password_hashed, pais_id, departamento_id)

            row = await conn.fetchrow("""
                SELECT 
                    u.id, u.name, u.email,
                    u.pais_id, p.nombre AS pais_nombre,
                    u.departamento_id, d.nombre AS departamento_nombre,
                    u.fcm_token
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE LOWER(u.email) = $1
            """, normalized_email)
            return dict(row)

    async def update(self, user_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
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
                    u.fcm_token
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE u.id = $1
            """, user_id)
            return dict(updated)

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
