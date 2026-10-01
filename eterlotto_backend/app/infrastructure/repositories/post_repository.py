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
            user = await conn.fetchrow(
                "SELECT name, avatar_url FROM users WHERE id = $1",
                user_id,
            )
            res = dict(record)
            res["user_name"] = user["name"] if user else ""
            res["avatar_url"] = user["avatar_url"] if user else None
            res["comments_count"] = 0
            res["total_likes"] = 0
            res["is_liked"] = False
            return res

    async def list_posts(
        self,
        skip: int,
        limit: int,
        requesting_user_id: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            records = await conn.fetch(
                """
                SELECT
                    p.id,
                    p.title,
                    p.content,
                    p.user_id,
                    p.created_at,
                    u.name AS user_name,
                    u.avatar_url,
                    (
                        SELECT COUNT(*)
                        FROM comments c
                        WHERE c.post_id = p.id
                          AND c.status IN ('active', 'approved')
                    ) AS comments_count,
                    (
                        SELECT COUNT(*)
                        FROM post_likes pl
                        WHERE pl.post_id = p.id
                    ) AS total_likes,
                    CASE
                        WHEN $3::BIGINT IS NULL THEN FALSE
                        ELSE EXISTS (
                            SELECT 1
                            FROM post_likes pl2
                            WHERE pl2.post_id = p.id
                              AND pl2.user_id = $3
                        )
                    END AS is_liked
                FROM posts p
                JOIN users u ON p.user_id = u.id
                ORDER BY p.created_at DESC
                LIMIT $1 OFFSET $2
                """,
                limit,
                skip,
                requesting_user_id,
            )
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
            
            user = await conn.fetchrow(
                "SELECT name, avatar_url FROM users WHERE id = $1",
                user_id,
            )
            res = dict(updated)
            res["user_name"] = user["name"] if user else ""
            res["avatar_url"] = user["avatar_url"] if user else None
            res["comments_count"] = await conn.fetchval(
                """
                SELECT COUNT(*)
                FROM comments
                WHERE post_id = $1
                  AND status IN ('active', 'approved')
                """,
                post_id,
            ) or 0
            res["total_likes"] = await conn.fetchval(
                "SELECT COUNT(*) FROM post_likes WHERE post_id = $1",
                post_id,
            ) or 0
            res["is_liked"] = bool(
                await conn.fetchval(
                    """
                    SELECT EXISTS(
                        SELECT 1
                        FROM post_likes
                        WHERE post_id = $1 AND user_id = $2
                    )
                    """,
                    post_id,
                    user_id,
                )
            )
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

            user = await conn.fetchrow(
                "SELECT name, avatar_url FROM users WHERE id = $1",
                user_id,
            )
            res = dict(record)
            res["user_name"] = user["name"] if user else ""
            res["avatar_url"] = user["avatar_url"] if user else None
            res["total_likes"] = 0
            res["is_liked"] = False
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
            user = await conn.fetchrow(
                "SELECT name, avatar_url FROM users WHERE id = $1",
                user_id,
            )
            res = dict(updated)
            res["user_name"] = user["name"] if user else ""
            res["avatar_url"] = user["avatar_url"] if user else None
            res["total_likes"] = await conn.fetchval(
                "SELECT COUNT(*) FROM comment_likes WHERE comment_id = $1",
                comment_id,
            ) or 0
            res["is_liked"] = bool(
                await conn.fetchval(
                    """
                    SELECT EXISTS(
                        SELECT 1
                        FROM comment_likes
                        WHERE comment_id = $1 AND user_id = $2
                    )
                    """,
                    comment_id,
                    user_id,
                )
            )
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

    async def report_comment(self, comment_id: int, reporter_user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            comment = await conn.fetchrow(
                """
                SELECT user_id, status
                FROM comments
                WHERE id = $1
                """,
                comment_id,
            )
            if not comment or comment["status"] not in ("active", "approved"):
                raise ValueError("Comentario no disponible para reportar")
            if comment["user_id"] == reporter_user_id:
                raise PermissionError("No puedes reportar tu propio comentario")

            report = await conn.fetchrow(
                """
                INSERT INTO comment_reports (comment_id, reporter_user_id)
                VALUES ($1, $2)
                ON CONFLICT (comment_id, reporter_user_id) DO NOTHING
                RETURNING id
                """,
                comment_id,
                reporter_user_id,
            )
            return report is not None

    async def list_comments_by_post(
        self,
        post_id: int,
        requesting_user_id: int,
    ) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            records = await conn.fetch(
                """
                SELECT
                    c.id,
                    c.post_id,
                    c.user_id,
                    c.content,
                    c.parent_id,
                    c.status,
                    c.moderation_reason,
                    c.created_at,
                    c.updated_at,
                    u.name AS user_name,
                    u.avatar_url,
                    (
                        SELECT COUNT(*)
                        FROM comment_likes cl
                        WHERE cl.comment_id = c.id
                    ) AS total_likes,
                    EXISTS (
                        SELECT 1
                        FROM comment_likes cl2
                        WHERE cl2.comment_id = c.id
                          AND cl2.user_id = $2
                    ) AS is_liked
                FROM comments c
                JOIN users u ON c.user_id = u.id
                WHERE c.post_id = $1
                  AND (
                      c.status IN ('active', 'approved')
                      OR (c.status = 'pending' AND c.user_id = $2)
                  )
                ORDER BY c.created_at ASC
                """,
                post_id,
                requesting_user_id,
            )
            return [dict(r) for r in records]

    async def toggle_post_like(
        self,
        post_id: int,
        user_id: int,
    ) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            async with conn.transaction():
                exists = await conn.fetchval(
                    "SELECT 1 FROM posts WHERE id = $1",
                    post_id,
                )
                if not exists:
                    raise ValueError("Post no encontrado")

                deleted = await conn.fetchrow(
                    """
                    DELETE FROM post_likes
                    WHERE post_id = $1 AND user_id = $2
                    RETURNING id
                    """,
                    post_id,
                    user_id,
                )

                if deleted is not None:
                    is_liked = False
                else:
                    await conn.execute(
                        """
                        INSERT INTO post_likes (post_id, user_id)
                        VALUES ($1, $2)
                        ON CONFLICT (post_id, user_id) DO NOTHING
                        """,
                        post_id,
                        user_id,
                    )
                    is_liked = True

                total_likes = await conn.fetchval(
                    "SELECT COUNT(*) FROM post_likes WHERE post_id = $1",
                    post_id,
                ) or 0

                return {
                    "success": True,
                    "post_id": post_id,
                    "is_liked": is_liked,
                    "total_likes": int(total_likes),
                }

    async def toggle_comment_like(
        self,
        comment_id: int,
        user_id: int,
    ) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            async with conn.transaction():
                comment = await conn.fetchrow(
                    """
                    SELECT status
                    FROM comments
                    WHERE id = $1
                    """,
                    comment_id,
                )
                if not comment or comment["status"] not in ("active", "approved"):
                    raise ValueError("Comentario no disponible")

                deleted = await conn.fetchrow(
                    """
                    DELETE FROM comment_likes
                    WHERE comment_id = $1 AND user_id = $2
                    RETURNING id
                    """,
                    comment_id,
                    user_id,
                )

                if deleted is not None:
                    is_liked = False
                else:
                    await conn.execute(
                        """
                        INSERT INTO comment_likes (comment_id, user_id)
                        VALUES ($1, $2)
                        ON CONFLICT (comment_id, user_id) DO NOTHING
                        """,
                        comment_id,
                        user_id,
                    )
                    is_liked = True

                total_likes = await conn.fetchval(
                    """
                    SELECT COUNT(*)
                    FROM comment_likes
                    WHERE comment_id = $1
                    """,
                    comment_id,
                ) or 0

                return {
                    "success": True,
                    "comment_id": comment_id,
                    "is_liked": is_liked,
                    "total_likes": int(total_likes),
                }

