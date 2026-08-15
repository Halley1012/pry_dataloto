import sys
from pathlib import Path
import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sqlalchemy import text

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class MilotoPredictor:
    def __init__(self):
        self.features = ['Año', 'Mes', 'Día', 'dia_semana']

    def run(self):
        print("🚀 Iniciando Predictor de Miloto con XGBoost...")
        engine = get_engine()

        # 1. Leer los resultados de la base de datos
        try:
            resultados = pd.read_sql("SELECT * FROM resultados_mloto;", engine)
        except Exception as e:
            print(f"❌ Error al consultar resultados de base de datos: {e}")
            return

        if resultados.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo.")
            return

        # 2. Crear el DataFrame inicial según el notebook
        df = pd.DataFrame(resultados, columns=["fecha", "balota1", "balota2", "balota3", "balota4", "balota5"])
        df['fecha'] = pd.to_datetime(df['fecha'])

        # 3. Extraer fecha del último sorteo
        fecha_ultimo_sorteo = df['fecha'].max().strftime('%Y-%m-%d')
        print(f"Fecha del último sorteo para predicción: {fecha_ultimo_sorteo}")

        # 4. Feature engineering idéntico al notebook
        df['Año'] = df['fecha'].dt.year
        df['Mes'] = df['fecha'].dt.month
        df['Día'] = df['fecha'].dt.day
        df['dia_semana'] = df['fecha'].dt.dayofweek

        # 5. Crear columnas binarias para los números 1 a 39
        for n in range(1, 40):
            df[f'n_{n}'] = df[['balota1', 'balota2', 'balota3', 'balota4', 'balota5']].apply(
                lambda row: int(n in row.values), axis=1
            )

        # 6. Definir matriz X y splits temporales
        X_future = df[df['fecha'] == fecha_ultimo_sorteo][self.features]
        df_train = df[df['fecha'] < fecha_ultimo_sorteo]

        if X_future.empty:
            print(f"⚠️ No se encontró la fila con la fecha objetivo {fecha_ultimo_sorteo} para predecir.")
            return

        predicciones = {}

        # 7. Bucle iterativo de XGBoost por cada una de las 39 balotas
        for i in range(1, 40):
            target_col = f'n_{i}'
            y = df[target_col]

            # Evitar entrenar modelos sin balance de clases mínimo
            if y.nunique() < 2:
                continue

            X_train = df_train[self.features]
            y_train = df_train[target_col]

            # Inicializar XGBoost con los hiperparámetros exactos del notebook
            model = XGBClassifier(
                n_estimators=100,
                learning_rate=0.1,
                max_depth=1,
                subsample=0.8,
                colsample_bytree=0.5,
                gamma=1,
                reg_alpha=0.1,
                reg_lambda=1,
                #use_label_encoder=False,
                eval_metric='logloss',
                random_state=42,
                n_jobs=1
            )
            model.fit(X_train, y_train)

            # Predecir probabilidad de la clase 1 (segunda columna)
            proba = model.predict_proba(X_future)[0, 1]
            predicciones[i] = proba

        # 8. Procesar y ordenar resultados
        df_predicciones = pd.DataFrame.from_dict(predicciones, orient='index', columns=['Probabilidad'])
        df_predicciones = df_predicciones.sort_values('Probabilidad', ascending=False)
        
        numeros_prediccion = df_predicciones.index.tolist()

        # 9. Guardar y actualizar en Neon DB de forma segura
        try:
            engine.dispose()  # Forzamos a destruir el pool viejo para evitar el SSL Timeout
            conn = engine.connect()
            
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS predicciones_mloto (
                    id SERIAL PRIMARY KEY,
                    fecha DATE UNIQUE NOT NULL,
                    numeros INT[]
                );
            """))
            conn.commit()

            conn.execute(text("""
                DELETE FROM predicciones_mloto 
                WHERE fecha < CURRENT_DATE - INTERVAL '7 days';
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones_mloto (fecha, numeros)
                VALUES (:fecha, :numeros)
                ON CONFLICT (fecha) DO UPDATE
                SET numeros = EXCLUDED.numeros;
            """), {"fecha": fecha_ultimo_sorteo, "numeros": numeros_prediccion})
            conn.commit()

            print(f"✅ Predicción con XGBoost guardada exitosamente en Neon DB para la fecha: {fecha_ultimo_sorteo}")
            print(f"Cantidad de números generados: {len(numeros_prediccion)}")
            
        except Exception as e:
            print(f"❌ Error al guardar predicciones en base de datos: {e}")
        finally:
            conn.close()


if __name__ == "__main__":
    MilotoPredictor().run()