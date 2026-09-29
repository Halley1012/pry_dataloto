import sys
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


def _date(value: Any):
    if value is None:
        return None
    try:
        return pd.Timestamp(value).date()
    except Exception:
        return None


def main():
    engine = get_engine()
    inspector = inspect(engine)

    lot_cols = {
        c["name"] for c in inspector.get_columns("loterias", schema="public")
    }
    wanted = ["id", "nombre", "route", "proximo_sorteo", "activa"]
    selected = [c for c in wanted if c in lot_cols]

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
        catalog_next = _date(lot.get("proximo_sorteo"))

        result_table = f"resultados_{route}" if route else None
        last_real = None
        placeholder = None

        if result_table and result_table in tables:
            cols = {
                c["name"]
                for c in inspector.get_columns(result_table, schema="public")
            }
            clauses = []
            params = {}

            if "loteria_id" in cols:
                clauses.append("loteria_id = :lid")
                params["lid"] = lid

            where_base = (
                " WHERE " + " AND ".join(clauses)
                if clauses
                else ""
            )

            if "fecha" in cols:
                # Resultado real: basta con balota1 > 0 cuando existe.
                if "balota1" in cols:
                    real_extra = "COALESCE(balota1, 0) > 0"
                    ph_extra = "COALESCE(balota1, 0) = 0"
                else:
                    real_extra = "TRUE"
                    ph_extra = "FALSE"

                real_where = list(clauses) + [real_extra]
                ph_where = list(clauses) + [ph_extra]

                with engine.connect() as conn:
                    last_real = _date(
                        conn.execute(
                            text(
                                f'SELECT MAX(fecha) FROM "{result_table}" '
                                + (
                                    "WHERE " + " AND ".join(real_where)
                                    if real_where else ""
                                )
                            ),
                            params,
                        ).scalar()
                    )

                    if "balota1" in cols:
                        placeholder = _date(
                            conn.execute(
                                text(
                                    f'SELECT MAX(fecha) FROM "{result_table}" '
                                    + (
                                        "WHERE " + " AND ".join(ph_where)
                                        if ph_where else ""
                                    )
                                ),
                                params,
                            ).scalar()
                        )

        latest_pred = None
        if pred_exists and route:
            with engine.connect() as conn:
                latest_pred = _date(
                    conn.execute(
                        text("""
                            SELECT MAX(fecha)
                            FROM predicciones
                            WHERE (
                                loteria_id = :lid
                                OR LOWER(TRIM(loteria_route)) = :route
                            )
                        """),
                        {"lid": lid, "route": route},
                    ).scalar()
                )

        flags = []

        if catalog_next and latest_pred and latest_pred != catalog_next:
            if latest_pred < catalog_next:
                flags.append("PREDICCION_ATRASADA")
            else:
                flags.append("CATALOGO_ATRASADO")

        if catalog_next and placeholder and placeholder != catalog_next:
            flags.append("PLACEHOLDER_DISTINTO")

        if placeholder and latest_pred and placeholder != latest_pred:
            flags.append("PREDICCION_PLACEHOLDER_DISTINTOS")

        if latest_pred and last_real and latest_pred <= last_real:
            flags.append("PREDICCION_NO_FUTURA")

        rows.append({
            "id": lid,
            "loteria": nombre,
            "route": route,
            "ultimo_real": last_real,
            "placeholder": placeholder,
            "catalogo_proximo": catalog_next,
            "ultima_prediccion": latest_pred,
            "estado": "OK" if not flags else " | ".join(flags),
        })

    df = pd.DataFrame(rows)

    print("\n================ AUDITORÍA DE FECHAS ETERLOTTO ================\n")

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
                    "placeholder",
                    "catalogo_proximo",
                    "ultima_prediccion",
                    "estado",
                ]
            ].to_string(index=False)
        )

    print("\n---------------- RESUMEN COMPLETO ----------------")
    print(
        df[
            [
                "id",
                "loteria",
                "ultimo_real",
                "placeholder",
                "catalogo_proximo",
                "ultima_prediccion",
                "estado",
            ]
        ].to_string(index=False)
    )

    print("\n===============================================================\n")


if __name__ == "__main__":
    main()
