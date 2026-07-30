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
                    u.departamento_id, d.nombre AS departamento_nombre
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
                    u.departamento_id, d.nombre AS departamento_nombre
                FROM users u
                LEFT JOIN paises p ON p.id = u.pais_id
                LEFT JOIN departamentos d ON d.id = u.departamento_id
                WHERE LOWER(u.email) = $1
            """, email.strip().lower())
            return dict(row) if row else None

    async def create(self, name: str, email: str, password_hashed: str, pais_id: int, departamento_id: int) -> Dict[str, Any]:
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
                    u.departamento_id, d.nombre AS departamento_nombre
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
                    u.departamento_id, d.nombre AS departamento_nombre
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

    def save_password_reset_token(self, user_id: int, token: str, expires: datetime) -> None:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO password_reset_tokens(user_id, token, expires) VALUES (%s, %s, %s)",
                    (user_id, token, expires)
                )
            conn.commit()

    def find_password_reset_token(self, token: str) -> Optional[Tuple[int, datetime]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT user_id, expires FROM password_reset_tokens WHERE token = %s", (token,))
                row = cur.fetchone()
                return row if row else None

    def update_password(self, user_id: int, new_password_hashed: str) -> None:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("UPDATE users SET password = %s WHERE id = %s", (new_password_hashed, user_id))
                cur.execute("DELETE FROM password_reset_tokens WHERE user_id = %s", (user_id,))
            conn.commit()
