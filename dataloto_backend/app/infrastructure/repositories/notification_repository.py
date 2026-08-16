from typing import List, Optional, Dict, Any
from datetime import datetime
from app.domain.ports import NotificationRepositoryPort
from app.infrastructure import db_connection

class PostgresNotificationRepository(NotificationRepositoryPort):
    async def create_notification(self, loteria_id: Optional[int], fecha_sorteo: Optional[datetime], mensaje: str, tipo: str, user_id: Optional[int] = None) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO notificaciones (usuario_id, loteria_id, fecha_sorteo, mensaje, tipo, leido, created_at)
                VALUES ($1, $2, $3, $4, $5, FALSE, CURRENT_TIMESTAMP)
            """, user_id, loteria_id, fecha_sorteo, mensaje, tipo)
            return {"success": True, "message": "Notificación creada"}

    async def list_notifications(self, user_id: Optional[int] = None, limit: int = 20) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            # Seleccionamos campos de notificaciones y metadata de la tabla loterias
            base_query = """
                SELECT n.*, l.pais_id, l.nombre AS loteria_nombre, l.route AS loteria_route 
                FROM notificaciones n
                LEFT JOIN loterias l ON l.id = n.loteria_id
                WHERE (n.usuario_id = $1 OR n.usuario_id IS NULL)
                AND n.created_at >= NOW() - INTERVAL '2 days'
                ORDER BY n.created_at DESC LIMIT $2
            """
            
            if user_id:
                rows = await conn.fetch(base_query, user_id, limit)
            else:
                # Si no hay user_id, mostramos solo las globales (usuario_id is null)
                query_no_user = """
                    SELECT n.*, l.pais_id, l.nombre AS loteria_nombre, l.route AS loteria_route 
                    FROM notificaciones n
                    LEFT JOIN loterias l ON l.id = n.loteria_id
                    WHERE n.usuario_id IS NULL 
                    AND n.created_at >= NOW() - INTERVAL '2 days' 
                    ORDER BY n.created_at DESC LIMIT $1
                """
                rows = await conn.fetch(query_no_user, limit)
            return [dict(r) for r in rows]

    async def mark_as_read(self, notification_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            result = await conn.execute("UPDATE notificaciones SET leido = TRUE WHERE id = $1", notification_id)
            return result == "UPDATE 1"
