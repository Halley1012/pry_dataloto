import sys
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
from xgboost import XGBClassifier
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class KabalaPredictor:
    def __init__(self):
        self.engine = get_engine()
        self.max_balota = 40
        self.loteria_id = 32
        self.loteria_route = 'kabala'

    def cargar_datos(self) -> pd.DataFrame:
        query = "SELECT * FROM resultados_kabala WHERE sorteo = 'Kábala' ORDER BY fecha ASC;"
        with self.engine.connect() as conn:
            df = pd.read_sql(text(query), conn)
        return df

    def run(self):
        print("🔮 Iniciando Predictor de Kábala (Perú - XGBoost)...")
        df = self.cargar_datos()

        if df.empty or len(df) < 15:
            print("⚠️ Insuficientes datos históricos para entrenar el modelo de Kábala.")
            return

        df['fecha'] = pd.to_datetime(df['fecha'])
        df = df.sort_values('fecha').reset_index(drop=True)

        proxima_fecha = df.iloc[-1]['fecha'].strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para Kábala: {proxima_fecha}")

        df_real = df[df['balota1'] > 0].copy().reset_index(drop=True)
        if len(df_real) < 10:
            print("⚠️ Insuficientes sorteos reales para entrenar.")
            return

        # -------------------------------------------------------------
        # 1. Matriz de Balotas Principales (1 a 40)
        # -------------------------------------------------------------
        binary_dict = {}
        for i in range(1, self.max_balota + 1):
            binary_dict[f'b_{i}'] = (
                (df['balota1'] == i) |
                (df['balota2'] == i) |
                (df['balota3'] == i) |
                (df['balota4'] == i) |
                (df['balota5'] == i) |
                (df['balota6'] == i)
            ).astype(int)

        df_b = pd.concat([df, pd.DataFrame(binary_dict, index=df.index)], axis=1)
        cols_balotas = [f'b_{i}' for i in range(1, self.max_balota + 1)]

        feat_dict = {
            'dia_semana': df_b['fecha'].dt.dayofweek,
            'mes': df_b['fecha'].dt.month,
            'dia': df_b['fecha'].dt.day
        }

        for lag in [1, 2, 3]:
            for col in cols_balotas:
                feat_dict[f'{col}_lag_{lag}'] = df_b[col].shift(lag)

        for w in [5, 10, 20]:
            for col in cols_balotas:
                feat_dict[f'{col}_roll_sum_{w}'] = df_b[col].shift(1).rolling(w, min_periods=1).sum()

        df_features = pd.DataFrame(feat_dict, index=df_b.index).fillna(0)
        X_pred = df_features.iloc[[-1]]

        train_idx = df_real.index[-500:] if len(df_real) > 500 else df_real.index[3:]
        X_train = df_features.iloc[train_idx]

        # Entrenar clasificadores para cada balota natural
        probabilidades = {}
        for i in range(1, self.max_balota + 1):
            target_col = f'b_{i}'
            y_train = df_b.iloc[train_idx][target_col]

            if y_train.nunique() < 2:
                probabilidades[i] = 0.05
                continue

            model = XGBClassifier(
                n_estimators=60,
                max_depth=4,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42,
                n_jobs=1
            )
            model.fit(X_train, y_train)

            prob = model.predict_proba(X_pred)[0][1] if len(model.classes_) > 1 else 0.05
            probabilidades[i] = prob

        df_pred_balotas = pd.DataFrame(list(probabilidades.items()), columns=['numero', 'probabilidad'])
        df_pred_balotas = df_pred_balotas.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        top_numeros = df_pred_balotas['numero'].tolist()

        # -------------------------------------------------------------
        # 2. Guardar en Base de Datos (Tabla 'predicciones')
        # -------------------------------------------------------------
        try:
            with self.engine.connect() as conn:
                lot_row = conn.execute(text("SELECT id FROM loterias WHERE LOWER(route) = 'kabala' LIMIT 1")).fetchone()
                if lot_row:
                    self.loteria_id = lot_row[0]

                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS predicciones (
                        id SERIAL PRIMARY KEY,
                        loteria_id INT,
                        loteria_route VARCHAR(50),
                        fecha DATE NOT NULL,
                        numeros INT[],
                        balotaroja INT[],
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT uq_prediccion_route_fecha UNIQUE (loteria_route, fecha)
                    );
                """))

                insert_query = text("""
                    INSERT INTO predicciones (loteria_id, loteria_route, fecha, numeros, balotaroja, created_at)
                    VALUES (:loteria_id, :loteria_route, :fecha, :numeros, :balotaroja, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria_route, fecha)
                    DO UPDATE SET
                        loteria_id = EXCLUDED.loteria_id,
                        numeros = EXCLUDED.numeros,
                        balotaroja = EXCLUDED.balotaroja,
                        created_at = CURRENT_TIMESTAMP;
                """)

                conn.execute(insert_query, {
                    "loteria_id": self.loteria_id,
                    "loteria_route": self.loteria_route,
                    "fecha": proxima_fecha,
                    "numeros": top_numeros,
                    "balotaroja": []
                })
                conn.commit()

            print(f"✅ Predicción de Kábala guardada exitosamente en BD para la fecha: {proxima_fecha}")
            print(f"Top 20 números naturales más probables (1 al 40): {top_numeros[:20]}")

        except Exception as e:
            print(f"❌ Error guardando predicción de Kábala en base de datos: {e}")

if __name__ == "__main__":
    predictor = KabalaPredictor()
    predictor.run()
