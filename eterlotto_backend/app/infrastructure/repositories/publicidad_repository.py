import logging
import re
import psycopg2
import psycopg2.extras
from psycopg2 import sql as pg_sql
from typing import List, Optional, Tuple, Dict, Any
from app.domain.ports import PublicidadRepositoryPort
from app.infrastructure import db_connection

logger = logging.getLogger(__name__)

class PostgresPublicidadRepository(PublicidadRepositoryPort):
    _engagement_schema_ensured: bool = False

    @classmethod
    async def _ensure_engagement_schema(cls, conn):
        if cls._engagement_schema_ensured:
            return
        await conn.execute("""
            ALTER TABLE publicidad
                ADD COLUMN IF NOT EXISTS about_us TEXT,
                ADD COLUMN IF NOT EXISTS galeria_urls TEXT[] DEFAULT ARRAY[]::TEXT[];

            CREATE TABLE IF NOT EXISTS publicidad_likes (
                id BIGSERIAL PRIMARY KEY,
                publicidad_id INTEGER NOT NULL REFERENCES publicidad(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (publicidad_id, user_id)
            );

            CREATE INDEX IF NOT EXISTS idx_publicidad_likes_publicidad
                ON publicidad_likes(publicidad_id);
            CREATE INDEX IF NOT EXISTS idx_publicidad_likes_user
                ON publicidad_likes(user_id);
        """)
        cls._engagement_schema_ensured = True

    @staticmethod
    def _normalize_identity(value: Optional[str]) -> str:
        return re.sub(
            r"_+",
            "_",
            re.sub(r"[^a-z0-9]+", "_", (value or "").strip().lower()),
        ).strip("_")

    def _resolve_result_table(
        self,
        cur,
        existing_tables: set[str],
        route: str,
        nombre: str,
    ) -> Optional[str]:
        aliases = {
            self._normalize_identity(route),
            self._normalize_identity(nombre),
        }
        aliases.discard("")
        if not aliases:
            return None

        bases = [f"resultados_{alias}" for alias in aliases]
        candidates = [
            table
            for table in existing_tables
            if any(
                table == base or re.fullmatch(re.escape(base) + r"\d+", table)
                for base in bases
            )
        ]
        if not candidates:
            return None

        ranked = []
        for table in candidates:
            latest = None
            try:
                cur.execute(f"SELECT MAX(fecha) AS max_fecha FROM {table}")
                row = cur.fetchone()
                if row:
                    latest = row.get("max_fecha") if isinstance(row, dict) else row[0]
            except Exception:
                try:
                    cur.connection.rollback()
                except Exception:
                    pass
            exact = table == f"resultados_{self._normalize_identity(route)}"
            ranked.append((latest is not None, latest, exact, table))

        ranked.sort(reverse=True)
        return ranked[0][3] if ranked else None

    def _get_result_dates(self, cur, table: str) -> tuple[Optional[str], Optional[str]]:
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position
            """,
            (table,),
        )
        cols = [
            (row.get("column_name") if isinstance(row, dict) else row[0]).lower()
            for row in cur.fetchall()
        ]
        if "fecha" not in cols:
            return None, None

        marker_col = None
        if "numero" in cols:
            marker_col = "numero"
        else:
            main_cols = [
                c
                for c in cols
                if re.fullmatch(r"balota\d+", c)
            ]
            main_cols.sort(
                key=lambda c: int(c.replace("balota", ""))
            )
            if main_cols:
                marker_col = main_cols[0]

        if marker_col is None:
            return None, None

        cur.execute(
            f"""
            SELECT
                MAX(fecha) FILTER (WHERE {marker_col} = 0) AS proximo_sorteo,
                MAX(fecha) FILTER (WHERE {marker_col} > 0) AS ultimo_sorteo
            FROM {table}
            """
        )
        row = cur.fetchone()
        if not row:
            return None, None
        proximo = row.get("proximo_sorteo") if isinstance(row, dict) else row[0]
        ultimo = row.get("ultimo_sorteo") if isinstance(row, dict) else row[1]
        return (str(proximo) if proximo else None, str(ultimo) if ultimo else None)

    async def create_publicidad(self, user_id: int, imagen_url: str, link: str, categoria_id: int, ciudad_id: int, departamento_id: int) -> Dict[str, Any]:
        # En la implementación original se recibe un dict complejo con múltiples campos.
        # Pasaremos esos datos directamente en el caso de uso, pero este método general
        # puede guardar los campos básicos. Para mantener 100% de compatibilidad, 
        # definiremos un método más genérico o que reciba los datos mapeados.
        pass

    async def create_publicidad_full(self, user_id: int, data: Dict[str, Any]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_engagement_schema(conn)
            galeria_urls = [
                str(url).strip()
                for url in (data.get("galeria_urls") or [])
                if str(url).strip()
            ]
            await conn.execute("""
                INSERT INTO publicidad (
                    usuario_id, categoria_id, pais_id, departamento_id, ciudad_id,
                    titulo, descripcion, imagen_url, telefono,
                    facebook_url, instagram_url, whatsapp_url, tiktok_url, pagina_url,
                    direccion, about_us, galeria_urls,
                    es_24_7, hora_apertura, hora_cierre, dias_atencion, estado_texto,
                    fecha_inicio, fecha_fin, estado, aprobado, pago_confirmado
                )
                VALUES (
                    $1, $2, $3, $4, $5,
                    $6, $7, $8, $9,
                    $10, $11, $12, $13, $14,
                    $15, $16, $17,
                    $18, $19, $20, $21, $22,
                    CURRENT_DATE, CURRENT_DATE + INTERVAL '15 days',
                    TRUE, FALSE, FALSE
                )
            """,
            user_id,
            data.get("categoria_id"),
            data.get("pais_id"),
            data.get("departamento_id"),
            data.get("ciudad_id"),
            data.get("titulo"),
            data.get("descripcion"),
            data.get("imagen_url"),
            data.get("telefono"),
            data.get("facebook_url"),
            data.get("instagram_url"),
            data.get("whatsapp_url"),
            data.get("tiktok_url"),
            data.get("pagina_url"),
            data.get("direccion"),
            data.get("about_us"),
            galeria_urls,
            bool(data.get("es_24_7", True)),
            data.get("hora_apertura", "00:00"),
            data.get("hora_cierre", "23:59"),
            data.get("dias_atencion", "Todos los días"),
            data.get("estado_texto", "Abierto 24/7")
            )
            return {"success": True, "message": "Anuncio creado exitosamente. Pendiente de aprobación."}

    async def list_publicidad_aprobada(self, categoria_id: Optional[int], departamento_id: Optional[int], ciudad_id: Optional[int]) -> List[Dict[str, Any]]:
        # Este método no se usa directamente tal cual, sino el dinámico de listar_publicidad con filtros
        pass

    async def list_publicidad_dinamica(self, filters: Dict[str, Any], limit: int, offset: int) -> Tuple[List[Dict[str, Any]], int]:
        pool = db_connection.get_pool()
        user_id = filters.get("user_id")
        user_id_sql = int(user_id) if user_id is not None else None

        if user_id_sql is not None:
            user_fav_sql = (
                "COALESCE((SELECT TRUE FROM publicidad_likes pl "
                f"WHERE pl.publicidad_id = p.id AND pl.user_id = {user_id_sql} LIMIT 1), FALSE)"
            )
            user_rating_sql = (
                "COALESCE((SELECT pc.estrellas FROM publicidad_calificaciones pc "
                f"WHERE pc.publicidad_id = p.id AND pc.user_id = {user_id_sql} LIMIT 1), 0)"
            )
        else:
            user_fav_sql = "FALSE"
            user_rating_sql = "0"

        base_query = f"""
            SELECT
                p.*,
                pa.nombre AS pais_nombre,
                d.nombre AS departamento_nombre,
                c.nombre AS categoria_nombre,
                ci.nombre AS ciudad_nombre,
                COALESCE((SELECT COUNT(*) FROM publicidad_likes pl WHERE pl.publicidad_id = p.id), 0) AS total_likes,
                COALESCE((SELECT AVG(pc.estrellas) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0.0) AS promedio_estrellas,
                COALESCE((SELECT COUNT(*) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0) AS total_calificaciones,
                (
                    COALESCE((SELECT AVG(pc.estrellas) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0.0) >= 4.5
                    AND COALESCE((SELECT COUNT(*) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0) >= 3
                ) AS is_destacado,
                {user_fav_sql} AS is_favorite,
                {user_rating_sql} AS user_rating
            FROM publicidad p
            LEFT JOIN paises pa ON p.pais_id = pa.id
            LEFT JOIN departamentos d ON p.departamento_id = d.id
            LEFT JOIN categorias c ON p.categoria_id = c.id
            LEFT JOIN ciudades ci ON p.ciudad_id = ci.id
            WHERE p.estado = TRUE
              AND p.aprobado = FALSE
              AND (p.fecha_fin IS NULL OR p.fecha_fin >= CURRENT_DATE)
        """
        params = []
        conditions = []

        if filters.get("pais_id"):
            conditions.append(f"p.pais_id = ${len(params) + 1}")
            params.append(filters["pais_id"])

        if filters.get("departamento_id"):
            conditions.append(f"p.departamento_id = ${len(params) + 1}")
            params.append(filters["departamento_id"])

        if filters.get("ciudad_id"):
            conditions.append(f"p.ciudad_id = ${len(params) + 1}")
            params.append(filters["ciudad_id"])

        if filters.get("categoria_id"):
            conditions.append(f"p.categoria_id = ${len(params) + 1}")
            params.append(filters["categoria_id"])

        if filters.get("titulo") and filters["titulo"].strip():
            conditions.append(f"LOWER(p.titulo) ILIKE LOWER(${len(params) + 1})")
            params.append(f"%{filters['titulo']}%")

        full_query = base_query
        if conditions:
            full_query += " AND " + " AND ".join(conditions)

        full_query += f" ORDER BY p.fecha_creacion DESC NULLS LAST LIMIT ${len(params) + 1} OFFSET ${len(params) + 2}"

        count_params = list(params)
        params.extend([limit, offset])

        async with pool.acquire() as conn:
            await self._ensure_engagement_schema(conn)
            rows = await conn.fetch(full_query, *params)
            data = [dict(row) for row in rows]

            simplified_count_query = """
                SELECT COUNT(*)
                FROM publicidad p
                WHERE p.estado = TRUE
                  AND p.aprobado = FALSE
                  AND (p.fecha_fin IS NULL OR p.fecha_fin >= CURRENT_DATE)
            """
            if conditions:
                simplified_count_query += " AND " + " AND ".join(conditions)

            total = await conn.fetchval(simplified_count_query, *count_params) or 0
            return data, total

    async def list_all_publicidades(self) -> List[Dict[str, Any]]:
        pass

    async def list_my_publicidades(self, user_id: int) -> List[Dict[str, Any]]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_engagement_schema(conn)
            query = """
                SELECT
                    p.*,
                    c.nombre AS categoria_nombre,
                    ci.nombre AS ciudad_nombre,
                    d.nombre AS departamento_nombre,
                    COALESCE((SELECT COUNT(*) FROM publicidad_likes pl WHERE pl.publicidad_id = p.id), 0) AS total_likes,
                    COALESCE((SELECT AVG(pc.estrellas) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0.0) AS promedio_estrellas,
                    COALESCE((SELECT COUNT(*) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0) AS total_calificaciones,
                    (
                        COALESCE((SELECT AVG(pc.estrellas) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0.0) >= 4.5
                        AND COALESCE((SELECT COUNT(*) FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id), 0) >= 3
                    ) AS is_destacado,
                    COALESCE((SELECT TRUE FROM publicidad_likes pl WHERE pl.publicidad_id = p.id AND pl.user_id = $1 LIMIT 1), FALSE) AS is_favorite,
                    COALESCE((SELECT pc.estrellas FROM publicidad_calificaciones pc WHERE pc.publicidad_id = p.id AND pc.user_id = $1 LIMIT 1), 0) AS user_rating
                FROM publicidad p
                LEFT JOIN categorias c ON p.categoria_id = c.id
                LEFT JOIN ciudades ci ON p.ciudad_id = ci.id
                LEFT JOIN departamentos d ON p.departamento_id = d.id
                WHERE p.usuario_id = $1
                ORDER BY p.id DESC
            """
            rows = await conn.fetch(query, user_id)
            return [dict(r) for r in rows]

    async def update_publicidad(self, publicidad_id: int, user_id: int, imagen_url: Optional[str], link: Optional[str], categoria_id: Optional[int], ciudad_id: Optional[int], departamento_id: Optional[int]) -> Optional[Dict[str, Any]]:
        pass

    async def update_publicidad_full(self, publicidad_id: int, user_id: int, data: Dict[str, Any]) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_engagement_schema(conn)
            existe = await conn.fetchrow(
                "SELECT 1 FROM publicidad WHERE id = $1 AND usuario_id = $2",
                publicidad_id,
                user_id,
            )
            if not existe:
                return False

            galeria_urls = [
                str(url).strip()
                for url in (data.get("galeria_urls") or [])
                if str(url).strip()
            ]

            query = """
                UPDATE publicidad SET
                    titulo = $1,
                    descripcion = $2,
                    direccion = $3,
                    pais_id = $4,
                    departamento_id = $5,
                    ciudad_id = COALESCE($6, ciudad_id),
                    categoria_id = $7,
                    imagen_url = $8,
                    telefono = $9,
                    facebook_url = COALESCE($10, facebook_url),
                    instagram_url = COALESCE($11, instagram_url),
                    whatsapp_url = COALESCE($12, whatsapp_url),
                    tiktok_url = COALESCE($13, tiktok_url),
                    pagina_url = COALESCE($14, pagina_url),
                    es_24_7 = COALESCE($15, es_24_7),
                    hora_apertura = COALESCE($16, hora_apertura),
                    hora_cierre = COALESCE($17, hora_cierre),
                    dias_atencion = COALESCE($18, dias_atencion),
                    estado_texto = COALESCE($19, estado_texto),
                    about_us = $20,
                    galeria_urls = $21,
                    fecha_fin = CASE
                        WHEN pago_confirmado = FALSE THEN CURRENT_DATE + INTERVAL '15 days'
                        ELSE fecha_fin
                    END
                WHERE id = $22
            """
            await conn.execute(
                query,
                data.get("titulo"),
                data.get("descripcion"),
                data.get("direccion"),
                data.get("pais_id"),
                data.get("departamento_id"),
                data.get("ciudad_id"),
                data.get("categoria_id"),
                data.get("imagen_url"),
                data.get("telefono"),
                data.get("facebook_url"),
                data.get("instagram_url"),
                data.get("whatsapp_url"),
                data.get("tiktok_url"),
                data.get("pagina_url"),
                data.get("es_24_7"),
                data.get("hora_apertura"),
                data.get("hora_cierre"),
                data.get("dias_atencion"),
                data.get("estado_texto"),
                data.get("about_us"),
                galeria_urls,
                publicidad_id,
            )
            return True

    async def delete_publicidad(self, publicidad_id: int) -> bool:
        pass

    async def delete_publicidad_by_user(self, publicidad_id: int, user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            result = await conn.execute("""
                DELETE FROM publicidad
                WHERE id = $1 AND usuario_id = $2
            """, publicidad_id, user_id)
            return result == "DELETE 1"

    async def calificar_publicidad(self, user_id: int, publicidad_id: int, estrellas: int) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_engagement_schema(conn)
            await conn.execute("""
                INSERT INTO publicidad_calificaciones (publicidad_id, user_id, estrellas, created_at)
                VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
                ON CONFLICT (publicidad_id, user_id)
                DO UPDATE SET estrellas = EXCLUDED.estrellas, created_at = CURRENT_TIMESTAMP
            """, publicidad_id, user_id, estrellas)

            stats = await conn.fetchrow("""
                SELECT
                    COALESCE(AVG(estrellas), 0.0) AS promedio,
                    COUNT(*) AS total_votos
                FROM publicidad_calificaciones
                WHERE publicidad_id = $1
            """, publicidad_id)

            promedio = float(stats["promedio"]) if stats else 0.0
            total_votos = int(stats["total_votos"]) if stats else 0

            return {
                "success": True,
                "promedio": round(promedio, 1),
                "total_votos": total_votos,
                "user_rating": estrellas,
                "is_destacado": promedio >= 4.5 and total_votos >= 3,
            }

    async def toggle_favorito(self, user_id: int, publicidad_id: int) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await self._ensure_engagement_schema(conn)

            existe = await conn.fetchval("""
                SELECT 1
                FROM publicidad_likes
                WHERE publicidad_id = $1 AND user_id = $2
            """, publicidad_id, user_id)

            if existe:
                await conn.execute("""
                    DELETE FROM publicidad_likes
                    WHERE publicidad_id = $1 AND user_id = $2
                """, publicidad_id, user_id)
                is_fav = False
            else:
                await conn.execute("""
                    INSERT INTO publicidad_likes (publicidad_id, user_id, created_at)
                    VALUES ($1, $2, CURRENT_TIMESTAMP)
                    ON CONFLICT (publicidad_id, user_id) DO NOTHING
                """, publicidad_id, user_id)
                is_fav = True

            total_likes = int(await conn.fetchval("""
                SELECT COUNT(*)
                FROM publicidad_likes
                WHERE publicidad_id = $1
            """, publicidad_id) or 0)

            rating_stats = await conn.fetchrow("""
                SELECT
                    COALESCE(AVG(estrellas), 0.0) AS promedio,
                    COUNT(*) AS total_votos
                FROM publicidad_calificaciones
                WHERE publicidad_id = $1
            """, publicidad_id)

            promedio = float(rating_stats["promedio"]) if rating_stats else 0.0
            total_votos = int(rating_stats["total_votos"]) if rating_stats else 0

            return {
                "success": True,
                "is_favorite": is_fav,
                "total_likes": total_likes,
                "promedio": round(promedio, 1),
                "total_votos": total_votos,
                "is_destacado": promedio >= 4.5 and total_votos >= 3,
            }

    async def aprobar_publicidad(self, publicidad_id: int, admin_user_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            is_admin = await conn.fetchval("SELECT is_super_admin FROM users WHERE id = $1", admin_user_id)
            if not is_admin:
                raise PermissionError("Permisos insuficientes para aprobar publicidad")
                
            result = await conn.execute("""
                UPDATE publicidad
                SET aprobado = TRUE, pago_confirmado = TRUE
                WHERE id = $1
            """, publicidad_id)
            return result == "UPDATE 1"

    def list_categorias(self, lang: str = "es") -> List[Dict[str, Any]]:
        normalized_lang = (lang or "es").strip().lower().split("-")[0]
        if not re.fullmatch(r"[a-z]{2,10}", normalized_lang):
            normalized_lang = "es"

        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT
                        c.id,
                        COALESCE(ct.nombre, c.nombre) AS nombre,
                        c.slug,
                        c.icono,
                        c.activa AS activo,
                        c.orden
                    FROM categorias AS c
                    LEFT JOIN categorias_traducciones AS ct
                      ON ct.categoria_id = c.id
                     AND ct.idioma = %s
                    WHERE COALESCE(c.activa, TRUE) = TRUE
                    ORDER BY LOWER(COALESCE(ct.nombre, c.nombre)), c.id
                    """,
                    (normalized_lang,),
                )
                return cur.fetchall()

    def list_paises(self) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                # `to_jsonb(p)` makes the read compatible with an instance that
                # has not received the additive country-media migration yet.
                # The canonical columns are still public.paises.flag_url and
                # public.paises.background_url; no visual asset is stored on
                # individual loterias.
                cur.execute("""
                    SELECT
                        p.id,
                        p.nombre,
                        UPPER(NULLIF(BTRIM(to_jsonb(p) ->> 'codigo_iso'), '')) AS codigo_iso,
                        NULLIF(BTRIM(to_jsonb(p) ->> 'flag_url'), '') AS flag_url,
                        NULLIF(BTRIM(to_jsonb(p) ->> 'background_url'), '') AS background_url
                    FROM paises AS p
                    ORDER BY p.nombre;
                """)
                return cur.fetchall()

    def list_departamentos(self, pais_id: int) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT id, nombre FROM departamentos WHERE pais_id = %s ORDER BY nombre", (pais_id,))
                return cur.fetchall()

    def list_departamentos_all(self) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT * FROM departamentos ORDER BY nombre")
                return cur.fetchall()

    def list_ciudades(self) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT * FROM ciudades ORDER BY nombre")
                return cur.fetchall()

    def list_ciudades_by_departamento(self, departamento_id: int) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT * FROM ciudades WHERE departamento_id = %s ORDER BY nombre", (departamento_id,))
                return cur.fetchall()

    def list_loterias(self) -> List[Dict[str, Any]]:
        return self.list_loterias_by_pais(None)

    def list_loterias_by_pais(self, pais_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Catálogo sin consultas SQL por lotería (evita el patrón N+1).

        El cálculo de las fechas conserva la selección anterior de tablas:
        route/nombre y sus sufijos numéricos, ordenadas por fecha máxima.
        Las lecturas de tablas de resultados se agrupan en un solo UNION ALL.
        """
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                query = """
                    SELECT id, nombre, tipo, pais_id, route,
                           max_seleccion, max_balotas_blancas, max_balotas_rojas,
                           superbalota_nombre, has_revancha, total_balotas_sorteo,
                           tiene_complementario, tiene_reintegro, top_probables_count
                    FROM loterias
                    WHERE activa = TRUE
                """
                params = []
                if pais_id is not None:
                    query += " AND pais_id = %s"
                    params.append(pais_id)
                query += " ORDER BY nombre"
                cur.execute(query, tuple(params))
                loterias = cur.fetchall()
                if not loterias:
                    return loterias

                # Una consulta al esquema, no una consulta por cada tabla/lotería.
                # Conservamos ordinal_position para priorizar numero o la primera balota.
                table_columns: Dict[str, List[Tuple[str, str]]] = {}
                try:
                    cur.execute("""
                        SELECT table_name, column_name, data_type
                        FROM information_schema.columns
                        WHERE table_schema = 'public'
                          AND LEFT(table_name, 11) = 'resultados_'
                        ORDER BY table_name, ordinal_position
                    """)
                    for item in cur.fetchall():
                        table_columns.setdefault(item['table_name'], []).append(
                            (item['column_name'].lower(), item['data_type'].lower())
                        )
                except Exception:
                    conn.rollback()
                    logger.exception('No se pudo leer esquema de tablas resultados')

                # Solo se consultan tablas candidatas realmente utilizadas.
                candidate_tables: set[str] = set()
                lots_with_candidates = []
                for lot in loterias:
                    route = self._normalize_identity(lot.get('route'))
                    nombre = self._normalize_identity(lot.get('nombre'))
                    aliases = {route, nombre} - {''}
                    bases = [f'resultados_{alias}' for alias in aliases]
                    # La implementación original solo buscaba resultados si
                    # la lotería tenía una route válida.
                    matches = [
                        table for table in table_columns
                        if route and any(
                            table == base or re.fullmatch(re.escape(base) + r'\d+', table)
                            for base in bases
                        )
                    ]
                    lots_with_candidates.append((lot, route, nombre, matches))
                    candidate_tables.update(matches)

                # MAX(fecha) determina la tabla de mayor vigencia, mientras que
                # numero/balota identifica sorteos futuros (0) y realizados (>0).
                # pg_sql.Identifier impide interpolación insegura de identificadores.
                result_dates: Dict[str, Tuple[Any, Optional[str], Optional[str]]] = {}
                numeric_types = {
                    'smallint', 'integer', 'bigint', 'numeric', 'decimal',
                    'real', 'double precision',
                }
                parts = []
                for table in sorted(candidate_tables):
                    columns = dict(table_columns[table])
                    if 'fecha' not in columns:
                        continue
                    main_cols = sorted(
                        (column for column in columns
                         if re.fullmatch(r'balota\d+', column)),
                        key=lambda column: int(column.replace('balota', '')),
                    )
                    marker = (
                        'numero' if 'numero' in columns
                        else (main_cols[0] if main_cols else None)
                    )
                    # Si el marcador no es numérico, no es posible calcular
                    # las fechas filtradas (igual que en la versión anterior).
                    if marker is not None and columns.get(marker) in numeric_types:
                        next_expr = pg_sql.SQL(
                            '(MAX({fecha}) FILTER (WHERE {marker} = 0))::text'
                        ).format(fecha=pg_sql.Identifier('fecha'), marker=pg_sql.Identifier(marker))
                        last_expr = pg_sql.SQL(
                            '(MAX({fecha}) FILTER (WHERE {marker} > 0))::text'
                        ).format(fecha=pg_sql.Identifier('fecha'), marker=pg_sql.Identifier(marker))
                    else:
                        next_expr = pg_sql.SQL('NULL')
                        last_expr = pg_sql.SQL('NULL')
                    parts.append(pg_sql.SQL("""
                        SELECT {name} AS table_name,
                               MAX({fecha})::text AS max_fecha,
                               {next} AS proximo_sorteo,
                               {last} AS ultimo_sorteo
                        FROM {table}
                    """).format(
                        name=pg_sql.Literal(table),
                        fecha=pg_sql.Identifier('fecha'),
                        next=next_expr,
                        last=last_expr,
                        table=pg_sql.Identifier('public', table),
                    ))

                if parts:
                    try:
                        cur.execute(pg_sql.SQL(' UNION ALL ').join(parts))
                        for item in cur.fetchall():
                            proximo = item['proximo_sorteo']
                            ultimo = item['ultimo_sorteo']
                            result_dates[item['table_name']] = (
                                item['max_fecha'],
                                str(proximo) if proximo else None,
                                str(ultimo) if ultimo else None,
                            )
                    except Exception:
                        # No permitir que una tabla irregular rompa todo el catálogo.
                        # La ruta de respaldo mantiene las reglas anteriores.
                        conn.rollback()
                        logger.exception('Fallo en consulta agrupada de fechas de resultados')
                        for table in sorted(candidate_tables):
                            try:
                                cur.execute(
                                    pg_sql.SQL('SELECT MAX(fecha) AS max_fecha FROM {}').format(
                                        pg_sql.Identifier('public', table)
                                    )
                                )
                                max_date = cur.fetchone()['max_fecha']
                                proximo, ultimo = self._get_result_dates(cur, table)
                                result_dates[table] = (max_date, proximo, ultimo)
                            except Exception:
                                conn.rollback()
                                logger.warning('Sin fechas legibles en %s', table)

                # Resolver cada lotería a partir del resultado compartido.
                # El criterio coincide con _resolve_result_table original.
                pending_predictions: set[str] = set()
                for lot, route, nombre, matches in lots_with_candidates:
                    ranked = [
                        (result_dates[table][0] is not None,
                         result_dates[table][0],
                         table == f'resultados_{route}', table)
                        for table in matches if table in result_dates
                    ]
                    if ranked:
                        ranked.sort(reverse=True)
                        selected = ranked[0][3]
                        _, proximo, ultimo = result_dates[selected]
                        if proximo:
                            lot['proximo_sorteo'] = proximo
                        if ultimo:
                            lot['ultimo_sorteo'] = ultimo
                    if route and not lot.get('proximo_sorteo'):
                        pending_predictions.update({route, nombre} - {''})

                # Una única agrupación en predicciones, en lugar de una por juego.
                prediction_dates: Dict[str, Any] = {}
                if pending_predictions:
                    normalized_route = "LOWER(REPLACE(REPLACE(TRIM(loteria_route), ' ', '_'), '-', '_'))"
                    try:
                        cur.execute(f"""
                            SELECT {normalized_route} AS route_key, MAX(fecha) AS p_fecha
                            FROM predicciones
                            WHERE {normalized_route} = ANY(%s)
                            GROUP BY {normalized_route}
                        """, (sorted(pending_predictions),))
                        prediction_dates = {
                            item['route_key']: item['p_fecha'] for item in cur.fetchall()
                        }
                    except Exception:
                        conn.rollback()
                        logger.exception('No se pudo agrupar próximas fechas desde predicciones')

                # También se leen los jackpots en una sola consulta.
                jackpot_map: Dict[str, str] = {}
                try:
                    cur.execute("""
                        SELECT DISTINCT ON (LOWER(TRIM(loteria)))
                               LOWER(TRIM(loteria)) AS lot, jackpot
                        FROM loterias_jackpots
                        ORDER BY LOWER(TRIM(loteria)), fecha DESC
                    """)
                    for item in cur.fetchall():
                        lot_key = item['lot']
                        jackpot = item['jackpot']
                        if lot_key and jackpot:
                            val = str(jackpot)
                            jackpot_map[lot_key] = val
                            jackpot_map[lot_key.replace('_', ' ')] = val
                            jackpot_map[lot_key.replace(' ', '_')] = val
                except Exception:
                    conn.rollback()
                    logger.exception('No se pudieron cargar los jackpots')

                for lot, route, nombre, _ in lots_with_candidates:
                    if route and not lot.get('proximo_sorteo'):
                        p_fecha = max(
                            (prediction_dates[key] for key in {route, nombre} - {''}
                             if prediction_dates.get(key) is not None),
                            default=None,
                        )
                        if p_fecha:
                            lot['proximo_sorteo'] = str(p_fecha)

                    jackpot = next(
                        (jackpot_map.get(k) for k in (route, nombre)
                         if k and jackpot_map.get(k)),
                        None,
                    )
                    if jackpot:
                        lot['jackpot'] = jackpot

                return loterias
