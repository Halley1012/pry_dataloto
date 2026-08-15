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
        self.features = ['Año', 'Mes', 'Día', 'dia_semana']

    def run(self):
        print("🔮 Iniciando Predictor de Mega Millions (Modelo Fecha/XGBoost)...")
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

        df3 = df_all[df_all['balota1'] > 0].copy().reset_index(drop=True)
        if df3.empty:
            print("⚠️ No hay suficientes resultados históricos reales para entrenar.")
            return

        df3['Año'] = df3['fecha'].dt.year
        df3['Mes'] = df3['fecha'].dt.month
        df3['Día'] = df3['fecha'].dt.day
        df3['dia_semana'] = df3['fecha'].dt.dayofweek

        # --- MODELO 1: Balotas Blancas ---
        for n in range(1, self.max_white_ball + 1):
            df3[f'n_{n}'] = df3[['balota1', 'balota2', 'balota3', 'balota4', 'balota5']].apply(
                lambda row: int(n in row.values), axis=1
            )

        df_future = df3[df3['fecha'] == df3['fecha'].max()].copy()
        if df_future.empty:
            print(f"⚠️ No se encontró la fila con la fecha reciente en Mega Millions.")
            return

        X_future = df_future[self.features]
        df_train = df3[df3['fecha'] < df3['fecha'].max()]

        predicciones_regular = {}
        for i in range(1, self.max_white_ball + 1):
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
                reg_lambda=1,
                eval_metric='logloss', 
                random_state=42,
                n_jobs=1
            )
            
            model_reg.fit(X_train, y_train)
            proba = model_reg.predict_proba(X_future)[0, 1]
            predicciones_regular[i] = proba

        df_pred_reg = pd.DataFrame.from_dict(predicciones_regular, orient='index', columns=['Probabilidad'])
        df_pred_reg = df_pred_reg.sort_values('Probabilidad', ascending=False)
        numeros_prediccion = df_pred_reg.index.tolist()

        # --- MODELO 2: Mega Ball (Balota Roja) ---
        X_train_roja = df_train[self.features]
        y_train_roja = df_train["balotaroja"] - 1

        valid_mask = (y_train_roja >= 0) & (y_train_roja < self.max_special_ball)
        X_train_roja = X_train_roja[valid_mask]
        y_train_roja = y_train_roja[valid_mask]

        model_roja = XGBClassifier(
            objective="multi:softprob",
            num_class=self.max_special_ball,
            eval_metric="mlogloss",
            random_state=42,
            n_jobs=1
        )
        model_roja.fit(X_train_roja, y_train_roja)

        probs_roja = model_roja.predict_proba(X_future)

        ranking_roja = pd.DataFrame({
            "Numero": [idx + 1 for idx in range(self.max_special_ball)],
            "Probabilidad": probs_roja[0]
        }).sort_values("Probabilidad", ascending=False)
        rojaprediccion = ranking_roja["Numero"].tolist()

        # --- Guardar en BD ---
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
