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

class DoublePlayPredictor:
    def __init__(self):
        self.max_white_ball = 69
        self.max_special_ball = 26

    def run(self):
        print("🔮 Iniciando Predictor Mejorado de Double Play...")
        engine = get_engine()

        try:
            df_all = pd.read_sql(
                'SELECT "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja" '
                'FROM resultados_double_play '
                'ORDER BY fecha ASC;', engine
            )
        except Exception as e:
            print(f"❌ Error consultando resultados Double Play: {e}")
            return

        if df_all.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo de Double Play.")
            return

        df_all["fecha"] = pd.to_datetime(df_all["fecha"])
        fecha_proximo_sorteo = df_all['fecha'].max().strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para Double Play: {fecha_proximo_sorteo}")

        df = df_all[df_all['balota1'] > 0].copy().reset_index(drop=True)
        if df.empty:
            print("⚠️ No hay suficientes resultados históricos reales para entrenar.")
            return

        num_draws = len(df)
        matrix = np.zeros((num_draws, self.max_white_ball + 1), dtype=int)
        balls_array = df[['balota1', 'balota2', 'balota3', 'balota4', 'balota5']].values

        for idx, row_balls in enumerate(balls_array):
            for b in row_balls:
                if 1 <= b <= self.max_white_ball:
                    matrix[idx, int(b)] = 1

        t_idx = num_draws
        t_dt = pd.to_datetime(fecha_proximo_sorteo)

        num_probs = {}
        raw_scores = {}

        def build_features_for_number(n, max_k):
            rows = []
            targets = []
            start_k = max(0, max_k - 400)
            for k in range(start_k + 30, max_k):
                sub = matrix[:k, n]
                seen = np.where(sub == 1)[0]
                recency = (k - seen[-1]) if len(seen) > 0 else 100
                f5 = np.sum(sub[-5:]) if k >= 5 else np.sum(sub)
                f10 = np.sum(sub[-10:]) if k >= 10 else np.sum(sub)
                f20 = np.sum(sub[-20:]) if k >= 20 else np.sum(sub)
                f50 = np.sum(sub[-50:]) if k >= 50 else np.sum(sub)
                decay = np.sum(sub * np.exp(-0.03 * (k - 1 - np.arange(k))))
                d_dt = df.iloc[k]['fecha']

                rows.append({
                    'recency': recency,
                    'f5': f5,
                    'f10': f10,
                    'f20': f20,
                    'f50': f50,
                    'decay': decay,
                    'year': d_dt.year,
                    'month': d_dt.month,
                    'day': d_dt.day,
                    'dayofweek': d_dt.dayofweek
                })
                targets.append(matrix[k, n])
            return pd.DataFrame(rows), np.array(targets)

        for n in range(1, self.max_white_ball + 1):
            sub_test = matrix[:t_idx, n]
            seen_t = np.where(sub_test == 1)[0]
            recency_t = (t_idx - seen_t[-1]) if len(seen_t) > 0 else 100
            f5_t = np.sum(sub_test[-5:]) if t_idx >= 5 else np.sum(sub_test)
            f10_t = np.sum(sub_test[-10:]) if t_idx >= 10 else np.sum(sub_test)
            f20_t = np.sum(sub_test[-20:]) if t_idx >= 20 else np.sum(sub_test)
            f50_t = np.sum(sub_test[-50:]) if t_idx >= 50 else np.sum(sub_test)
            decay_t = np.sum(sub_test * np.exp(-0.03 * (t_idx - 1 - np.arange(t_idx))))

            X_train, y_train = build_features_for_number(n, t_idx)

            X_test = pd.DataFrame([{
                'recency': recency_t,
                'f5': f5_t,
                'f10': f10_t,
                'f20': f20_t,
                'f50': f50_t,
                'decay': decay_t,
                'year': t_dt.year,
                'month': t_dt.month,
                'day': t_dt.day,
                'dayofweek': t_dt.dayofweek
            }])

            if len(y_train) == 0 or len(np.unique(y_train)) < 2:
                num_probs[n] = 0.0
            else:
                model = XGBClassifier(
                    n_estimators=100,
                    learning_rate=0.05,
                    max_depth=2,
                    subsample=0.8,
                    colsample_bytree=0.8,
                    eval_metric='logloss',
                    random_state=42
                )
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

        # --- MODELO 2: Powerball ---
        pb_series = df['balotaroja'].values
        pb_freq = {}
        for r in range(1, self.max_special_ball + 1):
            pb_sub = (pb_series[:t_idx] == r).astype(int)
            pb_f20 = np.sum(pb_sub[-20:]) if t_idx >= 20 else np.sum(pb_sub)
            pb_decay = np.sum(pb_sub * np.exp(-0.03 * (t_idx - 1 - np.arange(t_idx))))
            pb_freq[r] = pb_f20 + pb_decay

        pb_scores = pd.DataFrame.from_dict(pb_freq, orient='index', columns=['Score']).sort_values('Score', ascending=False)
        rojaprediccion = pb_scores.index.tolist()

        try:
            engine.dispose()
            conn = engine.connect()

            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS predicciones_double_play (
                    id SERIAL PRIMARY KEY,
                    fecha DATE UNIQUE NOT NULL,
                    numeros INT[],
                    balotaroja INT[]
                );
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones_double_play (fecha, numeros, balotaroja)
                VALUES (:fecha, :numeros, :balotaroja)
                ON CONFLICT (fecha) DO UPDATE
                SET numeros = EXCLUDED.numeros,
                    balotaroja = EXCLUDED.balotaroja;
            """), {"fecha": fecha_proximo_sorteo, "numeros": numeros_prediccion, "balotaroja": rojaprediccion})
            conn.commit()

            print(f"✅ Predicción de Double Play guardada exitosamente para la fecha del próximo sorteo: {fecha_proximo_sorteo}")
            print(f"Top 20 números con mayor probabilidad: {numeros_prediccion[:20]}")
            print(f"Top Powerball propuesta: {rojaprediccion[:5]}")

        except Exception as e:
            print(f"❌ Error al guardar predicciones de Double Play en BD: {e}")
        finally:
            conn.close()

if __name__ == "__main__":
    DoublePlayPredictor().run()
