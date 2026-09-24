import argparse
import math
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import text
from xgboost import XGBClassifier

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

from config.database import get_engine


FEATURES = ["Año", "Mes", "Día", "dia_semana"]

GAMES = {
    "baloto": {
        "table": "resultados_bloto",
        "where": "sorteo = 'Baloto' AND balota1 > 0",
        "max_number": 43,
        "topks": [5, 10, 15, 20, 21],
        "label": "Baloto",
    },
    "miloto": {
        "table": "resultados_mloto",
        "where": "balota1 > 0",
        "max_number": 39,
        "topks": [5, 10, 15, 20],
        "label": "MiLoto",
    },
}


def _prepare(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["fecha"] = pd.to_datetime(df["fecha"], errors="coerce")
    df = df.dropna(subset=["fecha"]).sort_values("fecha").reset_index(drop=True)

    for col in ["balota1", "balota2", "balota3", "balota4", "balota5"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df = df.dropna(subset=["balota1", "balota2", "balota3", "balota4", "balota5"])
    df["Año"] = df["fecha"].dt.year
    df["Mes"] = df["fecha"].dt.month
    df["Día"] = df["fecha"].dt.day
    df["dia_semana"] = df["fecha"].dt.dayofweek
    return df


def _winner_set(row) -> set[int]:
    return {
        int(row["balota1"]),
        int(row["balota2"]),
        int(row["balota3"]),
        int(row["balota4"]),
        int(row["balota5"]),
    }


def _binary_matrix(df: pd.DataFrame, max_number: int) -> pd.DataFrame:
    values = df[["balota1", "balota2", "balota3", "balota4", "balota5"]].to_numpy(dtype=int)
    data = {}
    for n in range(1, max_number + 1):
        data[n] = (values == n).any(axis=1).astype(np.int8)
    return pd.DataFrame(data, index=df.index)


def _xgb_ranking(train: pd.DataFrame, target: pd.Series, max_number: int) -> list[int]:
    """
    Replica el enfoque del predictor actual:
    - 1 clasificador binario por número.
    - Features: Año, Mes, Día, dia_semana.
    - Mismos hiperparámetros principales.
    """
    X_train = train[FEATURES]
    X_future = pd.DataFrame([{
        "Año": int(target["fecha"].year),
        "Mes": int(target["fecha"].month),
        "Día": int(target["fecha"].day),
        "dia_semana": int(target["fecha"].dayofweek),
    }], columns=FEATURES)

    binary = _binary_matrix(train, max_number)
    probs = {}

    for n in range(1, max_number + 1):
        y_train = binary[n]

        # Si históricamente solo existe una clase, asignamos probabilidad extrema
        # sin intentar entrenar XGBoost.
        if y_train.nunique() < 2:
            probs[n] = float(y_train.iloc[-1]) if len(y_train) else 0.0
            continue

        model = XGBClassifier(
            n_estimators=100,
            learning_rate=0.1,
            max_depth=1,
            subsample=0.8,
            colsample_bytree=0.5,
            gamma=1,
            reg_alpha=0.1,
            reg_lambda=1,
            eval_metric="logloss",
            random_state=42,
            n_jobs=1,
        )
        model.fit(X_train, y_train)
        probs[n] = float(model.predict_proba(X_future)[0, 1])

    return sorted(probs, key=probs.get, reverse=True)


def _frequency_ranking(train: pd.DataFrame, max_number: int, window: int | None = None) -> list[int]:
    subset = train.tail(window) if window else train
    binary = _binary_matrix(subset, max_number)
    counts = binary.sum(axis=0)

    # Desempate determinista por número ascendente.
    return sorted(
        range(1, max_number + 1),
        key=lambda n: (-int(counts.get(n, 0)), n),
    )


def _hypergeom_prob_at_least(total_numbers: int, winners: int, selected: int, minimum_hits: int) -> float:
    denom = math.comb(total_numbers, selected)
    if denom == 0:
        return 0.0

    probability = 0.0
    max_hits = min(winners, selected)
    for h in range(minimum_hits, max_hits + 1):
        if selected - h > total_numbers - winners:
            continue
        probability += (
            math.comb(winners, h)
            * math.comb(total_numbers - winners, selected - h)
            / denom
        )
    return probability


def _random_baseline(total_numbers: int, k: int) -> dict:
    return {
        "avg_hits": 5.0 * k / total_numbers,
        "coverage_pct": 100.0 * k / total_numbers,
        "pct_3plus": 100.0 * _hypergeom_prob_at_least(total_numbers, 5, k, 3),
        "pct_4plus": 100.0 * _hypergeom_prob_at_least(total_numbers, 5, k, 4),
        "pct_5": 100.0 * _hypergeom_prob_at_least(total_numbers, 5, k, 5),
    }


def _summarize(details: pd.DataFrame, game_cfg: dict) -> pd.DataFrame:
    rows = []
    max_number = game_cfg["max_number"]

    for method in ["xgboost_actual", "frecuencia_total", "frecuencia_20"]:
        for k in game_cfg["topks"]:
            col = f"{method}_top{k}"
            hits = details[col]
            avg_hits = float(hits.mean())
            coverage_pct = avg_hits / 5.0 * 100.0
            random = _random_baseline(max_number, k)

            rows.append({
                "metodo": method,
                "top_k": k,
                "sorteos": int(len(hits)),
                "prom_aciertos": round(avg_hits, 3),
                "coverage_pct": round(coverage_pct, 2),
                "pct_3plus": round(float((hits >= 3).mean() * 100.0), 2),
                "pct_4plus": round(float((hits >= 4).mean() * 100.0), 2),
                "pct_5": round(float((hits == 5).mean() * 100.0), 2),
                "azar_prom_aciertos": round(random["avg_hits"], 3),
                "azar_coverage_pct": round(random["coverage_pct"], 2),
                "lift_vs_azar": round(
                    coverage_pct / random["coverage_pct"]
                    if random["coverage_pct"] else 0.0,
                    3,
                ),
            })

    return pd.DataFrame(rows)


def evaluate_game(engine, game_key: str, max_evals: int, min_train: int) -> tuple[pd.DataFrame, pd.DataFrame]:
    cfg = GAMES[game_key]
    query = text(f"""
        SELECT fecha, balota1, balota2, balota3, balota4, balota5
        FROM {cfg['table']}
        WHERE {cfg['where']}
        ORDER BY fecha ASC
    """)

    with engine.connect() as conn:
        df = pd.read_sql(query, conn)

    df = _prepare(df)

    if len(df) <= min_train:
        raise RuntimeError(
            f"{cfg['label']}: solo hay {len(df)} sorteos reales; "
            f"se necesitan más de {min_train}."
        )

    start_idx = max(min_train, len(df) - max_evals)
    eval_indices = list(range(start_idx, len(df)))

    print("")
    print("============================================================")
    print(f"🎯 {cfg['label']}")
    print(f"Histórico real disponible: {len(df)} sorteos")
    print(f"Entrenamiento mínimo: {min_train}")
    print(f"Sorteos evaluados walk-forward: {len(eval_indices)}")
    print(f"Universo: 1..{cfg['max_number']}")
    print("============================================================")

    records = []
    started = time.time()

    for position, idx in enumerate(eval_indices, start=1):
        train = df.iloc[:idx].copy()
        target = df.iloc[idx]
        winners = _winner_set(target)

        xgb_rank = _xgb_ranking(train, target, cfg["max_number"])
        freq_all_rank = _frequency_ranking(train, cfg["max_number"], window=None)
        freq20_rank = _frequency_ranking(train, cfg["max_number"], window=20)

        record = {
            "fecha": target["fecha"].date(),
            "ganadores": ",".join(str(x) for x in sorted(winners)),
        }

        for method, ranking in [
            ("xgboost_actual", xgb_rank),
            ("frecuencia_total", freq_all_rank),
            ("frecuencia_20", freq20_rank),
        ]:
            for k in cfg["topks"]:
                record[f"{method}_top{k}"] = len(winners.intersection(ranking[:k]))

        records.append(record)

        if position == 1 or position % 10 == 0 or position == len(eval_indices):
            elapsed = time.time() - started
            print(
                f"[{position:>3}/{len(eval_indices)}] "
                f"{target['fecha'].date()} | "
                f"transcurrido={elapsed/60:.1f} min"
            )

    details = pd.DataFrame(records)
    summary = _summarize(details, cfg)
    return details, summary


def print_focus(summary: pd.DataFrame, game_key: str):
    cfg = GAMES[game_key]
    focus_k = 21 if game_key == "baloto" else 20

    focus = summary[summary["top_k"] == focus_k].copy()
    print("")
    print(f"---------------- OBJETIVO {cfg['label']}: TOP {focus_k} ----------------")
    print(
        focus[
            [
                "metodo",
                "sorteos",
                "prom_aciertos",
                "coverage_pct",
                "pct_3plus",
                "pct_4plus",
                "pct_5",
                "azar_prom_aciertos",
                "azar_coverage_pct",
                "lift_vs_azar",
            ]
        ].to_string(index=False)
    )


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Backtest temporal de Baloto/MiLoto. "
            "No inserta, actualiza ni elimina datos."
        )
    )
    parser.add_argument(
        "--game",
        choices=["baloto", "miloto", "both"],
        default="both",
        help="Juego a evaluar.",
    )
    parser.add_argument(
        "--max-evals",
        type=int,
        default=60,
        help="Cantidad máxima de sorteos recientes a evaluar por juego (default: 60).",
    )
    parser.add_argument(
        "--min-train",
        type=int,
        default=100,
        help="Sorteos mínimos previos antes de empezar el backtest (default: 100).",
    )
    parser.add_argument(
        "--save-csv",
        action="store_true",
        help="Guarda detalle y resumen en evaluacion/resultados/.",
    )
    args = parser.parse_args()

    print("🔬 BACKTEST ETERLOTTO - SOLO LECTURA")
    print("No modifica resultados, predicciones ni ninguna tabla.")

    engine = get_engine()
    games = ["baloto", "miloto"] if args.game == "both" else [args.game]

    out_dir = Path(__file__).resolve().parent / "resultados"
    if args.save_csv:
        out_dir.mkdir(parents=True, exist_ok=True)

    for game in games:
        details, summary = evaluate_game(
            engine=engine,
            game_key=game,
            max_evals=args.max_evals,
            min_train=args.min_train,
        )

        print("")
        print(f"================ RESUMEN {GAMES[game]['label']} ================")
        print(summary.to_string(index=False))
        print_focus(summary, game)

        if args.save_csv:
            details.to_csv(out_dir / f"{game}_detalle.csv", index=False)
            summary.to_csv(out_dir / f"{game}_resumen.csv", index=False)
            print(f"💾 CSV guardados en: {out_dir}")

    engine.dispose()
    print("")
    print("✅ Backtest terminado. Base de datos sin modificaciones.")


if __name__ == "__main__":
    main()
