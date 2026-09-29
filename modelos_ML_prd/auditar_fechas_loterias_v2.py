import sys
from datetime import date
from pathlib import Path
from typing import Any

import pandas as pd
from sqlalchemy import inspect, text

PROJECT_ROOT = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

from config.database import get_engine


def _as_date(value: Any):
    if value is None:
        return None
    try:
        return pd.Timestamp(value).date()
    except Exception:
        return None


def _as_int(value: Any):
    try:
        if value is None or pd.isna(value):
            return None
        return int(value)
    except Exception:
        return None


def main():
    engine = get_engine()
    inspector = inspect(engine)
    today = date.today()

    lot_cols = {
        c["name"] for c in inspector.get_columns("loterias", schema="public")
    }
    selected = [
        c for c in ("id", "nombre", "route", "proximo_sorteo", "activa")
        if c in lot_cols
    ]

    sql = "SELECT " + ", ".join(selected) + " FROM loterias"
    if "activa" in lot_cols:
        sql += " WHERE COALESCE(activa, TRUE) = TRUE"
    sql += " ORDER BY id"

    with engine.connect() as conn:
        loterias = [dict(r) for r in conn.execute(text(sql)).mappings().all()]

    tables = set(inspector.get_table_names(schema="public"))
    pred_exists = "predicciones" in tables
    rows = []

    for lot in loterias:
        lid = int(lot["id"])
        nombre = str(lot.get("nombre") or "")
        route = str(lot.get("route") or "").strip().lower()
        catalog_next = _as_date(lot.get("proximo_sorteo"))

        result_table = f"resultados_{route}" if route else None

        last_real = None
        last_real_concurso = None
        placeholder = None
        placeholder_concurso = None

        if result_table and result_table in tables:
            cols = {
                c["name"]
                for c in inspector.get_columns(result_table, schema="public")
            }

            params = {}
            identity_clause = ""
            if "loteria_id" in cols:
                identity_clause = " AND loteria_id = :lid"
                params["lid"] = lid

            order_cols = []
            if "concurso" in cols:
                order_cols.append("concurso DESC NULLS LAST")
            if "fecha" in cols:
                order_cols.append("fecha DESC")
            order_sql = ", ".join(order_cols) if order_cols else "1"

            select_concurso = "concurso" if "concurso" in cols else "NULL AS concurso"

            if "fecha" in cols and "balota1" in cols:
                sql_real = (
                    f'SELECT fecha, {select_concurso} '
                    f'FROM "{result_table}" '
                    f'WHERE COALESCE(balota1, 0) > 0{identity_clause} '
                    f'ORDER BY {order_sql} LIMIT 1'
                )
                sql_ph = (
                    f'SELECT fecha, {select_concurso} '
                    f'FROM "{result_table}" '
                    f'WHERE COALESCE(balota1, 0) = 0{identity_clause} '
                    f'ORDER BY {order_sql} LIMIT 1'
                )

                with engine.connect() as conn:
                    real = conn.execute(text(sql_real), params).mappings().first()
                    ph = conn.execute(text(sql_ph), params).mappings().first()

                if real:
                    last_real = _as_date(real.get("fecha"))
                    last_real_concurso = _as_int(real.get("concurso"))
                if ph:
                    placeholder = _as_date(ph.get("fecha"))
                    placeholder_concurso = _as_int(ph.get("concurso"))

        latest_pred = None
        if pred_exists and route:
            with engine.connect() as conn:
                latest_pred = _as_date(
                    conn.execute(
                        text(
                            "SELECT MAX(fecha) "
                            "FROM predicciones "
                            "WHERE loteria_id = :lid "
                            "   OR LOWER(TRIM(loteria_route)) = :route"
                        ),
                        {"lid": lid, "route": route},
                    ).scalar()
                )

        flags = []

        # El placeholder es la fecha objetivo canónica.
        if placeholder and latest_pred and latest_pred != placeholder:
            flags.append("PREDICCION_PLACEHOLDER_DISTINTOS")

        # Detecta una lotería estancada aunque placeholder y predicción coincidan.
        if placeholder and placeholder < today:
            flags.append("PLACEHOLDER_VENCIDO")

        if latest_pred and latest_pred < today and not placeholder:
            flags.append("PREDICCION_VENCIDA")

        # Puede haber dos sorteos el mismo día (ej. Chispazo). En ese caso
        # placeholder==último_real es válido si el concurso del placeholder
        # es posterior al concurso real.
        same_day_next_contest = (
            placeholder is not None
            and last_real is not None
            and placeholder == last_real
            and placeholder_concurso is not None
            and last_real_concurso is not None
            and placeholder_concurso > last_real_concurso
        )

        if latest_pred and last_real and latest_pred <= last_real:
            if not (latest_pred == placeholder and same_day_next_contest):
                flags.append("PREDICCION_NO_FUTURA")

        if catalog_next and placeholder and catalog_next != placeholder:
            flags.append("CATALOGO_PLACEHOLDER_DISTINTOS")

        rows.append({
            "id": lid,
            "loteria": nombre,
            "route": route,
            "ultimo_real": last_real,
            "concurso_real": last_real_concurso,
            "placeholder": placeholder,
            "concurso_placeholder": placeholder_concurso,
            "catalogo_proximo": catalog_next,
            "ultima_prediccion": latest_pred,
            "estado": "OK" if not flags else " | ".join(flags),
        })

    df = pd.DataFrame(rows)

    print("\n================ AUDITORÍA DE FECHAS ETERLOTTO V2 ================\n")
    print(f"Fecha de auditoría: {today}")

    if df.empty:
        print("No se encontraron loterías activas.")
        return

    problem = df[df["estado"] != "OK"].copy()
    ok = df[df["estado"] == "OK"].copy()

    print(f"Loterías revisadas: {len(df)}")
    print(f"Sin inconsistencias detectadas: {len(ok)}")
    print(f"Para revisar: {len(problem)}")

    if not problem.empty:
        print("\n---------------- INCONSISTENCIAS ----------------")
        print(
            problem[
                [
                    "id",
                    "loteria",
                    "route",
                    "ultimo_real",
                    "concurso_real",
                    "placeholder",
                    "concurso_placeholder",
                    "ultima_prediccion",
                    "estado",
                ]
            ].to_string(index=False)
        )

    print("\nNOTAS:")
    print("- placeholder es la fecha objetivo canónica de la predicción.")
    print("- placeholder == último_real puede ser válido si es el concurso siguiente del mismo día.")
    print("- PLACEHOLDER_VENCIDO detecta loterías detenidas en fechas antiguas.")
    print("- catalogo_proximo solo se compara cuando la BD realmente contiene ese valor.")
    print("\n==================================================================\n")


if __name__ == "__main__":
    main()
