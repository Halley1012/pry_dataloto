import sys
from pathlib import Path
import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sklearn.ensemble import RandomForestClassifier
from sqlalchemy import text

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine
from src.utils.feature_engineering import build_lottery_features

class MillionaireLifePredictor:
    def __init__(self):
        self.max_white_ball = 58
        self.max_special_ball = 5

    def run(self):
        print("🔮 Iniciando Predictor Avanzado de Millionaire for Life (Feature Engineering + Ensamble ML)...")
        engine = get_engine()

        try:
            df_all = pd.read_sql(
                'SELECT "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja" '
                'FROM resultados_millionaire_life '
                'ORDER BY fecha ASC;', engine
            )
        except Exception as e:
            print(f"❌ Error consultando resultados Millionaire Life: {e}")
            return

        if df_all.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo de Millionaire Life.")
            return

        df_all["fecha"] = pd.to_datetime(df_all["fecha"])
        fecha_proximo_sorteo = df_all['fecha'].max().strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para Millionaire Life: {fecha_proximo_sorteo}")

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

        xgb_params = dict(
            n_estimators=120,
            learning_rate=0.05,
            max_depth=2,
            subsample=0.8,
            colsample_bytree=0.8,
            reg_alpha=0.1,
            reg_lambda=1.0,
            eval_metric='logloss',
            random_state=42,
            n_jobs=1
        )

        rf_params = dict(
            n_estimators=150,
            max_depth=4,
            min_samples_split=4,
            min_samples_leaf=1,
            max_features=0.6,
            random_state=42,
            n_jobs=1
        )

        num_probs_xgb = {}
        num_probs_rf = {}
        raw_scores = {}

        for n in range(1, self.max_white_ball + 1):
            X_train, y_train, X_test = build_lottery_features(
                matrix, df['fecha'], self.max_white_ball, t_idx, n
            )

            col = matrix[:t_idx, n]
            cumsum_t = np.concatenate([[0], np.cumsum(col)])
            alpha = np.exp(-0.03)
            decay_t = 0.0
            for j in range(t_idx):
                decay_t = alpha * decay_t + col[j]

            f20_t = int(cumsum_t[t_idx] - cumsum_t[max(0, t_idx - 20)])
            raw_scores[n] = f20_t + decay_t

            if X_train.empty or len(np.unique(y_train)) < 2:
                num_probs_xgb[n] = 0.0
                num_probs_rf[n] = 0.0
            else:
                # 1. Modelo XGBoost
                model_xgb = XGBClassifier(**xgb_params)
                model_xgb.fit(X_train, y_train)
                num_probs_xgb[n] = float(model_xgb.predict_proba(X_test)[0, 1])

                # 2. Modelo Random Forest
                model_rf = RandomForestClassifier(**rf_params)
                model_rf.fit(X_train, y_train)
                num_probs_rf[n] = float(model_rf.predict_proba(X_test)[0, 1])

        # Normalización y Ensamble Soft-Voting
        max_raw = max(raw_scores.values()) if max(raw_scores.values()) > 0 else 1.0
        hybrid_probs = {}
        for n in range(1, self.max_white_ball + 1):
            score_freq = raw_scores[n] / max_raw
            # Ponderación: 50% XGBoost, 30% Random Forest, 20% Frecuencia/Decay histórico
            hybrid_probs[n] = 0.50 * num_probs_xgb[n] + 0.30 * num_probs_rf[n] + 0.20 * score_freq

        df_pred_reg = pd.DataFrame.from_dict(hybrid_probs, orient='index', columns=['Probabilidad'])
        df_pred_reg = df_pred_reg.sort_values('Probabilidad', ascending=False)
        numeros_prediccion = df_pred_reg.index.tolist()

        # --- MODELO 2: Balota Especial (Lucky Ball 1-5) ---
        pb_series = df['balotaroja'].values
        pb_freq = {}
        for r in range(1, self.max_special_ball + 1):
            pb_sub = (pb_series[:t_idx] == r).astype(np.int8)
            pb_f20 = np.sum(pb_sub[-20:]) if t_idx >= 20 else np.sum(pb_sub)
            alpha = np.exp(-0.03)
            pb_decay = 0.0
            for j in range(t_idx):
                pb_decay = alpha * pb_decay + pb_sub[j]
            pb_freq[r] = pb_f20 + pb_decay

        pb_scores = pd.DataFrame.from_dict(pb_freq, orient='index', columns=['Score']).sort_values('Score', ascending=False)
        rojaprediccion = pb_scores.index.tolist()

        # --- Guardar Predicciones en la Base de Datos ---
        try:
            engine.dispose()
            conn = engine.connect()

            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS predicciones (
                    id SERIAL PRIMARY KEY,
                    loteria_id INTEGER REFERENCES loterias(id) ON DELETE CASCADE,
                    loteria_route VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    numeros INT[] NOT NULL,
                    balotaroja INT[],
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    CONSTRAINT uq_predicciones_loteria_fecha UNIQUE (loteria_route, fecha)
                );
                CREATE INDEX IF NOT EXISTS idx_predicciones_route_fecha ON predicciones (loteria_route, fecha DESC);
                CREATE INDEX IF NOT EXISTS idx_predicciones_loteria_id ON predicciones (loteria_id);
            """))
            conn.commit()

            # Limpieza segura: eliminar solo registros viejos (> 15 días) de ESTA lotería
            conn.execute(text("""
                DELETE FROM predicciones 
                WHERE LOWER(loteria_route) = 'millionaire_life' 
                  AND fecha < CURRENT_DATE - INTERVAL '15 days';
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones (loteria_id, loteria_route, fecha, numeros, balotaroja)
                VALUES (
                    (SELECT id FROM loterias WHERE LOWER(route) = 'millionaire_life' OR LOWER(nombre) LIKE '%millionaire%' LIMIT 1),
                    'millionaire_life',
                    :fecha,
                    :numeros,
                    :balotaroja
                )
                ON CONFLICT (loteria_route, fecha) DO UPDATE
                SET numeros = EXCLUDED.numeros,
                    balotaroja = EXCLUDED.balotaroja,
                    loteria_id = EXCLUDED.loteria_id,
                    created_at = CURRENT_TIMESTAMP;
            """), {"fecha": fecha_proximo_sorteo, "numeros": numeros_prediccion, "balotaroja": rojaprediccion})
            conn.commit()

            print(f"✅ Predicción de Millionaire Life guardada exitosamente en la tabla unificada para la fecha: {fecha_proximo_sorteo}")
            print(f"Top 20 números con mayor probabilidad: {numeros_prediccion[:20]}")
            print(f"Top Balota Especial propuesta: {rojaprediccion[:5]}")

        except Exception as e:
            print(f"❌ Error al guardar predicciones de Millionaire Life en BD: {e}")
        finally:
            conn.close()

if __name__ == "__main__":
    MillionaireLifePredictor().run()
