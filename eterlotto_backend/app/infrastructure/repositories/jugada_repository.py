import logging
import re
from typing import Optional, Tuple, List, Dict, Any
from datetime import datetime, date
from app.domain.ports import JugadaRepositoryPort
from app.infrastructure import db_connection

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
                CREATE INDEX IF NOT EXISTS idx_jugadas_user_loteria ON jugadas (user_id, loteria_id);
                CREATE INDEX IF NOT EXISTS idx_jugadas_user_route ON jugadas (user_id, loteria_route);
                CREATE INDEX IF NOT EXISTS idx_jugadas_loteria_id ON jugadas (loteria_id);
                CREATE INDEX IF NOT EXISTS idx_jugadas_expira ON jugadas (expira);
            """)
            # Asegurar columnas si no existían
            await conn.execute("""
                ALTER TABLE jugadas ADD COLUMN IF NOT EXISTS loteria_id INTEGER;
                ALTER TABLE jugadas ADD COLUMN IF NOT EXISTS fecha_sorteo DATE;
                ALTER TABLE jugadas ADD COLUMN IF NOT EXISTS loteria_route VARCHAR(50);
            """)
            # Sólo completar loteria_id automáticamente cuando la route es única.
            # Para routes compartidas nunca adivinamos el país.
            await conn.execute("""
                UPDATE jugadas j
                SET loteria_id = l.id
                FROM loterias l
                WHERE j.loteria_id IS NULL
                  AND LOWER(l.route) = LOWER(j.loteria_route)
                  AND 1 = (
                      SELECT COUNT(*)
                      FROM loterias lx
                      WHERE LOWER(lx.route) = LOWER(j.loteria_route)
                  );
            """)
            await conn.execute("""
                DELETE FROM jugadas
                WHERE (expira IS NOT NULL AND expira < CURRENT_TIMESTAMP)
                   OR (fecha_guardado < CURRENT_TIMESTAMP - INTERVAL '7 days' AND (fecha_sorteo IS NULL OR fecha_sorteo < CURRENT_DATE - INTERVAL '7 days'));
            """)
            cls._table_ensured = True
        except Exception as e:
            logging.getLogger(__name__).error(f'Error capturado: {e}')
            pass

    async def _ensure_table(self, conn):
        if not PostgresJugadaRepository._table_ensured:
            await PostgresJugadaRepository.ensure_schema(conn)

    async def _resolve_lottery(self, conn, tipo: str, loteria_id: Optional[int] = None):
        """Resuelve una lotería concreta sin adivinar entre países.

        `loteria_id` es la identidad canónica. `tipo`/route queda como motor
        compartido y sólo se usa como fallback cuando la route identifica una
        única fila del catálogo.
        """
        clean_route = (tipo or "").strip().lower()

        if loteria_id is not None:
            row = await conn.fetchrow("""
                SELECT id, route, nombre, pais_id
                FROM loterias
                WHERE id = $1
                LIMIT 1
            """, int(loteria_id))
            if not row:
                raise ValueError(f"La lotería con id={loteria_id} no existe")

            canonical_route = (row['route'] or '').strip().lower()
            canonical_name = self._normalize_identity(row['nombre'])
            accepted_routes = {
                self._normalize_identity(canonical_route),
                canonical_name,
            }

            if clean_route and canonical_route and self._normalize_identity(clean_route) not in accepted_routes:
                raise ValueError(
                    f"loteria_id={loteria_id} corresponde a route '{canonical_route}', "
                    f"no a '{clean_route}'"
                )
            return row

        if not clean_route:
            return None

        rows = await conn.fetch("""
            SELECT id, route, nombre, pais_id
            FROM loterias
            WHERE LOWER(route) = $1
               OR LOWER(nombre) = $1
               OR REPLACE(LOWER(route), '_', ' ') = $1
               OR REPLACE(LOWER(nombre), ' ', '_') = $1
            ORDER BY id
        """, clean_route)

        if len(rows) > 1:
            raise ValueError(
                f"La route '{clean_route}' pertenece a varias loterías. "
                "Debes enviar loteria_id para identificar el país/lotería exactos."
            )
        return rows[0] if rows else None

    async def create_jugada(
        self,
        tipo: str,
        user_id: int,
        numeros: List[int],
        fecha_sorteo: Optional[date],
        fecha_guardado: datetime,
        expira: datetime,
        loteria_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        loteria_route = (tipo or "").strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            lot_row = await self._resolve_lottery(conn, loteria_route, loteria_id)

            resolved_loteria_id = lot_row['id'] if lot_row else loteria_id
            if lot_row and lot_row['route']:
                loteria_route = lot_row['route'].strip().lower()

            if not loteria_route:
                raise ValueError("No se pudo determinar la route de la lotería")

            row = await conn.fetchrow("""
                INSERT INTO jugadas (user_id, loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id, user_id, loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira
            """, user_id, resolved_loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira)
            d = dict(row)
            if d.get('fecha_sorteo'):
                d['fecha_sorteo'] = str(d['fecha_sorteo'])
            return d

    async def list_jugadas(
        self,
        tipo: str,
        user_id: int,
        fecha: Optional[str] = None,
        loteria_id: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        loteria_route = (tipo or "").strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)

            clean_date = None
            if fecha:
                try:
                    clean_str = fecha.replace('"', '').replace("'", "").strip().split('T')[0]
                    clean_date = datetime.strptime(clean_str, "%Y-%m-%d").date()
                except Exception as e:
                    logging.getLogger(__name__).warning(
                        "Fecha de jugada inválida '%s': %s", fecha, e
                    )

            rows = await conn.fetch("""
                SELECT id, user_id, loteria_id, loteria_route, numeros,
                       COALESCE(fecha_sorteo, fecha_guardado::date) AS fecha_sorteo,
                       fecha_guardado, expira
                FROM jugadas
                WHERE user_id = $1
                  AND (
                        ($2::int IS NOT NULL AND loteria_id = $2)
                        OR
                        ($2::int IS NULL AND ($3 = '' OR LOWER(loteria_route) = $3))
                      )
                  AND (
                        $4::date IS NULL
                        OR fecha_sorteo = $4
                        OR (
                            fecha_sorteo IS NULL
                            AND (
                                fecha_guardado::date = $4
                            )
                        )
                      )
                  AND (
                        $4::date IS NOT NULL
                        OR expira IS NULL
                        OR expira >= CURRENT_TIMESTAMP
                      )
                ORDER BY COALESCE(fecha_sorteo, fecha_guardado::date) DESC, id DESC
            """, user_id, loteria_id, loteria_route, clean_date)

            res = []
            for r in rows:
                d = dict(r)
                if d.get('fecha_sorteo'):
                    d['fecha_sorteo'] = str(d['fecha_sorteo'])
                res.append(d)
            return res

    async def delete_jugada(
        self,
        tipo: str,
        jugada_id: int,
        user_id: int,
        loteria_id: Optional[int] = None,
    ) -> bool:
        pool = db_connection.get_pool()
        loteria_route = (tipo or "").strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            result = await conn.execute("""
                DELETE FROM jugadas
                WHERE id = $1
                  AND user_id = $2
                  AND (
                        ($3::int IS NOT NULL AND loteria_id = $3)
                        OR
                        ($3::int IS NULL AND ($4 = '' OR LOWER(loteria_route) = $4))
                      )
            """, jugada_id, user_id, loteria_id, loteria_route)
            return result == "DELETE 1"

    async def update_jugada(
        self,
        tipo: str,
        jugada_id: int,
        user_id: int,
        numeros: List[int],
        loteria_id: Optional[int] = None,
    ) -> Optional[Dict[str, Any]]:
        pool = db_connection.get_pool()
        loteria_route = (tipo or "").strip().lower()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            numeros_clean = [int(n) for n in numeros]
            row = await conn.fetchrow("""
                UPDATE jugadas
                SET numeros = $1
                WHERE id = $2
                  AND user_id = $3
                  AND (
                        ($4::int IS NOT NULL AND loteria_id = $4)
                        OR
                        ($4::int IS NULL AND ($5 = '' OR LOWER(loteria_route) = $5))
                      )
                RETURNING id, user_id, loteria_id, loteria_route, numeros, fecha_sorteo, fecha_guardado, expira
            """, numeros_clean, jugada_id, user_id, loteria_id, loteria_route)
            if not row:
                return None
            d = dict(row)
            if d.get('fecha_sorteo'):
                d['fecha_sorteo'] = str(d['fecha_sorteo'])
            return d

    async def list_active_lotteries(self, user_id: int) -> List[str]:
        """Compatibilidad: devuelve routes activas, no la identidad canónica."""
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            rows = await conn.fetch("""
                SELECT DISTINCT LOWER(loteria_route) AS route
                FROM jugadas
                WHERE user_id = $1
                  AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
            """, user_id)
            return [r['route'] for r in rows if r['route']]

    async def list_active_lotteries_counts(self, user_id: int) -> Dict[str, int]:
        """Compatibilidad legacy por route. La pantalla nueva usa /mis_loterias_info."""
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            rows = await conn.fetch("""
                SELECT LOWER(loteria_route) AS route, COUNT(*)::int AS count
                FROM jugadas
                WHERE user_id = $1
                  AND (expira IS NULL OR expira >= CURRENT_TIMESTAMP)
                GROUP BY LOWER(loteria_route)
            """, user_id)
            return {r['route']: r['count'] for r in rows if r['route']}

    async def list_active_lotteries_info(self, user_id: int) -> Dict[str, Dict[str, Any]]:
        """Devuelve jugadas agrupadas por loteria_id.

        Las filas legacy sin loteria_id se conservan bajo `route:<route>` para
        no inventar un país cuando una route es compartida.
        """
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_table(conn)
            rows = await conn.fetch("""
                SELECT j.loteria_id,
                       LOWER(j.loteria_route) AS route,
                       COUNT(*)::int AS count,
                       MAX(COALESCE(j.fecha_sorteo, j.fecha_guardado::date)) AS latest_fecha
                FROM jugadas j
                WHERE j.user_id = $1
                  AND (j.expira IS NULL OR j.expira >= CURRENT_TIMESTAMP)
                GROUP BY j.loteria_id, LOWER(j.loteria_route)
                ORDER BY j.loteria_id NULLS LAST, LOWER(j.loteria_route)
            """, user_id)

            result: Dict[str, Dict[str, Any]] = {}
            for r in rows:
                key = str(r['loteria_id']) if r['loteria_id'] is not None else f"route:{r['route']}"
                result[key] = {
                    'loteria_id': r['loteria_id'],
                    'route': r['route'],
                    'count': r['count'],
                    'fecha': str(r['latest_fecha']) if r['latest_fecha'] else None,
                }
            return result
    @staticmethod
    def _normalize_identity(value: Optional[str]) -> str:
        return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", (value or "").strip().lower())).strip("_")

    def _resolve_catalog_identity(self, cur, route: str):
        requested = self._normalize_identity(route)
        if not requested:
            raise ValueError("La route de la lotería está vacía")
        if not re.fullmatch(r"[a-z0-9_]+", requested):
            raise ValueError("Route de lotería inválida")

        cur.execute("""
            SELECT route, nombre
            FROM loterias
            WHERE LOWER(REPLACE(REPLACE(TRIM(route), ' ', '_'), '-', '_')) = %s
               OR LOWER(REPLACE(REPLACE(TRIM(nombre), ' ', '_'), '-', '_')) = %s
            ORDER BY id;
        """, (requested, requested))
        rows = cur.fetchall()

        canonical_route = requested
        display_name = route.replace('_', ' ').strip().title()
        aliases = {requested}
        if rows:
            canonical_route = self._normalize_identity(rows[0][0]) or requested
            display_name = str(rows[0][1] or display_name)
            for row in rows:
                aliases.add(self._normalize_identity(row[0]))
                aliases.add(self._normalize_identity(row[1]))
        aliases.discard("")
        return canonical_route, display_name, sorted(aliases)

    def _resolve_data_table(self, cur, prefix: str, route: str) -> Optional[str]:
        canonical_route, _, aliases = self._resolve_catalog_identity(cur, route)
        cur.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name LIKE %s;
        """, (f"{prefix}_%",))
        available = [row[0].lower() for row in cur.fetchall()]

        candidate_prefixes = [f"{prefix}_{alias}" for alias in aliases]
        candidates = [
            name for name in available
            if any(name == base or re.fullmatch(re.escape(base) + r"\d+", name) for base in candidate_prefixes)
        ]
        if not candidates:
            exact = f"{prefix}_{canonical_route}"
            return exact if exact in available else None

        latest_by_table = []
        for table_name in candidates:
            if not re.fullmatch(r"[a-z0-9_]+", table_name):
                continue
            latest = None
            try:
                cur.execute(f"SELECT MAX(fecha) FROM {table_name};")
                row = cur.fetchone()
                latest = row[0] if row else None
            except Exception:
                try:
                    cur.connection.rollback()
                except Exception:
                    pass
            exact_priority = 0 if table_name == f"{prefix}_{canonical_route}" else 1
            latest_by_table.append((latest is not None, latest, -exact_priority, table_name))

        if not latest_by_table:
            return None
        latest_by_table.sort(reverse=True)
        return latest_by_table[0][3]

    def get_jackpot_reciente(self, route: str) -> Optional[str]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                _, _, aliases = self._resolve_catalog_identity(cur, route)
                cur.execute("""
                    SELECT jackpot
                    FROM loterias_jackpots
                    WHERE LOWER(REPLACE(REPLACE(TRIM(loteria), ' ', '_'), '-', '_')) = ANY(%s)
                    ORDER BY fecha DESC
                    LIMIT 1;
                """, (aliases,))
                row = cur.fetchone()
                return row[0] if row else None

    def get_predicciones_historico(self, route: str, limit: int) -> List[Tuple[datetime, List[int]]]:
        safe_limit = max(1, min(int(limit), 200))
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                _, _, aliases = self._resolve_catalog_identity(cur, route)
                try:
                    cur.execute("""
                        SELECT fecha, numeros
                        FROM predicciones
                        WHERE LOWER(REPLACE(REPLACE(TRIM(loteria_route), ' ', '_'), '-', '_')) = ANY(%s)
                          AND fecha >= CURRENT_DATE - INTERVAL '15 days'
                        ORDER BY fecha DESC
                        LIMIT %s;
                    """, (aliases, safe_limit))
                    rows = cur.fetchall()
                    if rows:
                        return [(r[0], r[1]) for r in rows]
                except Exception as exc:
                    logging.getLogger(__name__).debug("Predicciones globales no disponibles: %s", exc)
                    try:
                        conn.rollback()
                    except Exception:
                        pass

                table_name = self._resolve_data_table(cur, "predicciones", route)
                if not table_name:
                    return []
                try:
                    cur.execute(f"""
                        SELECT fecha, numeros
                        FROM {table_name}
                        WHERE fecha >= CURRENT_DATE - INTERVAL '15 days'
                        ORDER BY fecha DESC
                        LIMIT %s;
                    """, (safe_limit,))
                    return [(r[0], r[1]) for r in cur.fetchall()]
                except Exception as exc:
                    logging.getLogger(__name__).debug("Predicciones por tabla no disponibles: %s", exc)
                    return []

    def get_predicciones_historico_completas(self, route: str, limit: int = 50) -> List[Tuple[datetime, List[int], List[int]]]:
        safe_limit = max(1, min(int(limit), 200))
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                _, _, aliases = self._resolve_catalog_identity(cur, route)
                try:
                    cur.execute("""
                        SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                        FROM predicciones
                        WHERE LOWER(REPLACE(REPLACE(TRIM(loteria_route), ' ', '_'), '-', '_')) = ANY(%s)
                        ORDER BY fecha DESC
                        LIMIT %s;
                    """, (aliases, safe_limit))
                    rows = cur.fetchall()
                    if rows:
                        return [
                            (r[0], list(r[1] or []), list(r[2] or []))
                            for r in rows
                        ]
                except Exception as exc:
                    logging.getLogger(__name__).debug("Histórico global de predicciones no disponible: %s", exc)
                    try:
                        conn.rollback()
                    except Exception:
                        pass

                table_name = self._resolve_data_table(cur, "predicciones", route)
                if not table_name:
                    return []
                try:
                    cur.execute(f"""
                        SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                        FROM {table_name}
                        ORDER BY fecha DESC
                        LIMIT %s;
                    """, (safe_limit,))
                    return [(r[0], list(r[1] or []), list(r[2] or [])) for r in cur.fetchall()]
                except Exception as exc:
                    logging.getLogger(__name__).debug("Histórico específico de predicciones no disponible: %s", exc)
                    return []

    def get_prediccion_generico(self, route: str, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int], List[int]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                _, _, aliases = self._resolve_catalog_identity(cur, route)
                try:
                    if fecha:
                        cur.execute("""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM predicciones
                            WHERE LOWER(REPLACE(REPLACE(TRIM(loteria_route), ' ', '_'), '-', '_')) = ANY(%s)
                              AND fecha <= %s
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """, (aliases, fecha))
                    else:
                        cur.execute("""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM predicciones
                            WHERE LOWER(REPLACE(REPLACE(TRIM(loteria_route), ' ', '_'), '-', '_')) = ANY(%s)
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """, (aliases,))
                    row = cur.fetchone()
                    if row:
                        return row
                except Exception as exc:
                    logging.getLogger(__name__).debug("Predicción global no disponible: %s", exc)
                    try:
                        conn.rollback()
                    except Exception:
                        pass

                table_name = self._resolve_data_table(cur, "predicciones", route)
                if not table_name:
                    return None
                try:
                    if fecha:
                        cur.execute(f"""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM {table_name}
                            WHERE fecha <= %s
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """, (fecha,))
                    else:
                        cur.execute(f"""
                            SELECT fecha, numeros, COALESCE(balotaroja, ARRAY[]::integer[])
                            FROM {table_name}
                            ORDER BY fecha DESC
                            LIMIT 1;
                        """)
                    return cur.fetchone()
                except Exception as exc:
                    logging.getLogger(__name__).debug("Predicción específica no disponible: %s", exc)
                    return None

    def _jackpots_by_date(self, cur, aliases: List[str], draw_names: List[str]) -> Dict[Any, str]:
        all_aliases = {self._normalize_identity(x) for x in aliases + draw_names}
        all_aliases.discard("")
        if not all_aliases:
            return {}
        cur.execute("""
            SELECT fecha, jackpot
            FROM loterias_jackpots
            WHERE LOWER(REPLACE(REPLACE(TRIM(loteria), ' ', '_'), '-', '_')) = ANY(%s)
            ORDER BY fecha DESC;
        """, (sorted(all_aliases),))
        result = {}
        for fecha, jackpot in cur.fetchall():
            if fecha not in result and jackpot:
                result[fecha] = jackpot
        return result

    def _fetch_resultados_generico(self, route: str, limit: Optional[int], sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        with db_connection.get_connection() as conn:
            with conn.cursor() as cur:
                canonical_route, display_name, aliases = self._resolve_catalog_identity(cur, route)
                table_name = self._resolve_data_table(cur, "resultados", canonical_route)
                if not table_name:
                    return []

                cur.execute("""
                    SELECT max_seleccion,
                           max_balotas_rojas,
                           tiene_complementario,
                           tiene_reintegro
                    FROM loterias
                    WHERE LOWER(REPLACE(REPLACE(TRIM(route), ' ', '_'), '-', '_')) = %s
                    ORDER BY id
                    LIMIT 1;
                """, (canonical_route,))
                lot_config = cur.fetchone()
                if not lot_config or lot_config[0] is None:
                    raise ValueError(
                        f"La route '{canonical_route}' no tiene max_seleccion configurado en loterias"
                    )
                max_sel = int(lot_config[0])
                max_rojas_cfg = int(lot_config[1]) if lot_config[1] is not None else None
                tiene_comp_cfg = bool(lot_config[2]) if lot_config[2] is not None else False
                min_special = 0 if bool(lot_config[3]) else 1

                cur.execute("""
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = %s
                    ORDER BY ordinal_position;
                """, (table_name,))
                cols = [r[0].lower() for r in cur.fetchall()]
                if not cols or "fecha" not in cols:
                    return []

                # Formato ancho: balota1..N + especiales opcionales.
                balota_cols = [c for c in cols if c.startswith("balota") and not c.startswith("balotaroja")]
                balota_cols.sort(key=lambda x: int(x.replace("balota", "")) if x.replace("balota", "").isdigit() else 999)

                results = []
                if balota_cols:
                    special_cols = []
                    if max_rojas_cfg is None or max_rojas_cfg > 0:
                        special_cols = [c for c in ("balotaroja", "balotaroja2", "superbalota") if c in cols]

                    select_cols = ["fecha"] + balota_cols + special_cols
                    if "sorteo" in cols:
                        select_cols.append("sorteo")
                    where = ["fecha <= CURRENT_DATE", f"{balota_cols[0]} IS NOT NULL", f"{balota_cols[0]} > 0"]
                    params = []
                    if sorteo and "sorteo" in cols:
                        where.append("LOWER(sorteo) = LOWER(%s)")
                        params.append(sorteo)
                    limit_sql = ""
                    if limit is not None:
                        limit_sql = " LIMIT %s"
                        params.append(max(1, int(limit)))
                    cur.execute(
                        f"SELECT {', '.join(select_cols)} FROM {table_name} WHERE {' AND '.join(where)} ORDER BY fecha DESC{limit_sql};",
                        tuple(params),
                    )
                    rows = cur.fetchall()
                    main_count = len(balota_cols)
                    special_count = len(special_cols)
                    for row in rows:
                        fecha = row[0]
                        numeros = [n for n in row[1:1 + main_count] if n is not None and n >= 0]
                        if max_sel is not None:
                            numeros = numeros[: max_sel + (1 if tiene_comp_cfg else 0)]
                        especiales = [n for n in row[1 + main_count:1 + main_count + special_count] if n is not None and n >= min_special]
                        if max_rojas_cfg is not None:
                            if max_rojas_cfg > 0:
                                especiales = especiales[:max_rojas_cfg]
                            else:
                                especiales = []
                        sorteo_name = display_name
                        if "sorteo" in cols:
                            sorteo_name = row[1 + main_count + special_count] or display_name
                        results.append((fecha, numeros, especiales, sorteo_name, None))

                # Formato largo: una fila por número/color. Se detecta por esquema, no por nombre de lotería.
                elif "numero" in cols:
                    select_cols = ["fecha", "numero"]
                    if "color" in cols:
                        select_cols.append("color")
                    if "sorteo" in cols:
                        select_cols.append("sorteo")
                    where = ["fecha <= CURRENT_DATE", "numero IS NOT NULL", "numero > 0"]
                    params = []
                    if sorteo and "sorteo" in cols:
                        where.append("LOWER(sorteo) = LOWER(%s)")
                        params.append(sorteo)
                    cur.execute(
                        f"SELECT {', '.join(select_cols)} FROM {table_name} WHERE {' AND '.join(where)} ORDER BY fecha DESC;",
                        tuple(params),
                    )
                    grouped = {}
                    for row in cur.fetchall():
                        fecha = row[0]
                        numero = row[1]
                        idx = 2
                        if "color" in cols:
                            idx += 1
                        sorteo_name = row[idx] if "sorteo" in cols else display_name
                        key = (fecha, sorteo_name or display_name)
                        grouped.setdefault(key, []).append(int(numero))
                    for (fecha, sorteo_name), numeros in grouped.items():
                        results.append((fecha, numeros[:max_sel] if max_sel else numeros, [], sorteo_name, None))
                    results.sort(key=lambda item: item[0], reverse=True)
                    if limit is not None:
                        results = results[: max(1, int(limit))]
                else:
                    return []

                draw_names = [str(r[3]) for r in results if r[3]]
                jackpot_map = self._jackpots_by_date(cur, aliases, draw_names)
                return [(r[0], r[1], r[2], r[3], jackpot_map.get(r[0])) for r in results]

    def get_ultimos_resultados_generico(self, route: str, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        # Se consultan hasta 40 filas porque una route puede agrupar varios sorteos.
        return self._fetch_resultados_generico(route, limit=40, sorteo=sorteo)

    def get_ultimos50_resultados_generico(self, route: str, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        return self._fetch_resultados_generico(route, limit=50, sorteo=sorteo)

    def get_historico_completo_generico(self, route: str, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        return self._fetch_resultados_generico(route, limit=None, sorteo=sorteo)
