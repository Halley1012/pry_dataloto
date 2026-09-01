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

class BonolotoPredictor:
    def __init__(self):
        self.max_white_ball = 49
        self.max_reintegro = 10 # 0 al 9
        self.features = ['Año', 'Mes', 'Día', 'dia_semana']

    def run(self):
        print("🔮 Iniciando Predictor de Bonoloto (España - XGBoost)...")
        engine = get_engine()

        try:
            df_all = pd.read_sql(
                'SELECT "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balota6", "balotaroja", "balotaroja2" '
                'FROM resultados_bonoloto '
                'ORDER BY fecha ASC;', engine
            )
        except Exception as e:
            print(f"❌ Error consultando resultados Bonoloto: {e}")
            return

        if df_all.empty:
            print("⚠️ No hay resultados en la base de datos para entrenar el modelo de Bonoloto.")
            return

        df_all["fecha"] = pd.to_datetime(df_all["fecha"])
        fecha_proximo_sorteo = df_all['fecha'].max().strftime('%Y-%m-%d')
        print(f"Próximo sorteo a predecir para Bonoloto: {fecha_proximo_sorteo}")

        df3 = df_all[df_all['balota1'] > 0].copy().reset_index(drop=True)
        if df3.empty or len(df3) < 10:
            print("⚠️ No hay suficientes resultados históricos reales para entrenar.")
            return

        df3['Año'] = df3['fecha'].dt.year
        df3['Mes'] = df3['fecha'].dt.month
        df3['Día'] = df3['fecha'].dt.day
        df3['dia_semana'] = df3['fecha'].dt.dayofweek

        # --- Crear columnas binarias para los 49 números regulares ---
        for n in range(1, self.max_white_ball + 1):
            df3[f'n_{n}'] = df3[['balota1', 'balota2', 'balota3', 'balota4', 'balota5', 'balota6']].apply(
                lambda row: int(n in row.values), axis=1
            )

        # --- Crear columnas binarias para los 10 Reintegros (0 al 9) ---
        for r in range(self.max_reintegro):
            df3[f'r_{r}'] = (df3['balotaroja2'] == r).astype(int)

        df_future = df_all[df_all['fecha'] == df_all['fecha'].max()].copy()
        if df_future.empty:
            print("⚠️ No se encontró la fila con la fecha reciente en Bonoloto.")
            return

        df_future['Año'] = df_future['fecha'].dt.year
        df_future['Mes'] = df_future['fecha'].dt.month
        df_future['Día'] = df_future['fecha'].dt.day
        df_future['dia_semana'] = df_future['fecha'].dt.dayofweek

        X_future = df_future[self.features].iloc[[0]]
        df_train = df3[df3['fecha'] < df_all['fecha'].max()]

        # --- MODELO 1: 6 Números Regulares (1 al 49) ---
        predicciones_regular = {}
        for i in range(1, self.max_white_ball + 1):
            target_col = f'n_{i}'
            y_train = df_train[target_col]

            if y_train.nunique() < 2:
                predicciones_regular[i] = 0.0
                continue

            X_train = df_train[self.features]

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

        # --- MODELO 2: Reintegro (0 al 9) ---
        predicciones_reintegro = {}
        for r in range(self.max_reintegro):
            target_col = f'r_{r}'
            y_train_r = df_train[target_col]

            if y_train_r.nunique() < 2:
                predicciones_reintegro[r] = 0.0
                continue

            X_train_r = df_train[self.features]

            model_rein = XGBClassifier(
                n_estimators=80,
                learning_rate=0.1,
                max_depth=1,
                subsample=0.8,
                colsample_bytree=0.6,
                eval_metric='logloss',
                random_state=42,
                n_jobs=1
            )
            model_rein.fit(X_train_r, y_train_r)
            proba_r = model_rein.predict_proba(X_future)[0, 1]
            predicciones_reintegro[r] = proba_r

        df_pred_rein = pd.DataFrame.from_dict(predicciones_reintegro, orient='index', columns=['Probabilidad'])
        df_pred_rein = df_pred_rein.sort_values('Probabilidad', ascending=False)
        reintegroprediccion = df_pred_rein.index.tolist()

        # --- Guardar en BD en la tabla predicciones ---
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

            # Limpieza segura: eliminar solo registros viejos (> 15 días) de esta lotería
            conn.execute(text("""
                DELETE FROM predicciones 
                WHERE LOWER(loteria_route) = 'bonoloto' 
                  AND fecha < CURRENT_DATE - INTERVAL '15 days';
            """))
            conn.commit()

            conn.execute(text("""
                INSERT INTO predicciones (loteria_id, loteria_route, fecha, numeros, balotaroja)
                VALUES (
                    (SELECT id FROM loterias WHERE LOWER(route) = 'bonoloto' OR LOWER(nombre) = 'bonoloto' LIMIT 1),
                    'bonoloto',
                    :fecha,
                    :numeros,
                    :balotaroja
                )
                ON CONFLICT (loteria_route, fecha) DO UPDATE
                SET numeros = EXCLUDED.numeros,
                    balotaroja = EXCLUDED.balotaroja,
                    loteria_id = EXCLUDED.loteria_id,
                    created_at = CURRENT_TIMESTAMP;
            """), {"fecha": fecha_proximo_sorteo, "numeros": numeros_prediccion, "balotaroja": reintegroprediccion})
            conn.commit()

            print(f"✅ Predicción de Bonoloto guardada exitosamente en BD para la fecha: {fecha_proximo_sorteo}")
            print(f"Top 15 números principales con mayor probabilidad: {numeros_prediccion[:15]}")
            print(f"Ranking Reintegro propuesto: {reintegroprediccion}")

        except Exception as e:
            print(f"❌ Error al guardar predicciones de Bonoloto en BD: {e}")
        finally:
            conn.close()

if __name__ == "__main__":
    BonolotoPredictor().run()
