import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
from xgboost import XGBClassifier
from sqlalchemy import text
from sklearn.metrics import accuracy_score

# Asegurar import de módulos del proyecto
PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine


class LottoFrPredictor:
    def __init__(self):
        self.engine = get_engine()
        self.max_balota = 49       # 5 números entre 1 y 49
        self.max_chance = 10       # 1 número Chance entre 1 y 10
        self.loteria_id = 53       # ID en tabla loterias
        self.loteria_route = 'lotto_fr'

    def cargar_datos(self) -> pd.DataFrame:
        query = "SELECT * FROM resultados_lotto_fr WHERE sorteo = 'Loto Francia' ORDER BY fecha ASC;"
        with self.engine.connect() as conn:
            df = pd.read_sql(text(query), conn)
        return df

    def run(self):
        print("==================================================")
        print("🔮 Iniciando Predictor de Loto Francia (XGBoost)...")
        print("==================================================")
        df = self.cargar_datos()

        if df.empty or len(df) < 15:
            print(f"⚠️ Insuficientes datos históricos ({len(df)} sorteos) para entrenar el modelo de Loto Francia.")
            return

        df['fecha'] = pd.to_datetime(df['fecha'])
        df = df.sort_values('fecha').reset_index(drop=True)

        # La última fila es el sorteo futuro a predecir (balota1 == 0)
        proxima_fecha = df.iloc[-1]['fecha'].strftime('%Y-%m-%d')
        print(f"📅 Próximo sorteo a predecir para Loto Francia: {proxima_fecha}")

        # Separar histórico real
        df_real = df[df['balota1'] > 0].copy().reset_index(drop=True)
        if len(df_real) < 10:
            print("⚠️ Insuficientes sorteos reales para entrenar.")
            return

        # -------------------------------------------------------------
        # 1. Preparar Matriz de Balotas Principales (1 a 49)
        # -------------------------------------------------------------
        binary_dict = {}
        for i in range(1, self.max_balota + 1):
            binary_dict[f'b_{i}'] = (
                (df['balota1'] == i) |
                (df['balota2'] == i) |
                (df['balota3'] == i) |
                (df['balota4'] == i) |
                (df['balota5'] == i)
            ).astype(int)

        df_b = pd.concat([df, pd.DataFrame(binary_dict, index=df.index)], axis=1)
        cols_balotas = [f'b_{i}' for i in range(1, self.max_balota + 1)]

        # Ingeniería de características temporales y de retardo
        feat_dict = {
            'dia_semana': df_b['fecha'].dt.dayofweek,
            'mes': df_b['fecha'].dt.month,
            'dia': df_b['fecha'].dt.day
        }

        # Lags y sumas móviles
        for lag in [1, 2, 3]:
            for col in cols_balotas:
                feat_dict[f'{col}_lag_{lag}'] = df_b[col].shift(lag)

        for w in [5, 10, 20]:
            for col in cols_balotas:
                feat_dict[f'{col}_roll_sum_{w}'] = df_b[col].shift(1).rolling(w, min_periods=1).sum()

        df_features = pd.DataFrame(feat_dict, index=df_b.index).fillna(0)

        # Fila a predecir (última)
        X_pred = df_features.iloc[[-1]]

        # Datos de entrenamiento (histórico real omitiendo primeros lags para estabilidad)
        min_start = min(3, len(df_real) - 1)
        train_idx = df_real.index[min_start:]
        X_train = df_features.iloc[train_idx]

        # Entrenar clasificadores para cada una de las 49 balotas principales
        print("⚙️ Entrenando modelos XGBoost para las 49 balotas principales...")
        probabilidades = {}
        for i in range(1, self.max_balota + 1):
            target_col = f'b_{i}'
            y_train = df_b.iloc[train_idx][target_col]

            model = XGBClassifier(
                n_estimators=60,
                max_depth=3,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42
            )
            model.fit(X_train, y_train)

            # Probabilidad de aparición en el próximo sorteo
            prob = model.predict_proba(X_pred)[0][1] if len(model.classes_) > 1 else 0.1
            probabilidades[i] = prob

        df_prob = pd.DataFrame(list(probabilidades.items()), columns=['balota', 'probabilidad'])
        df_prob = df_prob.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        top_numeros = df_prob['balota'].tolist()

        # -------------------------------------------------------------
        # 2. Preparar Modelo para el Numéro Chance (1 a 10)
        # -------------------------------------------------------------
        print("⚙️ Entrenando modelo para el Numéro Chance (1 a 10)...")
        chance_binary_dict = {}
        for c in range(1, self.max_chance + 1):
            chance_binary_dict[f'c_{c}'] = (df['balotaroja'] == c).astype(int)

        df_c = pd.concat([df, pd.DataFrame(chance_binary_dict, index=df.index)], axis=1)
        cols_chance = [f'c_{c}' for c in range(1, self.max_chance + 1)]

        feat_c_dict = {
            'dia_semana': df_c['fecha'].dt.dayofweek,
            'mes': df_c['fecha'].dt.month,
            'dia': df_c['fecha'].dt.day
        }

        for lag in [1, 2]:
            for col in cols_chance:
                feat_c_dict[f'{col}_lag_{lag}'] = df_c[col].shift(lag)

        for w in [5, 10]:
            for col in cols_chance:
                feat_c_dict[f'{col}_roll_sum_{w}'] = df_c[col].shift(1).rolling(w, min_periods=1).sum()

        df_c_features = pd.DataFrame(feat_c_dict, index=df_c.index).fillna(0)
        X_c_pred = df_c_features.iloc[[-1]]
        X_c_train = df_c_features.iloc[train_idx]

        chance_probs = {}
        for c in range(1, self.max_chance + 1):
            target_col = f'c_{c}'
            y_c_train = df_c.iloc[train_idx][target_col]

            model_c = XGBClassifier(
                n_estimators=50,
                max_depth=3,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42
            )
            model_c.fit(X_c_train, y_c_train)
            prob_c = model_c.predict_proba(X_c_pred)[0][1] if len(model_c.classes_) > 1 else 0.1
            chance_probs[c] = prob_c

        df_pred_chance = pd.DataFrame(list(chance_probs.items()), columns=['chance', 'probabilidad'])
        df_pred_chance = df_pred_chance.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        chance_prediccion = df_pred_chance['chance'].tolist()

        # -------------------------------------------------------------
        # 3. Guardar en Base de Datos (Tabla 'predicciones')
        # -------------------------------------------------------------
        try:
            with self.engine.connect() as conn:
                # Obtener loteria_id desde la BD
                lot_row = conn.execute(text("SELECT id FROM loterias WHERE LOWER(route) = 'lotto_fr' LIMIT 1")).fetchone()
                if lot_row:
                    self.loteria_id = lot_row[0]

                # Asegurar tabla de predicciones
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

                # Inserción o actualización de la predicción
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
                    "balotaroja": chance_prediccion
                })
                conn.commit()

            print(f"✅ Predicción de Loto Francia guardada exitosamente en BD para la fecha: {proxima_fecha}")
            print(f"Top 10 números principales sugeridos: {top_numeros[:10]}")
            print(f"Ranking Numéro Chance sugerido: {chance_prediccion[:5]}")

        except Exception as e:
            print(f"❌ Error guardando predicción de Loto Francia en base de datos: {e}")


if __name__ == "__main__":
    predictor = LottoFrPredictor()
    predictor.run()
