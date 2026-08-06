import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sklearn.preprocessing import LabelEncoder
from sqlalchemy import text
import json
from config.database import get_engine

class ColorLotoPredictor:
    def __init__(self):
        pass

    def run(self):
        print("🔮 Iniciando Predictor de ColorLoto...")
        engine = get_engine()

        # 1. Leer los resultados de la base de datos
        try:
            resultados = pd.read_sql("SELECT fecha, color, numero FROM resultados_colorloto2", engine)
        except Exception as e:
            print(f"❌ Error consultando resultados ColorLoto: {e}")
            return

        if resultados.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo de ColorLoto.")
            return

        df = pd.DataFrame(resultados)
        df['fecha'] = pd.to_datetime(df['fecha'])

        # Ordenar temporalmente
        df = df.sort_values("fecha", ascending=False).reset_index(drop=True)

        # Definir fecha objetivo (la más reciente, que tiene ceros) e históricos
        fecha_objetivo = df['fecha'].max()
        fila_objetivo = df[df['fecha'] == fecha_objetivo]
        df_historico = df[df['fecha'] < fecha_objetivo]

        print(f"Fecha objetivo para predicción: {fecha_objetivo.strftime('%Y-%m-%d')}")

        # --- MODELO 1: Predicción de frecuencia de colores ---
        # Conteo de colores por fecha en históricos
        df_color_freq = (
            df_historico
            .groupby(["fecha", "color"])
            .size()
            .reset_index(name="count")
        )

        # Pivot -> columnas = colores
        df_color_pivot = df_color_freq.pivot(
            index="fecha",
            columns="color",
            values="count"
        ).fillna(0)

        # Target = color más frecuente del día
        df_color_pivot["target_color"] = df_color_pivot.idxmax(axis=1)

        # Encode target
        le_color = LabelEncoder()
        df_color_pivot["y"] = le_color.fit_transform(df_color_pivot["target_color"])

        X_color = df_color_pivot.drop(columns=["target_color", "y"])
        y_color = df_color_pivot["y"]

        model_color = XGBClassifier(
            n_estimators=300,
            max_depth=4,
            learning_rate=0.05,
            subsample=0.8,
            colsample_bytree=0.8,
            objective="multi:softprob",
            eval_metric="mlogloss",
            random_state=42
        )
        model_color.fit(X_color, y_color)

        # Predecir probabilidades de color para el último estado conocido
        X_fecha_color = X_color.iloc[-1:].values
        probs_color = model_color.predict_proba(X_fecha_color)[0]

        ranking_colores = sorted(
            zip(le_color.classes_, probs_color),
            key=lambda x: x[1],
            reverse=True
        )

        # --- MODELO 2: Predicción de números por color ---
        modelos_numeros = {}
        ranking_numeros = {}

        for color in df_historico["color"].unique():
            df_c = df_historico[df_historico["color"] == color].copy()

            # Features simples: lags del número
            for i in range(1, 6):
                df_c[f"lag_{i}"] = df_c["numero"].shift(i)

            df_c = df_c.dropna()

            if df_c.empty:
                continue

            X_num = df_c[[f"lag_{i}" for i in range(1, 6)]]
            y_num = df_c["numero"] - 1  # Clases 0-6 (los números van de 1 a 7)

            # Verificar que haya más de una clase para evitar errores
            if y_num.nunique() < 2:
                continue

            model_num = XGBClassifier(
                n_estimators=300,
                max_depth=4,
                learning_rate=0.05,
                subsample=0.8,
                colsample_bytree=0.8,
                objective="multi:softprob",
                eval_metric="mlogloss",
                random_state=42
            )
            model_num.fit(X_num, y_num)
            modelos_numeros[color] = model_num

            # Últimos valores para predecir
            ultimos = df_c.sort_values("fecha").tail(5)["numero"].values
            X_fecha_num = ultimos.reshape(1, -1)

            probs_num = model_num.predict_proba(X_fecha_num)[0]
            
            # Ordenar números del 1 al 7 según su probabilidad
            ranking = np.argsort(probs_num)[::-1] + 1
            ranking_numeros[color] = [int(num) for num in ranking]

        # Consolidar ranking final estructurado para guardar en la BD Neon
        # ColorLoto guarda un ranking de colores y la predicción de números asociados
        ranking_final = {
            "colores": [c for c, _ in ranking_colores],
            "numeros_por_color": ranking_numeros
        }

        # Guardar en base de datos Neon
        ranking_json = json.dumps(ranking_final)

        with engine.connect() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS predicciones_colorloto2 (
                    id SERIAL PRIMARY KEY,
                    fecha DATE UNIQUE NOT NULL,
                    ranking TEXT,
                    created_at TIMESTAMP DEFAULT NOW()
                );
            """))
            conn.commit()

            conn.execute(text("""
                DELETE FROM predicciones_colorloto2 
                WHERE fecha < CURRENT_DATE - INTERVAL '7 days';
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones_colorloto2 (fecha, ranking)
                VALUES (:fecha, :ranking)
                ON CONFLICT (fecha)
                DO UPDATE SET
                    ranking = EXCLUDED.ranking,
                    created_at = NOW();
            """), {"fecha": fecha_objetivo, "ranking": ranking_json})
            conn.commit()

        print(f"✅ Predicción de ColorLoto guardada exitosamente para la fecha {fecha_objetivo.strftime('%Y-%m-%d')}")
