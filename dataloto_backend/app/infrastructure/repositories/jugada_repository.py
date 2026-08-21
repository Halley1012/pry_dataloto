from typing import Optional, Tuple, List, Dict, Any
from datetime import datetime, date
from app.domain.ports import JugadaRepositoryPort
from app.infrastructure import db_connection
from app.core.cache import cached

class PostgresJugadaRepository(JugadaRepositoryPort):
    _table_ensured: bool = False

    @classmethod
    async def ensure_schema(cls, conn):
        if cls._table_ensured:
            return
        try:
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS jugadas (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    loteria_id INTEGER,
                    loteria_route VARCHAR(50) NOT NULL,
                    numeros INTEGER[] NOT NULL,
                    fecha_sorteo DATE,
                    fecha_guardado TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    expira TIMESTAMP WITH TIME ZONE
                );
                CREATE INDEX IF NOT EXISTS idx_jugadas_user_loteria ON jugadas (user_id, loteria_route);
                CREATE INDEX IF NOT EXISTS idx_jugadas_loteria_id ON jugadas (loteria_id);
                CREATE INDEX IF NOT EXISTS idx_jugadas_expira ON jugadas (expira);
            """)
            # Asegurar columnas si no existían
            await conn.execute("""
                ALTER TABLE jugadas ADD COLUMN IF NOT EXISTS loteria_id INTEGER;
                ALTER TABLE jugadas ADD COLUMN IF NOT EXISTS fecha_sorteo DATE;
                ALTER TABLE jugadas ADD COLUMN IF NOT EXISTS loteria_route VARCHAR(50);
            """)
            await conn.execute("""
                DELETE FROM jugadas
                WHERE (expira IS NOT NULL AND expira < CURRENT_TIMESTAMP)
                   OR (fecha_guardado < CURRENT_TIMESTAMP - INTERVAL '7 days' AND (fecha_sorteo IS NULL OR fecha_sorteo < CURRENT_DATE - INTERVAL '7 days'));
            """)
            cls._table_ensured = True
        except Exception:
            pass

    async def _ensure_table(self, conn):
        if not PostgresJugadaRepository._table_ensured:
            await PostgresJugadaRepository.ensure_schema(conn)

    async def create_jugada(self, tipo: str, user_id: int, numeros: List[int], fecha_sorteo: Optional[date], fecha_guardado: datetime, expira: datetime) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        loteria_route = tipo.strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            # Buscar el loteria_id numérico en la tabla loterias
            lot_row = await conn.fetchrow("""
                SELECT id, route 
                FROM loterias 
                WHERE LOWER(route) = $1 
                   OR LOWER(nombre) = $1
                   OR REPLACE(LOWER(route), '_', ' ') = $1
                   OR REPLACE(LOWER(nombre), ' ', '_') = $1
                LIMIT 1;
            """, loteria_route)
            
            loteria_id = lot_row['id'] if lot_row else None
            if lot_row and lot_row['route']:
                loteria_route = lot_row['route'].lower()

            row = await conn.fetchrow("""
                INSERT INTO jugadas (user_id, loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id, user_id, loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira
            """, user_id, loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira)
            d = dict(row)
            if d.get('fecha_sorteo'):
                d['fecha_sorteo'] = str(d['fecha_sorteo'])
            return d

    async def list_jugadas(self, tipo: str, user_id: int, fecha: Optional[str] = None) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        loteria_route = tipo.strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            if fecha:
                try:
                    clean_str = fecha.replace('"', '').replace("'", "").strip().split('T')[0]
                    clean_date = datetime.strptime(clean_str, "%Y-%m-%d").date()
                    rows = await conn.fetch("""
                        SELECT id, user_id, loteria_id, loteria_route, numeros, 
                               COALESCE(fecha_sorteo, fecha_guardado::date) AS fecha_sorteo,
                               fecha_guardado, expira
                        FROM jugadas
                        WHERE user_id = $1
                          AND ($2 = '' OR LOWER(loteria_route) = $2)
                          AND (fecha_sorteo = $3 OR (fecha_sorteo IS NULL AND (fecha_guardado::date = $3 OR (fecha_guardado AT TIME ZONE 'America/Bogota')::date = $3)))
                        ORDER BY COALESCE(fecha_sorteo, fecha_guardado::date) DESC, id DESC
                    """, user_id, loteria_route, clean_date)
                except Exception:
                    rows = await conn.fetch("""
                        SELECT id, user_id, loteria_id, loteria_route, numeros, 
                               COALESCE(fecha_sorteo, fecha_guardado::date) AS fecha_sorteo,
                               fecha_guardado, expira
                        FROM jugadas
                        WHERE user_id = $1
                          AND ($2 = '' OR LOWER(loteria_route) = $2)
                          AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
                        ORDER BY COALESCE(fecha_sorteo, fecha_guardado::date) DESC, id DESC
                    """, user_id, loteria_route)
            else:
                rows = await conn.fetch("""
                    SELECT id, user_id, loteria_id, loteria_route, numeros, 
                           COALESCE(fecha_sorteo, fecha_guardado::date) AS fecha_sorteo,
                           fecha_guardado, expira
                    FROM jugadas
                    WHERE user_id = $1
                      AND ($2 = '' OR LOWER(loteria_route) = $2)
                      AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
                    ORDER BY COALESCE(fecha_sorteo, fecha_guardado::date) DESC, id DESC
                """, user_id, loteria_route)
            
            res = []
            for r in rows:
                d = dict(r)
                if d.get('fecha_sorteo'):
                    d['fecha_sorteo'] = str(d['fecha_sorteo'])
                res.append(d)
            return res

    async def delete_jugada(self, tipo: str, jugada_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        loteria_route = tipo.strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            result = await conn.execute("""
                DELETE FROM jugadas
                WHERE id = $1 AND user_id = $2 AND ($3 = '' OR LOWER(loteria_route) = $3)
            """, jugada_id, user_id, loteria_route)
            return result == "DELETE 1"

    async def list_active_lotteries(self, user_id: int) -> List[str]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            rows = await conn.fetch("""
                SELECT DISTINCT LOWER(loteria_route) AS route
                FROM jugadas
                WHERE user_id = $1
                  AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
                  AND fecha_guardado >= NOW() - INTERVAL '7 days'
            """, user_id)
            return [r['route'] for r in rows if r['route']]


    @cached(ttl=300)
    def get_prediccion_reciente_mloto(self, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int]]]:
        row = self.get_prediccion_generico("predicciones_mloto", fecha)
        if row:
            return (row[0], row[1])
        return None
    
    @cached(ttl=300)
    def get_prediccion_reciente_bloto(self, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int], List[int]]]:
        return self.get_prediccion_generico("predicciones_bloto", fecha)

    @cached(ttl=300)
    def get_jackpot_reciente(self, loteria: str) -> Optional[str]:
        clean = loteria.strip().lower()
        clean_spaces = clean.replace('_', ' ')
        clean_under = clean.replace(' ', '_')
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT jackpot
                    FROM loterias_jackpots
                    WHERE LOWER(loteria) = %s 
                       OR LOWER(loteria) = %s
                       OR LOWER(loteria) = %s
                       OR LOWER(loteria) LIKE %s
                    ORDER BY fecha DESC
                    LIMIT 1;
                """, (clean, clean_spaces, clean_under, f"%{clean}%"))
                row = cur.fetchone()
                return row[0] if row else None

    @cached(ttl=300)
    def get_ultimos_resultados_mloto(self) -> List[Tuple[datetime, List[int], Optional[str]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:              
                cur.execute("""
                    SELECT r.fecha, r.balota1, r.balota2, r.balota3, r.balota4, r.balota5, j.jackpot
                    FROM resultados_mloto r
                    LEFT JOIN loterias_jackpots j ON j.loteria = 'miloto' AND j.fecha = r.fecha
                    WHERE r.balota1 <> 0
                    ORDER BY r.fecha DESC
                    LIMIT 5;
                """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], r[6]) for r in rows]
            
    @cached(ttl=300)
    def get_ultimos_resultados_bloto(self, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                if sorteo:
                    cur.execute("""
                        SELECT r.fecha, r.balota1, r.balota2, r.balota3, r.balota4, r.balota5, r.balotaroja, r.sorteo, j.jackpot
                        FROM resultados_bloto r
                        LEFT JOIN loterias_jackpots j ON j.loteria = LOWER(r.sorteo) AND j.fecha = r.fecha
                        WHERE r.balota1 <> 0
                        AND LOWER(r.sorteo) = LOWER(%s)
                        ORDER BY r.fecha DESC
                        LIMIT 5;
                    """, (sorteo,))
                else:
                    cur.execute("""
                        SELECT r.fecha, r.balota1, r.balota2, r.balota3, r.balota4, r.balota5, r.balotaroja, r.sorteo, j.jackpot
                        FROM resultados_bloto r
                        LEFT JOIN loterias_jackpots j ON j.loteria = LOWER(r.sorteo) AND j.fecha = r.fecha
                        WHERE r.balota1 <> 0
                        ORDER BY r.fecha DESC
                        LIMIT 10;
                    """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], [r[6]], r[7] if len(r) > 7 and r[7] else "Baloto", r[8]) for r in rows]

    @cached(ttl=600)
    def get_historico_completo_bloto(self, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                if sorteo:
                    cur.execute("""
                        SELECT r.fecha, r.balota1, r.balota2, r.balota3, r.balota4, r.balota5, r.balotaroja, r.sorteo, j.jackpot
                        FROM resultados_bloto r
                        LEFT JOIN loterias_jackpots j ON j.loteria = LOWER(r.sorteo) AND j.fecha = r.fecha
                        WHERE r.balota1 <> 0
                        AND LOWER(r.sorteo) = LOWER(%s)
                        ORDER BY r.fecha DESC;
                    """, (sorteo,))
                else:
                    cur.execute("""
                        SELECT r.fecha, r.balota1, r.balota2, r.balota3, r.balota4, r.balota5, r.balotaroja, r.sorteo, j.jackpot
                        FROM resultados_bloto r
                        LEFT JOIN loterias_jackpots j ON j.loteria = LOWER(r.sorteo) AND j.fecha = r.fecha
                        WHERE r.balota1 <> 0
                        ORDER BY r.fecha DESC;
                    """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], [r[6]], r[7] if len(r) > 7 and r[7] else "Baloto", r[8]) for r in rows]

    @cached(ttl=600)
    def get_historico_completo_mloto(self) -> List[Tuple[datetime, List[int], Optional[str]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT r.fecha, r.balota1, r.balota2, r.balota3, r.balota4, r.balota5, j.jackpot
                    FROM resultados_mloto r
                    LEFT JOIN loterias_jackpots j ON j.loteria = 'miloto' AND j.fecha = r.fecha
                    WHERE r.balota1 <> 0
                    ORDER BY r.fecha DESC;
                """)
                rows = cur.fetchall()
                return [(r[0], [r[1], r[2], r[3], r[4], r[5]], r[6]) for r in rows]

    @cached(ttl=300)
    def get_predicciones_historico(self, tipo: str, limit: int) -> List[Tuple[datetime, List[int]]]:
        clean_tipo = tipo.strip().lower()
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                try:
                    cur.execute("""
                        SELECT fecha, numeros
                        FROM predicciones
                        WHERE LOWER(loteria_route) = %s
                          AND fecha >= CURRENT_DATE - INTERVAL '15 days'
                        ORDER BY fecha DESC
                        LIMIT %s;
                    """, (clean_tipo, limit))
                    rows = cur.fetchall()
                    if rows:
                        return [(r[0], r[1]) for r in rows]
                except Exception:
                    pass

                try:
                    cur.execute(f"""
                        SELECT fecha, numeros
                        FROM predicciones_{clean_tipo}
                        WHERE fecha >= CURRENT_DATE - INTERVAL '15 days'
                        ORDER BY fecha DESC
                        LIMIT %s;
                    """, (limit,))
                    rows = cur.fetchall()
                    return [(r[0], r[1]) for r in rows]
                except Exception:
                    return []

    @cached(ttl=300)
    def get_prediccion_generico(self, tabla: str, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int], List[int]]]:
        clean_tipo = tabla.replace("predicciones_", "").strip().lower()
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                try:
                    if fecha:
                        cur.execute("""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM predicciones
                            WHERE LOWER(loteria_route) = %s AND fecha <= %s
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """, (clean_tipo, fecha))
                    else:
                        cur.execute("""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM predicciones
                            WHERE LOWER(loteria_route) = %s
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """, (clean_tipo,))
                    row = cur.fetchone()
                    if row:
                        return row
                except Exception:
                    pass

                try:
                    if fecha:
                        cur.execute(f"""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM {tabla}
                            WHERE fecha <= %s
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """, (fecha,))
                    else:
                        cur.execute(f"""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM {tabla}
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """)
                    row = cur.fetchone()
                    return row if row else None
                except Exception:
                    return None

    @cached(ttl=300)
    def get_ultimos_resultados_generico(self, tabla: str, sorteo_nombre: str) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        loteria_nombre = tabla.replace("resultados_", "")
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = %s
                    ORDER BY ordinal_position;
                """, (tabla,))
                cols = [r[0].lower() for r in cur.fetchall()]
                if not cols:
                    return []

                balota_cols = [c for c in cols if c.startswith("balota") and not c.startswith("balotaroja")]
                balota_cols.sort(key=lambda x: int(x.replace("balota", "")) if x.replace("balota", "").isdigit() else 99)

                roja_cols = [c for c in ["balotaroja", "balotaroja2", "superbalota"] if c in cols]
                sorteo_col = "r.sorteo" if "sorteo" in cols else f"'{sorteo_nombre}'"

                first_balota = balota_cols[0] if balota_cols else "fecha"
                select_cols = ["r.fecha"] + [f"r.{c}" for c in balota_cols] + [f"r.{c}" for c in roja_cols] + [sorteo_col, "j.jackpot"]

                query = f"""
                    SELECT {', '.join(select_cols)}
                    FROM {tabla} r
                    LEFT JOIN loterias_jackpots j ON j.loteria = '{loteria_nombre}' AND j.fecha = r.fecha
                    WHERE r.{first_balota} <> 0
                    ORDER BY r.fecha DESC
                    LIMIT 5;
                """
                cur.execute(query)
                rows = cur.fetchall()

                num_balotas = len(balota_cols)
                num_rojas = len(roja_cols)

                results = []
                for r in rows:
                    fecha = r[0]
                    numeros = [r[i] for i in range(1, 1 + num_balotas) if r[i] is not None and r[i] > 0]
                    balotas_rojas = [r[i] for i in range(1 + num_balotas, 1 + num_balotas + num_rojas) if r[i] is not None and r[i] >= 0]
                    sorteo = r[1 + num_balotas + num_rojas] or sorteo_nombre
                    jackpot = r[1 + num_balotas + num_rojas + 1]
                    results.append((fecha, numeros, balotas_rojas, sorteo, jackpot))

                return results

    @cached(ttl=600)
    def get_historico_completo_generico(self, tabla: str, sorteo_nombre: str) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        loteria_nombre = tabla.replace("resultados_", "")
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = %s
                    ORDER BY ordinal_position;
                """, (tabla,))
                cols = [r[0].lower() for r in cur.fetchall()]
                if not cols:
                    return []

                balota_cols = [c for c in cols if c.startswith("balota") and not c.startswith("balotaroja")]
                balota_cols.sort(key=lambda x: int(x.replace("balota", "")) if x.replace("balota", "").isdigit() else 99)

                roja_cols = [c for c in ["balotaroja", "balotaroja2", "superbalota"] if c in cols]
                sorteo_col = "r.sorteo" if "sorteo" in cols else f"'{sorteo_nombre}'"

                first_balota = balota_cols[0] if balota_cols else "fecha"
                select_cols = ["r.fecha"] + [f"r.{c}" for c in balota_cols] + [f"r.{c}" for c in roja_cols] + [sorteo_col, "j.jackpot"]

                query = f"""
                    SELECT {', '.join(select_cols)}
                    FROM {tabla} r
                    LEFT JOIN loterias_jackpots j ON j.loteria = '{loteria_nombre}' AND j.fecha = r.fecha
                    WHERE r.{first_balota} <> 0
                    ORDER BY r.fecha DESC;
                """
                cur.execute(query)
                rows = cur.fetchall()

                num_balotas = len(balota_cols)
                num_rojas = len(roja_cols)

                results = []
                for r in rows:
                    fecha = r[0]
                    numeros = [r[i] for i in range(1, 1 + num_balotas) if r[i] is not None and r[i] > 0]
                    balotas_rojas = [r[i] for i in range(1 + num_balotas, 1 + num_balotas + num_rojas) if r[i] is not None and r[i] >= 0]
                    sorteo = r[1 + num_balotas + num_rojas] or sorteo_nombre
                    jackpot = r[1 + num_balotas + num_rojas + 1]
                    results.append((fecha, numeros, balotas_rojas, sorteo, jackpot))

                return results

