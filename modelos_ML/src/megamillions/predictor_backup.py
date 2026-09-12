import sys
from pathlib import Path
import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sqlalchemy import text

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class MegaMillionsPredictor:
    def __init__(self):
        self.max_white_ball = 70
        self.max_special_ball = 25

    def run(self):
        print("🔮 Iniciando Predictor Mejorado de Mega Millions...")
        engine = get_engine()

        try:
            df_all = pd.read_sql(
                'SELECT "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja" '
                'FROM resultados_megamillions '
                'ORDER BY fecha ASC;', engine
            )
        except Exception as e:
            print(f"❌ Error consultando resultados Mega Millions: {e}")
            return

        if df_all.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo de Mega Millions.")
            return

        df_all["fecha"] = pd.to_datetime(df_all["fecha"])
        fecha_proximo_sorteo = df_all['fecha'].max().strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para Mega Millions: {fecha_proximo_sorteo}")

        df = df_all[df_all['balota1'] > 0].copy().reset_index(drop=True)
        if df.empty:
            print("⚠️ No hay suficientes resultados históricos reales para entrenar.")
            return

        num_draws = len(df)
        matrix = np.zeros((num_draws, self.max_white_ball + 1), dtype=np.int8)
        balls_array = df[['balota1', 'balota2', 'balota3', 'balota4', 'balota5']].values

        for idx, row_balls in enumerate(balls_array):
            for b in row_balls:
                if 1 <= b <= self.max_white_ball:
                    matrix[idx, int(b)] = 1

        t_idx = num_draws
        t_dt = pd.to_datetime(fecha_proximo_sorteo)

        num_probs = {}
        raw_scores = {}

        def build_features_vectorized(col, max_k):
            """Construye features en O(k) usando cumsum incremental y decay incremental."""
            cumsum = np.zeros(max_k + 1, dtype=np.int32)
            cumsum[1:] = np.cumsum(col)

            alpha = np.exp(-0.03)
            decay_arr = np.zeros(max_k + 1)
            for i in range(max_k):
                decay_arr[i + 1] = alpha * decay_arr[i] + col[i]

            last_seen = np.full(max_k + 1, -1, dtype=np.int32)
            for i in range(max_k):
                last_seen[i + 1] = i if col[i] == 1 else last_seen[i]
            indices = np.arange(max_k + 1)
            recency_full = np.where(last_seen >= 0, indices - last_seen, 100)

            start_k = max(0, max_k - 400)
            k_range = np.arange(start_k + 30, max_k)
            if len(k_range) == 0:
                return pd.DataFrame(), np.array([])

            f5  = cumsum[k_range] - cumsum[np.maximum(0, k_range - 5)]
            f10 = cumsum[k_range] - cumsum[np.maximum(0, k_range - 10)]
            f20 = cumsum[k_range] - cumsum[np.maximum(0, k_range - 20)]
            f50 = cumsum[k_range] - cumsum[np.maximum(0, k_range - 50)]
            fechas = df['fecha'].iloc[k_range]

            X = pd.DataFrame({
                'recency'   : recency_full[k_range],
                'f5'        : f5,
                'f10'       : f10,
                'f20'       : f20,
                'f50'       : f50,
                'decay'     : decay_arr[k_range],
                'year'      : fechas.dt.year.values,
                'month'     : fechas.dt.month.values,
                'day'       : fechas.dt.day.values,
                'dayofweek' : fechas.dt.dayofweek.values,
            })
            y = col[k_range]
            return X, y

        xgb_params = dict(
            n_estimators=100,
            learning_rate=0.05,
            max_depth=2,
            subsample=0.8,
            colsample_bytree=0.8,
            eval_metric='logloss',
            random_state=42,
            n_jobs=-1,
        )

        for n in range(1, self.max_white_ball + 1):
            col = matrix[:t_idx, n]

            X_train, y_train = build_features_vectorized(col, t_idx)

            cumsum_t = np.concatenate([[0], np.cumsum(col)])
            alpha = np.exp(-0.03)
            decay_t = 0.0
            for j in range(t_idx):
                decay_t = alpha * decay_t + col[j]

            seen_t = np.where(col == 1)[0]
            recency_t = (t_idx - seen_t[-1]) if len(seen_t) > 0 else 100
            f5_t  = int(cumsum_t[t_idx] - cumsum_t[max(0, t_idx - 5)])
            f10_t = int(cumsum_t[t_idx] - cumsum_t[max(0, t_idx - 10)])
            f20_t = int(cumsum_t[t_idx] - cumsum_t[max(0, t_idx - 20)])
            f50_t = int(cumsum_t[t_idx] - cumsum_t[max(0, t_idx - 50)])

            X_test = pd.DataFrame([{
                'recency'   : recency_t,
                'f5'        : f5_t,
                'f10'       : f10_t,
                'f20'       : f20_t,
                'f50'       : f50_t,
                'decay'     : decay_t,
                'year'      : t_dt.year,
                'month'     : t_dt.month,
                'day'       : t_dt.day,
                'dayofweek' : t_dt.dayofweek,
            }])

            if len(y_train) == 0 or len(np.unique(y_train)) < 2:
                num_probs[n] = 0.0
            else:
                model = XGBClassifier(**xgb_params)
                model.fit(X_train, y_train)
                num_probs[n] = float(model.predict_proba(X_test)[0, 1])

            raw_scores[n] = f20_t + decay_t

        max_raw = max(raw_scores.values()) if max(raw_scores.values()) > 0 else 1.0
        hybrid_probs = {}
        for n in range(1, self.max_white_ball + 1):
            hybrid_probs[n] = 0.6 * num_probs[n] + 0.4 * (raw_scores[n] / max_raw)

        df_pred_reg = pd.DataFrame.from_dict(hybrid_probs, orient='index', columns=['Probabilidad'])
        df_pred_reg = df_pred_reg.sort_values('Probabilidad', ascending=False)
        numeros_prediccion = df_pred_reg.index.tolist()

        # --- MODELO 2: Mega Ball ---
        pb_series = df['balotaroja'].values
        pb_freq = {}
        for r in range(1, self.max_special_ball + 1):
            pb_sub = (pb_series[:t_idx] == r).astype(np.int8)
            pb_f20 = int(np.sum(pb_sub[-20:])) if t_idx >= 20 else int(np.sum(pb_sub))
            alpha = np.exp(-0.03)
            pb_decay = 0.0
            for j in range(t_idx):
                pb_decay = alpha * pb_decay + pb_sub[j]
            pb_freq[r] = pb_f20 + pb_decay

        pb_scores = pd.DataFrame.from_dict(pb_freq, orient='index', columns=['Score']).sort_values('Score', ascending=False)
        rojaprediccion = pb_scores.index.tolist()

        try:
            engine.dispose()
            conn = engine.connect()

            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS predicciones_megamillions (
                    id SERIAL PRIMARY KEY,
                    fecha DATE UNIQUE NOT NULL,
                    numeros INT[],
                    balotaroja INT[]
                );
            """))
            conn.commit()

            conn.execute(text("""
                DELETE FROM predicciones_megamillions 
                WHERE fecha < CURRENT_DATE - INTERVAL '7 days';
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones_megamillions (fecha, numeros, balotaroja)
                VALUES (:fecha, :numeros, :balotaroja)
                ON CONFLICT (fecha) DO UPDATE
                SET numeros = EXCLUDED.numeros,
                    balotaroja = EXCLUDED.balotaroja;
            """), {"fecha": fecha_proximo_sorteo, "numeros": numeros_prediccion, "balotaroja": rojaprediccion})
            conn.commit()

            print(f"✅ Predicción de Mega Millions guardada exitosamente para la fecha del próximo sorteo: {fecha_proximo_sorteo}")
            print(f"Top 20 números con mayor probabilidad: {numeros_prediccion[:20]}")
            print(f"Top Mega Ball propuesta: {rojaprediccion[:5]}")

        except Exception as e:
            print(f"❌ Error al guardar predicciones de Mega Millions en BD: {e}")
        finally:
            conn.close()

if __name__ == "__main__":
    MegaMillionsPredictor().run()
