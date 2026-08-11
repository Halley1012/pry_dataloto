from typing import Optional, Tuple, List, Dict, Any
from datetime import datetime
from app.domain.ports import JugadaRepositoryPort
from app.infrastructure import db_connection

class PostgresJugadaRepository(JugadaRepositoryPort):
    async def _ensure_table(self, conn, tabla: str):
        await conn.execute(f"""
            CREATE TABLE IF NOT EXISTS {tabla} (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL,
                numeros INTEGER[] NOT NULL,
                fecha_guardado TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                expira TIMESTAMP WITH TIME ZONE
            );
        """)
        await conn.execute(f"""
            DELETE FROM {tabla}
            WHERE (expira IS NOT NULL AND expira < CURRENT_TIMESTAMP)
               OR fecha_guardado < CURRENT_TIMESTAMP - INTERVAL '7 days';
        """)

    async def create_jugada(self, tipo: str, user_id: int, numeros: List[int], fecha_guardado: datetime, expira: datetime) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        tabla = f"jugadas_{tipo}"
        async with pool.acquire() as conn:
            await self._ensure_table(conn, tabla)
            row = await conn.fetchrow(f"""
                INSERT INTO {tabla} (user_id, numeros, fecha_guardado, expira)
                VALUES ($1, $2, $3, $4)
                RETURNING id, user_id, numeros, fecha_guardado, expira
            """, user_id, numeros, fecha_guardado, expira)
            return dict(row)

    async def list_jugadas(self, tipo: str, user_id: int) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        tabla = f"jugadas_{tipo}"
        async with pool.acquire() as conn:
            await self._ensure_table(conn, tabla)
            rows = await conn.fetch(f"""
                SELECT id, user_id, numeros, fecha_guardado, expira
                FROM {tabla}
                WHERE user_id = $1
                  AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
                  AND fecha_guardado >= NOW() - INTERVAL '7 days'
                ORDER BY fecha_guardado DESC
            """, user_id)
            return [dict(r) for r in rows]

    async def delete_jugada(self, tipo: str, jugada_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        tabla = f"jugadas_{tipo}"
        async with pool.acquire() as conn:
            await self._ensure_table(conn, tabla)
            result = await conn.execute(f"""
                DELETE FROM {tabla}
                WHERE id = $1 AND user_id = $2
            """, jugada_id, user_id)
            return result == "DELETE 1"

    async def list_active_lotteries(self, user_id: int) -> List[str]:
        pool = db_connection.get_pool()
        tipos = [
            "mloto", "bloto", "colorloto", "powerball", 
            "lotto_america", "double_play", "millionaire_life", "megamillions"
        ]
        activas = []
        async with pool.acquire() as conn:
            for tipo in tipos:
                tabla = f"jugadas_{tipo}"
                # Verificamos si la tabla existe antes de consultar
                exists_table = await conn.fetchval("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_name = $1
                    );
                """, tabla)
                
                if exists_table:
                    has_rows = await conn.fetchval(f"""
                        SELECT EXISTS (
                            SELECT 1 FROM {tabla} 
                            WHERE user_id = $1 
                              AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
                              AND fecha_guardado >= NOW() - INTERVAL '7 days'
                        )
                    """, user_id)
                    if has_rows:
                        activas.append(tipo)
        return activas


    def get_prediccion_reciente_mloto(self) -> Optional[Tuple[datetime, List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"""
                    SELECT fecha, numeros
                    FROM predicciones_mloto
                    ORDER BY fecha DESC
                    LIMIT 1;
                """)
                row = cur.fetchone()
                return row if row else None
    
    def get_prediccion_reciente_bloto(self) -> Optional[Tuple[datetime, List[int], List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"""
                    SELECT fecha, numeros, balotaroja
                    FROM predicciones_bloto
                    ORDER BY fecha DESC
                    LIMIT 1;
                """)
                row = cur.fetchone()
                return row if row else None

    def get_ultimos_resultados_mloto(self) -> List[Tuple[datetime, List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:              
                cur.execute(f"""
                    SELECT fecha, balota1, balota2, balota3, balota4, balota5
                    FROM resultados_mloto
                    where balota1 <> 0
                    ORDER BY fecha DESC
                    LIMIT 5;
                """)
                rows = cur.fetchall()
                # mapeamos a (fecha, [b1, b2, b3, b4, b5])
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]]) for r in rows]
            
    def get_ultimos_resultados_bloto(self, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                if sorteo:
                    cur.execute("""
                        SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, sorteo
                        FROM resultados_bloto
                        WHERE balota1 <> 0
                        AND LOWER(sorteo) = LOWER(%s)
                        ORDER BY fecha DESC
                        LIMIT 5;
                    """, (sorteo,))
                else:
                    cur.execute("""
                        SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, sorteo
                        FROM resultados_bloto
                        WHERE balota1 <> 0
                        ORDER BY fecha DESC
                        LIMIT 10;
                    """)
                rows = cur.fetchall()
                # mapeamos a (fecha, [b1, b2, b3, b4, b5], [balotaroja], sorteo)
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], [r[6]], r[7] if len(r) > 7 else "Baloto") for r in rows]

    def get_historico_completo_bloto(self, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                if sorteo:
                    cur.execute("""
                        SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, sorteo
                        FROM resultados_bloto
                        WHERE balota1 <> 0
                        AND LOWER(sorteo) = LOWER(%s)
                        ORDER BY fecha DESC;
                    """, (sorteo,))
                else:
                    cur.execute("""
                        SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, sorteo
                        FROM resultados_bloto
                        WHERE balota1 <> 0
                        ORDER BY fecha DESC;
                    """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], [r[6]], r[7] if len(r) > 7 else "Baloto") for r in rows]

    def get_historico_completo_mloto(self) -> List[Tuple[datetime, List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT fecha, balota1, balota2, balota3, balota4, balota5
                    FROM resultados_mloto
                    WHERE balota1 <> 0
                    ORDER BY fecha DESC;
                """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]]) for r in rows]

    def get_predicciones_historico(self, tipo: str, limit: int) -> List[Tuple[datetime, List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"""
                    SELECT fecha, numeros
                    FROM predicciones_{tipo}
                    WHERE fecha >= CURRENT_DATE - INTERVAL '7 days'
                    ORDER BY fecha DESC
                    LIMIT %s;
                """, (limit,))
                rows = cur.fetchall()
                # para predicciones el formato numeros es str o similar en BD
                return [(r[0], r[1]) for r in rows]

    def get_prediccion_generico(self, tabla: str, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int], List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                if fecha:
                    cur.execute(f"""
                        SELECT fecha, numeros, balotaroja
                        FROM {tabla}
                        WHERE fecha <= %s
                        ORDER BY fecha DESC
                        LIMIT 1;
                    """, (fecha,))
                else:
                    cur.execute(f"""
                        SELECT fecha, numeros, balotaroja
                        FROM {tabla}
                        ORDER BY fecha DESC
                        LIMIT 1;
                    """)
                row = cur.fetchone()
                return row if row else None

    def get_ultimos_resultados_generico(self, tabla: str, sorteo_nombre: str) -> List[Tuple[datetime, List[int], List[int], str]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"""
                    SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, sorteo
                    FROM {tabla}
                    WHERE balota1 <> 0
                    ORDER BY fecha DESC
                    LIMIT 5;
                """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], [r[6]], r[7] if len(r) > 7 and r[7] else sorteo_nombre) for r in rows]

    def get_historico_completo_generico(self, tabla: str, sorteo_nombre: str) -> List[Tuple[datetime, List[int], List[int], str]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(f"""
                    SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, sorteo
                    FROM {tabla}
                    WHERE balota1 <> 0
                    ORDER BY fecha DESC;
                """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], [r[6]], r[7] if len(r) > 7 and r[7] else sorteo_nombre) for r in rows]

