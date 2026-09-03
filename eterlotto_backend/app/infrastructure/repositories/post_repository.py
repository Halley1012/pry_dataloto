from typing import Optional, List, Dict, Any
from app.domain.ports import PostRepositoryPort
from app.infrastructure import db_connection

class PostgresPostRepository(PostRepositoryPort):
    async def create_post(self, title: str, content: str, user_id: int) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            record = await conn.fetchrow("""
                INSERT INTO posts (title, content, user_id, created_at)
                VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
                RETURNING id, title, content, user_id, created_at
            """, title, content, user_id)
            user = await conn.fetchrow("SELECT name FROM users WHERE id = $1", user_id)
            res = dict(record)
            res["user_name"] = user["name"] if user else ""
            return res

    async def list_posts(self, skip: int, limit: int) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            records = await conn.fetch("""
                SELECT 
                    p.id, p.title, p.content, p.user_id, p.created_at, u.name AS user_name,
                    (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.status = 'active') AS comments_count
                FROM posts p
                JOIN users u ON p.user_id = u.id
                ORDER BY p.created_at DESC
                LIMIT $1 OFFSET $2
            """, limit, skip)
            return [dict(r) for r in records]

    async def update_post(self, post_id: int, title: str, content: str, user_id: int) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            existing = await conn.fetchrow("SELECT user_id FROM posts WHERE id = $1", post_id)
            if not existing:
                return None
            if existing["user_id"] != user_id:
                raise PermissionError("No autorizado para editar este post")

            updated = await conn.fetchrow("""
                UPDATE posts
                SET title = $1, content = $2
                WHERE id = $3
                RETURNING id, title, content, user_id, created_at
            """, title, content, post_id)
            
            user = await conn.fetchrow("SELECT name FROM users WHERE id = $1", user_id)
            res = dict(updated)
            res["user_name"] = user["name"] if user else ""
            return res

    async def delete_post(self, post_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            existing = await conn.fetchrow("SELECT user_id FROM posts WHERE id = $1", post_id)
            if not existing:
                return False
            if existing["user_id"] != user_id:
                raise PermissionError("No autorizado para eliminar este post")
            await conn.execute("DELETE FROM posts WHERE id = $1", post_id)
            return True

    async def create_comment(self, post_id: int, user_id: int, content: str, parent_id: Optional[int] = None, status: str = "active", moderation_reason: Optional[str] = None) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            record = await conn.fetchrow("""
                INSERT INTO comments (post_id, user_id, content, parent_id, status, moderation_reason, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                RETURNING id, post_id, user_id, content, parent_id, status, moderation_reason, created_at, updated_at
            """, post_id, user_id, content, parent_id, status, moderation_reason)

            user = await conn.fetchrow("SELECT name FROM users WHERE id = $1", user_id)
            res = dict(record)
            res["user_name"] = user["name"] if user else ""
            return res

    async def update_comment(self, comment_id: int, user_id: int, content: str, status: str = "active", moderation_reason: Optional[str] = None) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            existing = await conn.fetchrow("SELECT user_id, post_id FROM comments WHERE id = $1", comment_id)
            if not existing:
                return None
            if existing["user_id"] != user_id:
                raise PermissionError("No autorizado para editar este comentario")

            updated = await conn.fetchrow("""
                UPDATE comments
                SET content = $1, status = $2, moderation_reason = $3, updated_at = CURRENT_TIMESTAMP
                WHERE id = $4
                RETURNING id, post_id, user_id, content, parent_id, status, moderation_reason, created_at, updated_at
            """, content, status, moderation_reason, comment_id)
            user = await conn.fetchrow("SELECT name FROM users WHERE id = $1", user_id)
            res = dict(updated)
            res["user_name"] = user["name"] if user else ""
            return res

    async def delete_comment(self, comment_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            existing = await conn.fetchrow("SELECT user_id FROM comments WHERE id = $1", comment_id)
            if not existing:
                return False
            if existing["user_id"] != user_id:
                raise PermissionError("No autorizado para eliminar este comentario")
            await conn.execute("""
                UPDATE comments 
                SET status = 'deleted', updated_at = CURRENT_TIMESTAMP 
                WHERE id = $1
            """, comment_id)
            return True

    async def list_comments_by_post(self, post_id: int) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            records = await conn.fetch("""
                SELECT c.id, c.post_id, c.user_id, c.content, c.parent_id, c.status, c.moderation_reason, 
                       c.created_at, c.updated_at, u.name AS user_name
                FROM comments c
                JOIN users u ON c.user_id = u.id
                WHERE c.post_id = $1 AND c.status = 'active'
                ORDER BY c.created_at ASC
            """, post_id)
            return [dict(r) for r in records]
