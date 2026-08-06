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

class BalotoPredictor:
    def __init__(self):
        # Alineado a las columnas exactas del notebook ('Año' con eñe y 'dia_semana')
        self.features = ['Año', 'Mes', 'Día', 'dia_semana']

    def run(self):
        print("🔮 Iniciando Predictor de Baloto...")
        engine = get_engine()

        # 1. Cargar dataset general manteniendo la consulta limpia
        try:
            df3 = pd.read_sql(
                'SELECT "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja" '
                'FROM resultados_bloto '
                "WHERE \"sorteo\" = 'Baloto';", engine
            )
        except Exception as e:
            print(f"❌ Error consultando resultados Baloto: {e}")
            return

        if df3.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo de Baloto.")
            return

        df3["fecha"] = pd.to_datetime(df3["fecha"])
        fecha_ultimo_sorteo = df3['fecha'].max().strftime('%Y-%m-%d')
        print(f"Último sorteo identificado para Baloto: {fecha_ultimo_sorteo}")

        # 2. Feature Engineering idéntico al notebook (Celda 5)
        df3['Año'] = df3['fecha'].dt.year
        df3['Mes'] = df3['fecha'].dt.month
        df3['Día'] = df3['fecha'].dt.day
        df3['dia_semana'] = df3['fecha'].dt.dayofweek

        # --- MODELO 1: 5 Balotas regulares ---
        # Crear columnas binarias para los números del 1 al 43 (Celda 6)
        for n in range(1, 44):
            df3[f'n_{n}'] = df3[['balota1', 'balota2', 'balota3', 'balota4', 'balota5']].apply(
                lambda row: int(n in row.values), axis=1
            )

        df_future = df3[df3['fecha'] == fecha_ultimo_sorteo].copy()
        if df_future.empty:
            print(f"⚠️ No se encontró la fila con la fecha {fecha_ultimo_sorteo} en Baloto.")
            return

        X_future = df_future[self.features]
        df_train = df3[df3['fecha'] < fecha_ultimo_sorteo]

        predicciones_regular = {}
        for i in range(1, 44):
            target_col = f'n_{i}'
            y = df3[target_col]

            if y.nunique() < 2:
                continue

            X_train = df_train[self.features]
            y_train = df_train[target_col]

            model_reg = XGBClassifier(
                n_estimators=100, 
                learning_rate=0.1, 
                max_depth=1,
                subsample=0.8, 
                colsample_bytree=0.5, 
                gamma=1,
                reg_alpha=0.1, 
                reg_lambda=1, #use_label_encoder=False,
                eval_metric='logloss', 
                random_state=42
            )
            
            model_reg.fit(X_train, y_train)
            proba = model_reg.predict_proba(X_future)[0, 1]
            predicciones_regular[i] = proba

        df_pred_reg = pd.DataFrame.from_dict(predicciones_regular, orient='index', columns=['Probabilidad'])
        df_pred_reg = df_pred_reg.sort_values('Probabilidad', ascending=False)
        numeros_prediccion = df_pred_reg.index.tolist()

        # --- MODELO 2: Balota Roja ---
        X_train_roja = df_train[self.features]
        
        # Ajustamos RESTANDO 1 para que las clases vayan de 0 a 15 y XGBoost no falle
        y_train_roja = df_train["balotaroja"] - 1

        # Filtro de seguridad para asegurar que los datos estén en el rango esperado (0 a 15)
        valid_mask = (y_train_roja >= 0) & (y_train_roja < 16)
        X_train_roja = X_train_roja[valid_mask]
        y_train_roja = y_train_roja[valid_mask]

        model_roja = XGBClassifier(
            objective="multi:softprob",
            num_class=16,
            eval_metric="mlogloss",
            #use_label_encoder=False,
            random_state=42
        )
        model_roja.fit(X_train_roja, y_train_roja)

        probs_roja = model_roja.predict_proba(X_future)

        # Al reconstruir el ranking, LE SUMAMOS 1 al índice para volver a tener los números reales (1 al 16)
        ranking_roja = pd.DataFrame({
            "Numero": [idx + 1 for idx in range(16)],
            "Probabilidad": probs_roja[0]
        }).sort_values("Probabilidad", ascending=False)
        rojaprediccion = ranking_roja["Numero"].tolist()

        # --- Guardar en Neon DB con Cierre Seguro de Conexión ---
        try:
            engine.dispose()  # Forzamos a destruir el pool viejo para evitar el SSL Timeout
            conn = engine.connect()
            
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS predicciones_bloto (
                    id SERIAL PRIMARY KEY,
                    fecha DATE UNIQUE NOT NULL,
                    numeros INT[],
                    balotaroja INT[]
                );
            """))
            conn.commit()

            conn.execute(text("""
                DELETE FROM predicciones_bloto 
                WHERE fecha < CURRENT_DATE - INTERVAL '7 days';
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones_bloto (fecha, numeros, balotaroja)
                VALUES (:fecha, :numeros, :balotaroja)
                ON CONFLICT (fecha) DO UPDATE
                SET numeros = EXCLUDED.numeros,
                    balotaroja = EXCLUDED.balotaroja;
            """), {"fecha": fecha_ultimo_sorteo, "numeros": numeros_prediccion, "balotaroja": rojaprediccion})
            conn.commit()

            print(f"✅ Predicción de Baloto guardada exitosamente para la fecha {fecha_ultimo_sorteo}")
            print(f"Cantidad de números generados: {len(numeros_prediccion)}")
            print(f"Cantidad de balotas rojas: {len(rojaprediccion)}")

        except Exception as e:
            print(f"❌ Error al guardar predicciones de Baloto en base de datos: {e}")
        finally:
            conn.close()


if __name__ == "__main__":
    BalotoPredictor().run()  