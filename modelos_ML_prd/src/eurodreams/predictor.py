import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
from xgboost import XGBClassifier
from sqlalchemy import text
from sklearn.metrics import accuracy_score

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class EuroDreamsPredictor:
    def __init__(self):
        self.engine = get_engine()
        self.max_balota = 40
        self.max_dream = 5
        self.loteria_id = 29
        self.loteria_route = 'eurodreams'

    def cargar_datos(self) -> pd.DataFrame:
        query = "SELECT * FROM resultados_eurodreams ORDER BY fecha ASC;"
        with self.engine.connect() as conn:
            df = pd.read_sql(text(query), conn)
        return df

    def run(self):
        print("🔮 Iniciando Predictor de EuroDreams (España / Europa - XGBoost)...")
        df = self.cargar_datos()

        if df.empty or len(df) < 15:
            print("⚠️ Insuficientes datos históricos para entrenar el modelo de EuroDreams.")
            return

        df['fecha'] = pd.to_datetime(df['fecha'])
        df = df.sort_values('fecha').reset_index(drop=True)

        # La última fila es el sorteo futuro a predecir (balota1 == 0)
        proxima_fecha = df.iloc[-1]['fecha'].strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para EuroDreams: {proxima_fecha}")

        # Separar histórico real
        df_real = df[df['balota1'] > 0].copy().reset_index(drop=True)
        if len(df_real) < 10:
            print("⚠️ Insuficientes sorteos reales para entrenar.")
            return

        # -------------------------------------------------------------
        # 1. Preparar Matriz de Balotas Principales (1 a 40)
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

        # Ingeniería de características (construido en dict para evitar fragmentación)
        feat_dict = {
            'dia_semana': df_b['fecha'].dt.dayofweek,
            'mes': df_b['fecha'].dt.month,
            'dia': df_b['fecha'].dt.day
        }

        # Lags y medias móviles de las balotas
        for lag in [1, 2, 3]:
            for col in cols_balotas:
                feat_dict[f'{col}_lag_{lag}'] = df_b[col].shift(lag)

        for w in [5, 10, 20]:
            for col in cols_balotas:
                feat_dict[f'{col}_roll_sum_{w}'] = df_b[col].shift(1).rolling(w, min_periods=1).sum()

        df_features = pd.DataFrame(feat_dict, index=df_b.index).fillna(0)

        # Fila a predecir (última)
        X_pred = df_features.iloc[[-1]]

        # Datos de entrenamiento (histórico real sin los primeros lags)
        train_idx = df_real.index[3:]
        X_train = df_features.iloc[train_idx]

        # Entrenar clasificadores para cada balota principal
        probabilidades = {}
        for i in range(1, self.max_balota + 1):
            target_col = f'b_{i}'
            y_train = df_b.iloc[train_idx][target_col]

            model = XGBClassifier(
                n_estimators=70,
                max_depth=4,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42
            )
            model.fit(X_train, y_train)

            # Probabilidad de clase 1 (que caiga el número)
            prob = model.predict_proba(X_pred)[0][1] if len(model.classes_) > 1 else 0.05
            probabilidades[i] = prob

        # Ranking de balotas principales
        df_pred_balotas = pd.DataFrame(list(probabilidades.items()), columns=['numero', 'probabilidad'])
        df_pred_balotas = df_pred_balotas.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        top_numeros = df_pred_balotas['numero'].tolist()

        # -------------------------------------------------------------
        # 2. Preparar Modelo para Número Dream (1 a 5)
        # -------------------------------------------------------------
        binary_d_dict = {}
        for d in range(1, self.max_dream + 1):
            binary_d_dict[f'd_{d}'] = (df['balotaroja'] == d).astype(int)

        df_d = pd.concat([df, pd.DataFrame(binary_d_dict, index=df.index)], axis=1)
        cols_dream = [f'd_{d}' for d in range(1, self.max_dream + 1)]

        d_feat_dict = {
            'dia_semana': df_d['fecha'].dt.dayofweek,
            'mes': df_d['fecha'].dt.month
        }

        for lag in [1, 2, 3]:
            for col in cols_dream:
                d_feat_dict[f'{col}_lag_{lag}'] = df_d[col].shift(lag)

        for w in [5, 10]:
            for col in cols_dream:
                d_feat_dict[f'{col}_roll_sum_{w}'] = df_d[col].shift(1).rolling(w, min_periods=1).sum()

        df_d_features = pd.DataFrame(d_feat_dict, index=df_d.index).fillna(0)
        X_d_pred = df_d_features.iloc[[-1]]
        X_d_train = df_d_features.iloc[train_idx]

        dream_probs = {}
        for d in range(1, self.max_dream + 1):
            target_col = f'd_{d}'
            y_d_train = df_d.iloc[train_idx][target_col]

            model_d = XGBClassifier(
                n_estimators=50,
                max_depth=3,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42
            )
            model_d.fit(X_d_train, y_d_train)
            prob_d = model_d.predict_proba(X_d_pred)[0][1] if len(model_d.classes_) > 1 else 0.2
            dream_probs[d] = prob_d

        df_pred_dream = pd.DataFrame(list(dream_probs.items()), columns=['dream', 'probabilidad'])
        df_pred_dream = df_pred_dream.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        dream_prediccion = df_pred_dream['dream'].tolist()

        # -------------------------------------------------------------
        # 3. Guardar en Base de Datos (Tabla 'predicciones')
        # -------------------------------------------------------------
        try:
            with self.engine.connect() as conn:
                # Obtener loteria_id
                lot_row = conn.execute(text("SELECT id FROM loterias WHERE LOWER(route) = 'eurodreams' LIMIT 1")).fetchone()
                if lot_row:
                    self.loteria_id = lot_row[0]

                # Asegurar tabla
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

                # Inserción con UPSERT
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
                    "balotaroja": dream_prediccion
                })
                conn.commit()

            print(f"✅ Predicción de EuroDreams guardada exitosamente en BD para la fecha: {proxima_fecha}")
            print(f"Top 15 números principales con mayor probabilidad: {top_numeros[:15]}")
            print(f"Ranking Número Dream propuesto: {dream_prediccion}")

        except Exception as e:
            print(f"❌ Error guardando predicción de EuroDreams en base de datos: {e}")

if __name__ == "__main__":
    predictor = EuroDreamsPredictor()
    predictor.run()
