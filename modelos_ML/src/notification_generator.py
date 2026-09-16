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

    def _fetch_latest_result_from_table(
        self,
        table: str,
        *,
        loteria_id: int,
        require_loteria_id: bool,
    ) -> dict[str, Any] | None:
        columns = self._table_columns(table)
        if "fecha" not in columns:
            return None

        clauses = []
        params: dict[str, Any] = {}

        if "balota1" in columns:
            clauses.append("COALESCE(balota1, 0) > 0")

        if require_loteria_id:
            if "loteria_id" not in columns:
                return None
            clauses.append("loteria_id = :loteria_id")
            params["loteria_id"] = int(loteria_id)

        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        sql = text(
            f'SELECT * FROM "{table}"'
            f"{where} ORDER BY fecha DESC LIMIT 1"
        )

        with self.engine.connect() as conn:
            row = conn.execute(sql, params).mappings().first()

        return dict(row) if row else None

    def _latest_result(
        self,
        *,
        loteria_id: int,
        route: str,
    ) -> tuple[str, dict[str, Any]] | tuple[None, None]:
        """
        1) Busca por loteria_id en cualquier resultados_*.
        2) Como compatibilidad para datasets compartidos, usa resultados_<route>
           si no existe fila concreta por ID.

        No existen filtros del tipo sorteo='Baloto', nombres o IDs fijos.
        """
        result_tables = self._result_tables()
        preferred = f"resultados_{route.strip().lower()}"

        ordered = []
        if preferred in result_tables:
            ordered.append(preferred)
        ordered.extend(table for table in result_tables if table != preferred)

        # Identidad concreta primero.
        for table in ordered:
            row = self._fetch_latest_result_from_table(
                table,
                loteria_id=loteria_id,
                require_loteria_id=True,
            )
            if row:
                return table, row

        # Compatibilidad: route como dataset compartido.
        if preferred in result_tables:
            row = self._fetch_latest_result_from_table(
                preferred,
                loteria_id=loteria_id,
                require_loteria_id=False,
            )
            if row:
                return preferred, row

        return None, None

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

    @staticmethod
    def _winning_special_numbers(result: dict[str, Any]) -> set[int]:
        values: set[int] = set()
        for column, value in result.items():
            if column.lower().startswith("balotaroja"):
                values.update(NotificationGenerator._as_int_list(value))
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
                return min(
                    int(math.ceil(int(max_white) / 2)),
                    len(pred_nums),
                )
        except (TypeError, ValueError):
            pass

        # Último fallback técnico: usa la mitad del ranking realmente guardado.
        return max(1, int(math.ceil(len(pred_nums) / 2)))

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
        ganadores: set[int],
        force: bool = False,
    ) -> None:
        if not ganadores:
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
            print(
                f"⚠️ No se pudieron consultar jugadas de {nombre_display}: {exc}"
            )
            return

        if jugadas.empty:
            return

        total_resultado = len(ganadores)

        for user_id, grupo in jugadas.groupby("user_id"):
            mejor_aciertos: set[int] = set()
            cantidad_jugadas = 0

            for _, row in grupo.iterrows():
                numeros = set(self._as_int_list(row.get("numeros")))
                if not numeros:
                    continue

                cantidad_jugadas += 1
                aciertos = numeros.intersection(ganadores)
                if len(aciertos) > len(mejor_aciertos):
                    mejor_aciertos = aciertos

            # 0 aciertos no genera push.
            if not mejor_aciertos:
                continue

            cantidad = len(mejor_aciertos)
            numeros_txt = ", ".join(map(str, sorted(mejor_aciertos)))

            if cantidad_jugadas > 1:
                mensaje = (
                    f"🎯 En tus jugadas de {nombre_display}, tu mejor combinación "
                    f"acertó {cantidad} de {total_resultado} números "
                    f"({numeros_txt}) con el resultado del sorteo."
                )
            else:
                mensaje = (
                    f"🎯 En tu jugada de {nombre_display} acertaste "
                    f"{cantidad} de {total_resultado} números "
                    f"({numeros_txt}) con el resultado del sorteo."
                )

            self._publicar_notificacion_usuario(
                user_id=int(user_id),
                loteria_id=int(loteria_id),
                fecha=fecha,
                mensaje=mensaje,
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

        table, result = self._latest_result(
            loteria_id=loteria_id,
            route=route,
        )
        if not result:
            print(
                f"ℹ️ Sin resultado válido para {nombre_display} "
                f"(loteria_id={loteria_id}, route={route})."
            )
            return

        fecha = result.get("fecha")
        if fecha is None:
            print(f"⚠️ Resultado sin fecha para {nombre_display}; se omite.")
            return

        try:
            expected_white = int(catalog.get("max_seleccion") or 0) or None
        except (TypeError, ValueError):
            expected_white = None

        ganadores = self._winning_white_numbers(
            result,
            expected_count=expected_white,
        )
        if not ganadores:
            print(
                f"⚠️ {table}: no fue posible obtener balotas ganadoras "
                f"para {nombre_display}."
            )
            return

        especiales_ganadores = self._winning_special_numbers(result)

        # Resultado real de las jugadas: independiente de la predicción IA.
        self.notificar_aciertos_jugadas(
            loteria_id=loteria_id,
            nombre_display=nombre_display,
            fecha=fecha,
            ganadores=ganadores,
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
        coincidencias = ganadores.intersection(top_probables)

        # A. Acierto parcial
        if len(coincidencias) >= self.partial_hit_min:
            nums_str = ", ".join(map(str, sorted(coincidencias)))
            mensaje = (
                f"¡Casi! De los {top_count} números con mayor probabilidad "
                f"generados por la IA para {nombre_display}, cayeron "
                f"{len(coincidencias)} números ({nums_str})."
            )
            self.guardar_notificacion(
                loteria_id,
                fecha,
                mensaje,
                "acierto_parcial",
                force=force,
            )

        # B. Especial: completamente genérico.
        if especiales_ganadores and pred_special:
            cantidad_especiales = len(especiales_ganadores)
            pred_especial_top = set(pred_special[:cantidad_especiales])
            aciertos_especiales = especiales_ganadores.intersection(
                pred_especial_top
            )

            if aciertos_especiales:
                label = str(
                    catalog.get("superbalota_nombre")
                    or "número especial"
                ).strip()
                valores = ", ".join(
                    map(str, sorted(aciertos_especiales))
                )

                if len(aciertos_especiales) == 1:
                    mensaje = (
                        f"¡La IA acertó {label} ({valores}) en el sorteo "
                        f"de {nombre_display}!"
                    )
                else:
                    mensaje = (
                        f"¡La IA acertó {len(aciertos_especiales)} números "
                        f"especiales ({valores}) en el sorteo "
                        f"de {nombre_display}!"
                    )

                self.guardar_notificacion(
                    loteria_id,
                    fecha,
                    mensaje,
                    "acierto_directo",
                    force=force,
                )

        # C. Precisión general
        total_winning = len(ganadores)
        efectividad = (
            (len(coincidencias) / total_winning) * 100
            if total_winning
            else 0.0
        )
        mensaje = (
            f"En el sorteo de {nombre_display}, los {top_count} números "
            f"más probables tuvieron una efectividad del "
            f"{int(round(efectividad))}% "
            f"({len(coincidencias)} de {total_winning} aciertos)."
        )
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
