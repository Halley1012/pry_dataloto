import psycopg2
import psycopg2.extras
from typing import List, Optional, Tuple, Dict, Any
from app.domain.ports import PublicidadRepositoryPort
from app.infrastructure import db_connection

class PostgresPublicidadRepository(PublicidadRepositoryPort):
    async def create_publicidad(self, user_id: int, imagen_url: str, link: str, categoria_id: int, ciudad_id: int, departamento_id: int) -> Dict[str, Any]:
        # En la implementación original se recibe un dict complejo con múltiples campos.
        # Pasaremos esos datos directamente en el caso de uso, pero este método general
        # puede guardar los campos básicos. Para mantener 100% de compatibilidad, 
        # definiremos un método más genérico o que reciba los datos mapeados.
        pass

    async def create_publicidad_full(self, user_id: int, data: Dict[str, Any]) -> Dict[str, Any]:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO publicidad (
                    usuario_id, categoria_id, pais_id, departamento_id, ciudad_id,
                    titulo, descripcion, imagen_url, telefono, 
                    facebook_url, instagram_url, whatsapp_url, tiktok_url, pagina_url,
                    direccion, fecha_inicio, fecha_fin, estado, aprobado, pago_confirmado
                )
                VALUES (
                    $1, $2, $3, $4, $5,
                    $6, $7, $8, $9,
                    $10, $11, $12, $13, $14,
                    $15, CURRENT_DATE, CURRENT_DATE + INTERVAL '15 days',
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
            data.get("direccion")
            )
            return {"success": True, "message": "Anuncio creado exitosamente. Pendiente de aprobación."}

    async def list_publicidad_aprobada(self, categoria_id: Optional[int], departamento_id: Optional[int], ciudad_id: Optional[int]) -> List[Dict[str, Any]]:
        # Este método no se usa directamente tal cual, sino el dinámico de listar_publicidad con filtros
        pass

    async def list_publicidad_dinamica(self, filters: Dict[str, Any], limit: int, offset: int) -> Tuple[List[Dict[str, Any]], int]:
        pool = db_connection.get_pool()
        base_query = """
            SELECT 
                p.*,
                pa.nombre AS pais_nombre,
                d.nombre AS departamento_nombre,
                c.nombre AS categoria_nombre,
                ci.nombre AS ciudad_nombre
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
            rows = await conn.fetch(full_query, *params)
            data = [dict(row) for row in rows]

            # Reemplazar de forma limpia y simplificada para evitar errores de matching de strings multilinea largos
            simplified_count_query = f"""
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
            query = """
                SELECT 
                    p.*, 
                    c.nombre AS categoria_nombre,
                    ci.nombre AS ciudad_nombre,
                    d.nombre AS departamento_nombre
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
            existe = await conn.fetchrow("SELECT 1 FROM publicidad WHERE id = $1 AND usuario_id = $2", publicidad_id, user_id)
            if not existe:
                return False

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
                    fecha_fin = CASE 
                        WHEN pago_confirmado = FALSE THEN CURRENT_DATE + INTERVAL '15 days'
                        ELSE fecha_fin
                     END
                WHERE id = $15
            """
            await conn.execute(query,
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
                publicidad_id
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

    async def aprobar_publicidad(self, publicidad_id: int) -> bool:
        pool = db_connection.get_pool()
        async with pool.acquire() as conn:
            result = await conn.execute("""
                UPDATE publicidad
                SET aprobado = TRUE, pago_confirmado = TRUE
                WHERE id = $1
            """, publicidad_id)
            return result == "UPDATE 1"

    def list_categorias(self) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT * FROM categorias ORDER BY nombre")
                return cur.fetchall()

    def list_paises(self) -> List[Dict[str, Any]]:
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT id, nombre FROM paises ORDER BY nombre;")
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
        with db_connection.get_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                try:
                    if pais_id:
                        cur.execute("""
                            SELECT id, nombre, tipo, pais_id,
                                   COALESCE(route, '') AS route,
                                   COALESCE(max_seleccion, 5) AS max_seleccion,
                                   COALESCE(max_balotas_blancas, 45) AS max_balotas_blancas,
                                   COALESCE(max_balotas_rojas, 0) AS max_balotas_rojas,
                                   superbalota_nombre,
                                   COALESCE(has_revancha, false) AS has_revancha
                            FROM loterias
                            WHERE pais_id = %s
                              AND activa = true
                            ORDER BY nombre
                        """, (pais_id,))
                    else:
                        cur.execute("""
                            SELECT id, nombre, tipo, pais_id,
                                   COALESCE(route, '') AS route,
                                   COALESCE(max_seleccion, 5) AS max_seleccion,
                                   COALESCE(max_balotas_blancas, 45) AS max_balotas_blancas,
                                   COALESCE(max_balotas_rojas, 0) AS max_balotas_rojas,
                                   superbalota_nombre,
                                   COALESCE(has_revancha, false) AS has_revancha
                            FROM loterias
                            WHERE activa = true
                            ORDER BY nombre
                        """)
                    loterias = cur.fetchall()
                except Exception as e:
                    # Fallback si las nuevas columnas aún no se han creado en la BD
                    logger.warning(f"Columnas nuevas de loterias no encontradas (ejecute la migración SQL): {e}")
                    conn.rollback()
                    if pais_id:
                        cur.execute("""
                            SELECT id, nombre, tipo, pais_id
                            FROM loterias
                            WHERE pais_id = %s
                              AND activa = true
                            ORDER BY nombre
                        """, (pais_id,))
                    else:
                        cur.execute("""
                            SELECT id, nombre, tipo, pais_id
                            FROM loterias
                            WHERE activa = true
                            ORDER BY nombre
                        """)
                    loterias = cur.fetchall()

                for lot in loterias:
                    r = (lot.get('route') or '').strip().lower()
                    if not r:
                        r = lot['nombre'].lower().strip().replace(' ', '_')
                        lot['route'] = r

                    tabla = f"resultados_{r}"
                    try:
                        # Verificar si existe la tabla antes de consultar la fecha de sorteo
                        cur.execute("""
                            SELECT EXISTS (
                                SELECT FROM information_schema.tables 
                                WHERE table_name = %s
                            );
                        """, (tabla,))
                        exists = cur.fetchone()
                        has_table = exists['exists'] if isinstance(exists, dict) else (exists[0] if exists else False)

                        if has_table:
                            cur.execute(f"SELECT MAX(fecha) AS max_fecha FROM {tabla} WHERE balota1 = 0 AND fecha >= (CURRENT_DATE - INTERVAL '1 day')")
                            res = cur.fetchone()
                            if res:
                                max_fecha = res['max_fecha'] if isinstance(res, dict) and 'max_fecha' in res else res[0]
                                if max_fecha:
                                    lot['proximo_sorteo'] = str(max_fecha)
                    except Exception:
                        pass
                return loterias
