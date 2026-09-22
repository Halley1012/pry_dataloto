import math
import os
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

import pandas as pd
from sqlalchemy import inspect, text

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

from config.database import get_engine
from config.backend_notifications import BackendNotificationClient


class NotificationGenerator:
    """
    Generador universal de notificaciones de resultados.

    Identidad:
      - loteria_id = identidad concreta/canónica.
      - route = motor/dataset compartido.

    No contiene tablas, rangos, nombres ni IDs específicos por lotería.
    """

    _BALOTA_RE = re.compile(r"^balota(\d+)$", re.IGNORECASE)
    _BALOTA_ROJA_RE = re.compile(r"^balotaroja(\d*)$", re.IGNORECASE)

    def __init__(self):
        self.engine = get_engine()
        self.notification_client = BackendNotificationClient()
        self.partial_hit_min = self._env_int(
            "NOTIFICATION_PARTIAL_HIT_MIN",
            default=3,
            minimum=1,
        )
        self._table_columns_cache: dict[str, set[str]] = {}
        self._result_tables_cache: list[str] | None = None

    @staticmethod
    def _env_int(name: str, *, default: int, minimum: int = 0) -> int:
        raw = os.getenv(name, "").strip()
        if not raw:
            return default
        try:
            return max(minimum, int(raw))
        except ValueError:
            print(
                f"⚠️ {name}='{raw}' no es entero. "
                f"Se usa el valor por defecto {default}."
            )
            return default

    @staticmethod
    def _normalize(value: Any) -> str:
        text_value = "" if value is None else str(value)
        normalized = unicodedata.normalize("NFKD", text_value)
        ascii_value = "".join(
            char for char in normalized if not unicodedata.combining(char)
        )
        return re.sub(r"[^a-z0-9]+", "", ascii_value.lower())

    @staticmethod
    def _as_int_list(value: Any) -> list[int]:
        if value is None:
            return []

        if isinstance(value, (list, tuple, set)):
            raw_values = list(value)
        else:
            try:
                # PostgreSQL arrays normalmente ya llegan como list/tuple.
                # Evitamos iterar strings carácter por carácter.
                if pd.isna(value):
                    return []
            except (TypeError, ValueError):
                pass
            raw_values = [value]

        result: list[int] = []
        for item in raw_values:
            if item is None:
                continue
            try:
                if pd.isna(item):
                    continue
            except (TypeError, ValueError):
                pass
            try:
                result.append(int(item))
            except (TypeError, ValueError):
                continue
        return result

    # ------------------------------------------------------------------
    # Catálogo
    # ------------------------------------------------------------------

    def _catalog_rows(self) -> list[dict[str, Any]]:
        """
        Lee únicamente columnas que realmente existen en la tabla loterias.
        Esto permite que DEV/PRD tengan pequeñas diferencias de migración.
        """
        inspector = inspect(self.engine)
        columns = {
            item["name"]
            for item in inspector.get_columns("loterias", schema="public")
        }

        required = {"id", "nombre", "route"}
        missing = required - columns
        if missing:
            raise RuntimeError(
                "La tabla loterias no contiene las columnas canónicas: "
                + ", ".join(sorted(missing))
            )

        optional = [
            "pais_id",
            "activa",
            "max_seleccion",
            "max_balotas_blancas",
            "max_balotas_rojas",
            "superbalota_nombre",
            "total_balotas_sorteo",
            "top_probables_count",
        ]
        selected = ["id", "nombre", "route"] + [
            col for col in optional if col in columns
        ]

        sql = "SELECT " + ", ".join(f'"{col}"' for col in selected)
        sql += " FROM loterias"
        if "activa" in columns:
            sql += " WHERE COALESCE(activa, TRUE) = TRUE"
        sql += " ORDER BY id"

        with self.engine.connect() as conn:
            rows = conn.execute(text(sql)).mappings().all()

        return [dict(row) for row in rows]

    def _resolve_catalog(self, requested: str) -> list[dict[str, Any]]:
        rows = self._catalog_rows()

        if requested.strip().lower() == "all":
            return [row for row in rows if row.get("route")]

        target = self._normalize(requested)
        matches = []

        for row in rows:
            candidates = {
                self._normalize(row.get("route")),
                self._normalize(row.get("nombre")),
            }
            if target in candidates:
                matches.append(row)

        return matches

    # ------------------------------------------------------------------
    # Resultados
    # ------------------------------------------------------------------

    def _result_tables(self) -> list[str]:
        if self._result_tables_cache is None:
            inspector = inspect(self.engine)
            self._result_tables_cache = sorted(
                table
                for table in inspector.get_table_names(schema="public")
                if table.startswith("resultados_")
            )
        return self._result_tables_cache

    def _table_columns(self, table: str) -> set[str]:
        if table not in self._table_columns_cache:
            inspector = inspect(self.engine)
            self._table_columns_cache[table] = {
                item["name"]
                for item in inspector.get_columns(table, schema="public")
            }
        return self._table_columns_cache[table]

    def _fetch_latest_results_from_table(
        self,
        table: str,
        *,
        loteria_id: int,
        require_loteria_id: bool,
    ) -> list[dict[str, Any]]:
        """
        Devuelve TODAS las variantes reales del último sorteo de la tabla.

        Varias loterías comparten una misma fecha y guardan modalidades como
        filas distintas (por ejemplo principal/revancha). Tomar LIMIT 1 hacía
        que la notificación pudiera atribuir a la modalidad principal los
        aciertos de otra fila del mismo sorteo.
        """
        columns = self._table_columns(table)
        if "fecha" not in columns:
            return []

        clauses: list[str] = []
        params: dict[str, Any] = {}

        if "balota1" in columns:
            clauses.append("COALESCE(balota1, 0) > 0")

        if require_loteria_id:
            if "loteria_id" not in columns:
                return []
            clauses.append("loteria_id = :loteria_id")
            params["loteria_id"] = int(loteria_id)

        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        latest_sql = text(
            f'SELECT MAX(fecha) FROM "{table}"{where}'
        )
        with self.engine.connect() as conn:
            latest_fecha = conn.execute(latest_sql, params).scalar()

        if latest_fecha is None:
            return []

        same_draw_clauses = list(clauses) + ["fecha = :latest_fecha"]
        same_params = dict(params)
        same_params["latest_fecha"] = latest_fecha
        same_where = " WHERE " + " AND ".join(same_draw_clauses)

        order_parts = []
        if "sorteo" in columns:
            order_parts.append("sorteo")
        if "id" in columns:
            order_parts.append("id")
        order_sql = " ORDER BY " + ", ".join(order_parts) if order_parts else ""

        sql = text(f'SELECT * FROM "{table}"{same_where}{order_sql}')
        with self.engine.connect() as conn:
            rows = conn.execute(sql, same_params).mappings().all()

        # Evita que una tabla legacy con filas duplicadas genere una modalidad
        # repetida en el mismo resumen.
        unique: dict[str, dict[str, Any]] = {}
        for row in rows:
            item = dict(row)
            variant = str(item.get("sorteo") or "").strip()
            key = self._normalize(variant) or f"row-{len(unique)}"
            if key not in unique:
                unique[key] = item
        return list(unique.values())

    def _latest_results(
        self,
        *,
        loteria_id: int,
        route: str,
    ) -> tuple[str, list[dict[str, Any]]] | tuple[None, list]:
        """Resuelve el dataset y conserva todas las modalidades de la fecha."""
        result_tables = self._result_tables()
        preferred = f"resultados_{route.strip().lower()}"

        ordered = []
        if preferred in result_tables:
            ordered.append(preferred)
        ordered.extend(table for table in result_tables if table != preferred)

        for table in ordered:
            rows = self._fetch_latest_results_from_table(
                table,
                loteria_id=loteria_id,
                require_loteria_id=True,
            )
            if rows:
                return table, rows

        if preferred in result_tables:
            rows = self._fetch_latest_results_from_table(
                preferred,
                loteria_id=loteria_id,
                require_loteria_id=False,
            )
            if rows:
                return preferred, rows

        return None, []

    @staticmethod
    def _variant_name(result: dict[str, Any], fallback: str) -> str:
        value = str(result.get("sorteo") or "").strip()
        if value and value.lower() not in {"desconocido", "none", "null"}:
            return value
        return fallback

    @staticmethod
    def _format_fecha_es(value: Any) -> str:
        meses = [
            "enero", "febrero", "marzo", "abril", "mayo", "junio",
            "julio", "agosto", "septiembre", "octubre", "noviembre",
            "diciembre",
        ]
        try:
            dt = pd.to_datetime(value)
            return f"{int(dt.day)} de {meses[int(dt.month) - 1]}"
        except Exception:
            return str(value)

    @classmethod
    def _winning_white_numbers(
        cls,
        result: dict[str, Any],
        *,
        expected_count: int | None,
    ) -> set[int]:
        numbered_columns: list[tuple[int, str]] = []
        for column in result:
            match = cls._BALOTA_RE.fullmatch(column)
            if match:
                numbered_columns.append((int(match.group(1)), column))

        numbered_columns.sort()
        if expected_count and expected_count > 0:
            numbered_columns = numbered_columns[:expected_count]

        values: set[int] = set()
        for _, column in numbered_columns:
            values.update(cls._as_int_list(result.get(column)))
        return values

    @classmethod
    def _winning_special_numbers(
        cls,
        result: dict[str, Any],
        *,
        expected_count: int | None,
    ) -> set[int]:
        """
        Obtiene únicamente las balotas especiales que realmente forman parte
        del sorteo según el catálogo.

        `total_balotas_sorteo - max_seleccion` es la fuente canónica del
        número de especiales. Esto evita interpretar como especial un
        `balotaroja = 0` técnico en loterías que en realidad no tienen
        balota especial.
        """
        if expected_count is not None and expected_count <= 0:
            return set()

        numbered_columns: list[tuple[int, str]] = []
        for column in result:
            match = cls._BALOTA_ROJA_RE.fullmatch(column)
            if not match:
                continue
            suffix = match.group(1)
            position = int(suffix) if suffix else 1
            numbered_columns.append((position, column))

        numbered_columns.sort()
        if expected_count is not None:
            numbered_columns = numbered_columns[:expected_count]

        values: set[int] = set()
        for _, column in numbered_columns:
            values.update(cls._as_int_list(result.get(column)))
        return values

    # ------------------------------------------------------------------
    # Predicción
    # ------------------------------------------------------------------

    def _prediction_for_draw(
        self,
        *,
        loteria_id: int,
        route: str,
        fecha,
    ) -> dict[str, Any] | None:
        """
        Match exacto por fecha. No usa una predicción anterior como fallback:
        eso evitaría atribuirle a la IA una predicción que no pertenecía
        realmente a ese sorteo.
        """
        with self.engine.connect() as conn:
            row = conn.execute(
                text("""
                    SELECT *
                    FROM predicciones
                    WHERE fecha = :fecha
                      AND (
                        loteria_id = :loteria_id
                        OR LOWER(loteria_route) = :route
                      )
                    ORDER BY
                      CASE WHEN loteria_id = :loteria_id THEN 0 ELSE 1 END,
                      created_at DESC NULLS LAST
                    LIMIT 1
                """),
                {
                    "fecha": fecha,
                    "loteria_id": int(loteria_id),
                    "route": route.strip().lower(),
                },
            ).mappings().first()

        return dict(row) if row else None

    @staticmethod
    def _top_probables_count(
        catalog: dict[str, Any],
        pred_nums: list[int],
    ) -> int:
        explicit = catalog.get("top_probables_count")
        try:
            if explicit is not None and int(explicit) > 0:
                return min(int(explicit), len(pred_nums))
        except (TypeError, ValueError):
            pass

        max_white = catalog.get("max_balotas_blancas")
        try:
            if max_white is not None and int(max_white) > 0:
                # Fallback de compatibilidad. La fuente canónica es
                # loterias.top_probables_count; si aún no está configurada,
                # usamos división entera para coincidir con ResultadosScreen.
                return min(
                    max(1, int(max_white) // 2),
                    len(pred_nums),
                )
        except (TypeError, ValueError):
            pass

        # Último fallback técnico: usa la mitad entera del ranking guardado.
        return max(1, len(pred_nums) // 2)

    # ------------------------------------------------------------------
    # Jugadas de usuario
    # ------------------------------------------------------------------

    def _notificacion_usuario_ya_publicada(
        self,
        user_id: int,
        loteria_id: int,
        fecha,
        tipo: str,
    ) -> bool:
        with self.engine.connect() as conn:
            return bool(
                conn.execute(
                    text("""
                        SELECT EXISTS (
                            SELECT 1
                            FROM notificaciones
                            WHERE usuario_id = :user_id
                              AND loteria_id = :loteria_id
                              AND fecha_sorteo = :fecha
                              AND tipo = :tipo
                        )
                    """),
                    {
                        "user_id": int(user_id),
                        "loteria_id": int(loteria_id),
                        "fecha": fecha,
                        "tipo": tipo,
                    },
                ).scalar()
            )

    def _publicar_notificacion_usuario(
        self,
        *,
        user_id: int,
        loteria_id: int,
        fecha,
        mensaje: str,
        tipo: str,
        force: bool = False,
    ) -> bool:
        try:
            if (
                not force
                and self._notificacion_usuario_ya_publicada(
                    user_id,
                    loteria_id,
                    fecha,
                    tipo,
                )
            ):
                print(
                    "ℹ️ Notificación personalizada ya publicada; "
                    f"user_id={user_id}, loteria_id={loteria_id}, fecha={fecha}."
                )
                return False

            result = self.notification_client.publish(
                loteria_id=int(loteria_id),
                fecha_sorteo=fecha,
                mensaje=mensaje,
                tipo=tipo,
                user_id=int(user_id),
            )
            if result.get("created") is False or result.get("duplicate") is True:
                print(
                    "ℹ️ Resultado de jugada ya publicado; backend omitió duplicado "
                    f"| user_id={user_id} | loteria_id={loteria_id} | fecha={fecha}"
                )
                return False

            push = result.get("push") or {}
            print(
                "✅ Resultado de jugada notificado "
                f"| user_id={user_id} | sent={push.get('sent', 0)} "
                f"| failed={push.get('failed', 0)}"
            )
            return True
        except Exception as exc:
            print(
                "⚠️ No fue posible publicar el resultado de jugada "
                f"para user_id={user_id}: {exc}"
            )
            return False

    def notificar_aciertos_jugadas(
        self,
        *,
        loteria_id: int,
        nombre_display: str,
        fecha,
        ganadores: set[int] | None = None,
        especiales_ganadores: set[int] | None = None,
        variantes: list[dict[str, Any]] | None = None,
        max_seleccion: int | None = None,
        total_balotas_sorteo: int | None = None,
        especial_nombre: str | None = None,
        force: bool = False,
    ) -> None:
        """
        Compara jugadas preservando roles y modalidades.

        Compatibilidad: `ganadores`/`especiales_ganadores` siguen aceptándose
        para pruebas o loterías de una sola modalidad. En producción se pasa
        `variantes` para evitar mezclar Baloto/Revancha u otras modalidades.
        """
        if not variantes:
            variantes = [
                {
                    "nombre": nombre_display,
                    "ganadores": ganadores or set(),
                    "especiales": especiales_ganadores or set(),
                }
            ]

        if not any(v.get("ganadores") or v.get("especiales") for v in variantes):
            return

        try:
            jugadas = pd.read_sql(
                text("""
                    SELECT user_id, numeros
                    FROM jugadas
                    WHERE loteria_id = :loteria_id
                      AND (
                        fecha_sorteo = :fecha
                        OR (
                          fecha_sorteo IS NULL
                          AND fecha_guardado::date = :fecha
                        )
                      )
                """),
                self.engine,
                params={
                    "loteria_id": int(loteria_id),
                    "fecha": fecha,
                },
            )
        except Exception as exc:
            print(f"⚠️ No se pudieron consultar jugadas de {nombre_display}: {exc}")
            return

        if jugadas.empty:
            return

        try:
            main_count = int(max_seleccion or 0)
        except (TypeError, ValueError):
            main_count = 0
        if main_count <= 0:
            main_count = max(
                (len(v.get("ganadores") or set()) for v in variantes),
                default=0,
            )

        try:
            total_configurado = int(total_balotas_sorteo or 0)
        except (TypeError, ValueError):
            total_configurado = 0

        total_resultado = total_configurado if total_configurado > 0 else main_count
        special_slots = max(0, total_resultado - main_count)
        special_label = (especial_nombre or "Especial").strip() or "Especial"

        for user_id, grupo in jugadas.groupby("user_id"):
            mejor: dict[str, Any] | None = None
            cantidad_jugadas = 0

            for _, row in grupo.iterrows():
                numeros = self._as_int_list(row.get("numeros"))
                if not numeros:
                    continue
                cantidad_jugadas += 1

                principales_jugada = set(numeros[:main_count])
                especiales_jugada = set(
                    numeros[main_count : main_count + special_slots]
                )

                for variant in variantes:
                    principales_resultado = set(variant.get("ganadores") or set())
                    especiales_resultado = set(variant.get("especiales") or set())
                    aciertos_principales = principales_jugada.intersection(
                        principales_resultado
                    )
                    aciertos_especiales = especiales_jugada.intersection(
                        especiales_resultado
                    )
                    total_aciertos = len(aciertos_principales) + len(aciertos_especiales)

                    candidate = {
                        "total": total_aciertos,
                        "principales": aciertos_principales,
                        "especiales": aciertos_especiales,
                        "variante": str(variant.get("nombre") or nombre_display),
                    }
                    if mejor is None or (
                        candidate["total"],
                        len(candidate["principales"]),
                        len(candidate["especiales"]),
                    ) > (
                        mejor["total"],
                        len(mejor["principales"]),
                        len(mejor["especiales"]),
                    ):
                        mejor = candidate

            if not mejor or mejor["total"] <= 0:
                continue

            principales = sorted(mejor["principales"])
            especiales = sorted(mejor["especiales"])
            variante = mejor["variante"]
            variante_sufijo = (
                ""
                if self._normalize(variante) == self._normalize(nombre_display)
                else f" en {variante}"
            )

            principales_txt = ", ".join(map(str, principales))
            detalle_principal = f"Principales: {len(principales)} de {main_count}"
            if principales_txt:
                detalle_principal += f" ({principales_txt})"

            detalles = [detalle_principal]
            if special_slots > 0:
                if especiales:
                    especiales_txt = ", ".join(map(str, especiales))
                    if special_slots == 1:
                        detalles.append(f"{special_label}: {especiales_txt} ✅")
                    else:
                        detalles.append(
                            f"{special_label}: {len(especiales)} de {special_slots} "
                            f"({especiales_txt})"
                        )
                else:
                    detalles.append(f"{special_label}: sin acierto")

            sujeto = "tus jugadas" if cantidad_jugadas > 1 else "tu jugada"
            mensaje = (
                f"🎯 En {sujeto} de {nombre_display}, tu mejor combinación "
                f"acertó {mejor['total']} de {total_resultado}{variante_sufijo}. "
                + " · ".join(detalles)
                + "."
            )

            self._publicar_notificacion_usuario(
                user_id=int(user_id),
                loteria_id=int(loteria_id),
                fecha=fecha,
                mensaje=mensaje[:500],
                tipo="resultado_jugada",
                force=force,
            )

    # ------------------------------------------------------------------
    # Publicación global
    # ------------------------------------------------------------------

    def _notificacion_ya_publicada(
        self,
        loteria_id: int,
        fecha,
        tipo: str,
    ) -> bool:
        with self.engine.connect() as conn:
            return bool(
                conn.execute(
                    text("""
                        SELECT EXISTS (
                            SELECT 1
                            FROM notificaciones
                            WHERE usuario_id IS NULL
                              AND loteria_id = :l_id
                              AND fecha_sorteo = :fecha
                              AND tipo = :tipo
                        )
                    """),
                    {
                        "l_id": int(loteria_id),
                        "fecha": fecha,
                        "tipo": tipo,
                    },
                ).scalar()
            )

    def guardar_notificacion(
        self,
        loteria_id: int,
        fecha,
        mensaje: str,
        tipo: str,
        *,
        force: bool = False,
    ) -> bool:
        try:
            if (
                not force
                and self._notificacion_ya_publicada(
                    loteria_id,
                    fecha,
                    tipo,
                )
            ):
                print(
                    "ℹ️ Notificación ya publicada; se omite duplicado "
                    f"(loteria_id={loteria_id}, fecha={fecha}, tipo={tipo})."
                )
                return False

            result = self.notification_client.publish(
                loteria_id=int(loteria_id),
                fecha_sorteo=fecha,
                mensaje=mensaje,
                tipo=tipo,
            )

            if result.get("created") is False or result.get("duplicate") is True:
                print(
                    "ℹ️ Backend omitió notificación duplicada "
                    f"({tipo}) | loteria_id={loteria_id} | fecha={fecha}"
                )
                return False

            push = result.get("push") or {}
            print(
                "✅ Notificación publicada por backend "
                f"({tipo}) | targets={push.get('targets', 0)} "
                f"| sent={push.get('sent', 0)} "
                f"| failed={push.get('failed', 0)}"
            )
            return True
        except Exception as exc:
            print(f"❌ Error publicando notificación en backend: {exc}")
            return False

    # ------------------------------------------------------------------
    # Orquestación universal
    # ------------------------------------------------------------------

    def procesar_loteria(
        self,
        catalog: dict[str, Any],
        *,
        force: bool = False,
    ) -> None:
        loteria_id = int(catalog["id"])
        nombre_display = str(catalog.get("nombre") or catalog["route"])
        route = str(catalog["route"]).strip().lower()

        table, results = self._latest_results(
            loteria_id=loteria_id,
            route=route,
        )
        if not results:
            print(
                f"ℹ️ Sin resultado válido para {nombre_display} "
                f"(loteria_id={loteria_id}, route={route})."
            )
            return

        fecha = results[0].get("fecha")
        if fecha is None:
            print(f"⚠️ Resultado sin fecha para {nombre_display}; se omite.")
            return

        try:
            expected_white = int(catalog.get("max_seleccion") or 0) or None
        except (TypeError, ValueError):
            expected_white = None

        try:
            total_draw = int(catalog.get("total_balotas_sorteo") or 0)
        except (TypeError, ValueError):
            total_draw = 0

        expected_special = None
        if total_draw > 0 and expected_white is not None:
            expected_special = max(0, total_draw - expected_white)

        variantes: list[dict[str, Any]] = []
        for result in results:
            ganadores = self._winning_white_numbers(
                result,
                expected_count=expected_white,
            )
            if not ganadores:
                continue
            especiales = self._winning_special_numbers(
                result,
                expected_count=expected_special,
            )
            variantes.append(
                {
                    "nombre": self._variant_name(result, nombre_display),
                    "ganadores": ganadores,
                    "especiales": especiales,
                }
            )

        if not variantes:
            print(
                f"⚠️ {table}: no fue posible obtener balotas ganadoras "
                f"para {nombre_display}."
            )
            return

        # Resultado de las jugadas: se evalúa contra cada modalidad de la fecha
        # y se conserva la mejor, sin mezclar principales con especiales.
        self.notificar_aciertos_jugadas(
            loteria_id=loteria_id,
            nombre_display=nombre_display,
            fecha=fecha,
            variantes=variantes,
            max_seleccion=expected_white,
            total_balotas_sorteo=total_draw or None,
            especial_nombre=catalog.get("superbalota_nombre"),
            force=force,
        )

        pred = self._prediction_for_draw(
            loteria_id=loteria_id,
            route=route,
            fecha=fecha,
        )
        if not pred:
            print(
                f"⚠️ Sin predicción EXACTA para {nombre_display} "
                f"en {fecha}; no se calcula precisión retrospectiva."
            )
            return

        pred_nums = self._as_int_list(pred.get("numeros"))
        if not pred_nums:
            print(f"⚠️ Predicción sin números para {nombre_display} ({fecha}).")
            return

        pred_special = self._as_int_list(pred.get("balotaroja"))
        top_count = self._top_probables_count(catalog, pred_nums)
        top_probables = set(pred_nums[:top_count])
        special_slots = max(0, (total_draw or 0) - (expected_white or 0))
        pred_especial_top = set(pred_special[:special_slots]) if special_slots else set()
        special_label = str(catalog.get("superbalota_nombre") or "Especial").strip()

        resumenes: list[str] = []
        especiales_resumen: list[str] = []
        nombres_variantes: list[str] = []

        for variant in variantes:
            variant_name = str(variant["nombre"])
            nombres_variantes.append(variant_name)
            ganadores = set(variant["ganadores"])
            coincidencias = ganadores.intersection(top_probables)
            total_winning = len(ganadores)
            efectividad = (
                (len(coincidencias) / total_winning) * 100
                if total_winning
                else 0.0
            )
            nums = ", ".join(map(str, sorted(coincidencias)))
            nums_suffix = f" ({nums})" if nums else ""
            resumenes.append(
                f"{variant_name}: {len(coincidencias)}/{total_winning}"
                f"{nums_suffix}, {int(round(efectividad))}%"
            )

            if pred_especial_top and variant.get("especiales"):
                aciertos_especiales = set(variant["especiales"]).intersection(
                    pred_especial_top
                )
                if aciertos_especiales:
                    valores = ", ".join(map(str, sorted(aciertos_especiales)))
                    especiales_resumen.append(
                        f"{variant_name} {special_label}: {valores} ✅"
                    )

        # Una sola notificación global por sorteo. Se conserva el tipo
        # 'precision' para que los índices de idempotencia existentes eviten
        # republicar sorteos ya procesados al desplegar esta versión.
        fecha_txt = self._format_fecha_es(fecha)
        unique_names = list(dict.fromkeys(nombres_variantes))
        display = "/".join(unique_names) if len(unique_names) > 1 else nombre_display
        mensaje = (
            f"En el sorteo del {fecha_txt} para {display}, el Top {top_count} "
            f"de la IA logró: " + " | ".join(resumenes) + "."
        )
        if especiales_resumen:
            mensaje += " Especiales: " + " | ".join(especiales_resumen) + "."

        if len(mensaje) > 500:
            mensaje = mensaje[:497].rstrip() + "..."

        self.guardar_notificacion(
            loteria_id,
            fecha,
            mensaje,
            "precision",
            force=force,
        )

    def run(self, loteria: str = "all", force: bool = False) -> None:
        print(
            "🔔 Generador universal de notificaciones "
            f"| referencia={loteria}"
        )

        matches = self._resolve_catalog(loteria)
        if not matches:
            print(
                f"⚠️ No existe en el catálogo una lotería activa que coincida "
                f"con '{loteria}'."
            )
            return

        print(
            f"📚 Catálogo: {len(matches)} lotería(s) resuelta(s) "
            "sin configuración hardcodeada."
        )

        for catalog in matches:
            try:
                self.procesar_loteria(catalog, force=force)
            except Exception as exc:
                nombre = catalog.get("nombre") or catalog.get("route")
                print(f"❌ Error procesando {nombre}: {exc}")
                import traceback
                print(traceback.format_exc())


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Genera notificaciones dinámicas de Eterlotto"
    )
    parser.add_argument(
        "loteria",
        nargs="?",
        default="all",
        help="route o nombre del catálogo. 'all' procesa todas las activas.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Republica aunque ya exista la misma fecha/tipo (solo diagnóstico).",
    )
    args = parser.parse_args()

    NotificationGenerator().run(args.loteria, force=args.force)
