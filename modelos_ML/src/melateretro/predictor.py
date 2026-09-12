import sys
import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
from xgboost import XGBClassifier
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class MelateRetroPredictor:
    def __init__(self):
        self.engine = get_engine()
        self.max_balota = 39
        self.max_adicional = 39
        self.loteria_id = 17
        self.loteria_route = 'melateretro'

    def cargar_datos(self) -> pd.DataFrame:
        query = "SELECT * FROM resultados_melateretro ORDER BY fecha ASC;"
        with self.engine.connect() as conn:
            df = pd.read_sql(text(query), conn)
        return df

    def run(self):
        print("🔮 Iniciando Predictor de Melate Retro (México - XGBoost)...")
        df = self.cargar_datos()

        if df.empty or len(df) < 15:
            print("⚠️ Insuficientes datos históricos para entrenar el modelo de Melate Retro.")
            return

        df['fecha'] = pd.to_datetime(df['fecha'])
        df = df.sort_values('fecha').reset_index(drop=True)

        # La última fila es el sorteo futuro a predecir (balota1 == 0)
        proxima_fecha = df.iloc[-1]['fecha'].strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para Melate Retro: {proxima_fecha}")

        # Separar histórico real
        df_real = df[df['balota1'] > 0].copy().reset_index(drop=True)
        if len(df_real) < 10:
            print("⚠️ Insuficientes sorteos reales para entrenar.")
            return

        # -------------------------------------------------------------
        # 1. Preparar Matriz de Balotas Principales (1 a 39)
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

        # Usar los últimos 1000 sorteos para entrenamiento
        train_idx = df_real.index[-1000:] if len(df_real) > 1000 else df_real.index[3:]
        X_train = df_features.iloc[train_idx]

        # Entrenar clasificadores para cada una de las 39 balotas naturales
        probabilidades = {}
        for i in range(1, self.max_balota + 1):
            target_col = f'b_{i}'
            y_train = df_b.iloc[train_idx][target_col]

            if y_train.nunique() < 2:
                probabilidades[i] = 0.05
                continue

            model = XGBClassifier(
                n_estimators=70,
                max_depth=4,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42,
                n_jobs=1
            )
            model.fit(X_train, y_train)

            prob = model.predict_proba(X_pred)[0][1] if len(model.classes_) > 1 else 0.05
            probabilidades[i] = prob

        # Ranking de balotas naturales
        df_pred_balotas = pd.DataFrame(list(probabilidades.items()), columns=['numero', 'probabilidad'])
        df_pred_balotas = df_pred_balotas.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        top_numeros = df_pred_balotas['numero'].tolist()

        # -------------------------------------------------------------
        # 2. Preparar Modelo para Número Adicional (1 a 39)
        # -------------------------------------------------------------
        binary_add_dict = {}
        for a in range(1, self.max_adicional + 1):
            binary_add_dict[f'add_{a}'] = (df['balotaroja'] == a).astype(int)

        df_add = pd.concat([df, pd.DataFrame(binary_add_dict, index=df.index)], axis=1)
        cols_add = [f'add_{a}' for a in range(1, self.max_adicional + 1)]

        add_feat_dict = {
            'dia_semana': df_add['fecha'].dt.dayofweek,
            'mes': df_add['fecha'].dt.month
        }

        for lag in [1, 2, 3]:
            for col in cols_add:
                add_feat_dict[f'{col}_lag_{lag}'] = df_add[col].shift(lag)

        for w in [5, 10]:
            for col in cols_add:
                add_feat_dict[f'{col}_roll_sum_{w}'] = df_add[col].shift(1).rolling(w, min_periods=1).sum()

        df_add_features = pd.DataFrame(add_feat_dict, index=df_add.index).fillna(0)
        X_add_pred = df_add_features.iloc[[-1]]
        X_add_train = df_add_features.iloc[train_idx]

        add_probs = {}
        for a in range(1, self.max_adicional + 1):
            target_col = f'add_{a}'
            y_add_train = df_add.iloc[train_idx][target_col]

            if y_add_train.nunique() < 2:
                add_probs[a] = 0.02
                continue

            model_add = XGBClassifier(
                n_estimators=50,
                max_depth=3,
                learning_rate=0.05,
                eval_metric='logloss',
                random_state=42,
                n_jobs=1
            )
            model_add.fit(X_add_train, y_add_train)
            prob_a = model_add.predict_proba(X_add_pred)[0][1] if len(model_add.classes_) > 1 else 0.02
            add_probs[a] = prob_a

        df_pred_add = pd.DataFrame(list(add_probs.items()), columns=['adicional', 'probabilidad'])
        df_pred_add = df_pred_add.sort_values(by='probabilidad', ascending=False).reset_index(drop=True)
        adicionales_prediccion = df_pred_add['adicional'].tolist()

        # -------------------------------------------------------------
        # 3. Guardar en Base de Datos (Tabla 'predicciones')
        # -------------------------------------------------------------
        try:
            with self.engine.connect() as conn:
                lot_row = conn.execute(text("SELECT id FROM loterias WHERE LOWER(route) = 'melateretro' LIMIT 1")).fetchone()
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
                    "balotaroja": adicionales_prediccion
                })
                conn.commit()

            print(f"✅ Predicción de Melate Retro guardada exitosamente en BD para la fecha: {proxima_fecha}")
            print(f"Top 15 números principales con mayor probabilidad: {top_numeros[:15]}")
            print(f"Top 10 números adicionales más probables: {adicionales_prediccion[:10]}")

        except Exception as e:
            print(f"❌ Error guardando predicción de Melate Retro en base de datos: {e}")

if __name__ == "__main__":
    predictor = MelateRetroPredictor()
    predictor.run()
