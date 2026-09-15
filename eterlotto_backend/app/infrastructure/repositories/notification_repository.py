from typing import List, Optional, Dict, Any
from datetime import datetime
from app.domain.ports import NotificationRepositoryPort
from app.infrastructure import db_connection

class PostgresNotificationRepository(NotificationRepositoryPort):
    async def _ensure_user_state_table(self, conn) -> None:
        """Guarda el estado de una notificación global por usuario, no en ella."""
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS notification_user_state (
                notification_id INTEGER NOT NULL REFERENCES notificaciones(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                leido BOOLEAN NOT NULL DEFAULT FALSE,
                eliminado BOOLEAN NOT NULL DEFAULT FALSE,
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (notification_id, user_id)
            );
            CREATE INDEX IF NOT EXISTS idx_notification_user_state_visible
                ON notification_user_state (user_id, eliminado, notification_id);
        """)

    async def create_notification(self, loteria_id: Optional[int], fecha_sorteo: Optional[datetime], mensaje: str, tipo: str, user_id: Optional[int] = None) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO notificaciones (usuario_id, loteria_id, fecha_sorteo, mensaje, tipo, leido, created_at)
                VALUES ($1, $2, $3, $4, $5, FALSE, CURRENT_TIMESTAMP)
            """, user_id, loteria_id, fecha_sorteo, mensaje, tipo)
            return {"success": True, "message": "Notificación creada"}

    async def list_notifications(self, user_id: Optional[int] = None, limit: int = 50) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_user_state_table(conn)
            # Una global se entrega al país del usuario, a sus loterías jugadas
            # o a todos si no está asociada a una lotería. El estado es privado.
            base_query = """
                SELECT n.id, n.usuario_id, n.loteria_id, n.fecha_sorteo, n.mensaje,
                       n.tipo, n.created_at, l.pais_id, l.nombre AS loteria_nombre,
                       l.route AS loteria_route,
                       CASE
                         WHEN n.usuario_id = $1 THEN COALESCE(s.leido, n.leido, FALSE)
                         ELSE COALESCE(s.leido, FALSE)
                       END AS leido
                FROM notificaciones n
                LEFT JOIN loterias l ON l.id = n.loteria_id
                LEFT JOIN users u ON u.id = $1
                LEFT JOIN notification_user_state s
                    ON s.notification_id = n.id AND s.user_id = $1
                WHERE n.created_at >= NOW() - INTERVAL '3 days'
                  AND COALESCE(s.eliminado, FALSE) = FALSE
                  AND (
                    n.usuario_id = $1
                    OR (
                      n.usuario_id IS NULL
                      AND COALESCE(u.notificaciones_activas, TRUE) = TRUE
                      AND (
                        n.loteria_id IS NULL
                        OR l.pais_id = u.pais_id
                        OR EXISTS (
                          SELECT 1 FROM jugadas j
                          WHERE j.user_id = $1
                            AND j.loteria_id = n.loteria_id
                            AND (j.expira IS NULL OR j.expira >= CURRENT_TIMESTAMP)
                        )
                      )
                    )
                  )
                ORDER BY n.created_at DESC LIMIT $2
            """
            
            if user_id is not None:
                rows = await conn.fetch(base_query, user_id, limit)
            else:
                # Sin sesión no se puede resolver país ni loterías jugadas.
                query_no_user = """
                    SELECT n.*, l.pais_id, l.nombre AS loteria_nombre, l.route AS loteria_route 
                    FROM notificaciones n
                    LEFT JOIN loterias l ON l.id = n.loteria_id
                    WHERE n.usuario_id IS NULL 
                    AND n.created_at >= NOW() - INTERVAL '3 days' 
                    ORDER BY n.created_at DESC LIMIT $1
                """
                rows = await conn.fetch(query_no_user, limit)
            return [dict(r) for r in rows]

    async def mark_as_read(self, notification_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_user_state_table(conn)
            result = await conn.execute("""
                INSERT INTO notification_user_state
                    (notification_id, user_id, leido, eliminado, updated_at)
                SELECT id, $2, TRUE, FALSE, CURRENT_TIMESTAMP
                FROM notificaciones
                WHERE id = $1 AND (usuario_id = $2 OR usuario_id IS NULL)
                ON CONFLICT (notification_id, user_id)
                DO UPDATE SET leido = TRUE, updated_at = CURRENT_TIMESTAMP
            """, notification_id, user_id)
            return result in ("INSERT 0 1", "UPDATE 1")

    async def delete_notification(self, notification_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_user_state_table(conn)
            # Eliminar significa ocultar para este usuario; nunca borra el aviso global.
            result = await conn.execute("""
                INSERT INTO notification_user_state
                    (notification_id, user_id, leido, eliminado, updated_at)
                SELECT id, $2, TRUE, TRUE, CURRENT_TIMESTAMP
                FROM notificaciones
                WHERE id = $1 AND (usuario_id = $2 OR usuario_id IS NULL)
                ON CONFLICT (notification_id, user_id)
                DO UPDATE SET leido = TRUE, eliminado = TRUE, updated_at = CURRENT_TIMESTAMP
            """, notification_id, user_id)
            return result in ("INSERT 0 1", "UPDATE 1")
