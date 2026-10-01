import sys
from pathlib import Path
from datetime import timedelta

import pandas as pd
from xgboost import XGBClassifier
from sqlalchemy import text

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

from config.database import get_engine


class DoublePlayPredictor:
    """
    Predictor de Double Play.

    La fecha objetivo NO depende del placeholder ni de la predicción anterior:
    se calcula desde el último resultado real según el calendario oficial
    lunes/miércoles/sábado.
    """

    def __init__(self):
        self.max_white_ball = 69
        self.max_special_ball = 26
        self.features = ["Año", "Mes", "Día", "dia_semana"]
        self.draw_days = (0, 2, 5)  # lunes, miércoles, sábado

    def _calcular_proximo_sorteo(self, ultima_fecha_real):
        fecha = pd.Timestamp(ultima_fecha_real).date() + timedelta(days=1)
        while fecha.weekday() not in self.draw_days:
            fecha += timedelta(days=1)
        return fecha

    @staticmethod
    def _prediction_exists(engine, fecha) -> bool:
        with engine.connect() as conn:
            return bool(
                conn.execute(
                    text("""
                        SELECT EXISTS (
                            SELECT 1
                            FROM predicciones
                            WHERE LOWER(TRIM(loteria_route)) = 'double_play'
                              AND fecha = :fecha
                        )
                    """),
                    {"fecha": fecha},
                ).scalar()
            )

    def run(self):
        print("🔮 Iniciando Predictor de Double Play (Modelo Fecha/XGBoost)...")
        engine = get_engine()

        try:
            df_all = pd.read_sql(
                text("""
                    SELECT
                        fecha,
                        balota1, balota2, balota3, balota4, balota5,
                        balotaroja
                    FROM resultados_double_play
                    ORDER BY fecha ASC
                """),
                engine,
            )
        except Exception as e:
            print(f"❌ Error consultando resultados Double Play: {e}")
            return

        if df_all.empty:
            print("⚠️ No hay resultados para entrenar Double Play.")
            return

        df_all["fecha"] = pd.to_datetime(df_all["fecha"], errors="coerce")
        df_all = df_all.dropna(subset=["fecha"]).reset_index(drop=True)

        # El placeholder (balota1=0) representa la fecha objetivo de la
        # predicción. Esa es la fuente canónica siempre que exista.
        df_placeholder = df_all[df_all["balota1"].fillna(0).astype(int) == 0].copy()
        df3 = df_all[df_all["balota1"].fillna(0).astype(int) > 0].copy().reset_index(drop=True)

        if df3.empty:
            print("⚠️ No hay resultados reales para entrenar Double Play.")
            return

        ultima_fecha_real = df3["fecha"].max().date()

        if not df_placeholder.empty:
            fecha_proximo_sorteo = df_placeholder["fecha"].max().date()
            origen_fecha = "placeholder"
        else:
            # Fallback de seguridad si por alguna razón aún no existe
            # placeholder. No reemplaza la función del placeholder.
            fecha_proximo_sorteo = self._calcular_proximo_sorteo(ultima_fecha_real)
            origen_fecha = "calendario (fallback)"

        if fecha_proximo_sorteo <= ultima_fecha_real:
            print(
                "⚠️ Placeholder/fecha objetivo inválida: "
                f"{fecha_proximo_sorteo} no es posterior al último resultado real "
                f"{ultima_fecha_real}. Se recalcula por calendario."
            )
            fecha_proximo_sorteo = self._calcular_proximo_sorteo(ultima_fecha_real)
            origen_fecha = "calendario (fallback por placeholder inválido)"

        print(f"📅 Último resultado real de Double Play: {ultima_fecha_real}")
        print(
            f"🎯 Próximo sorteo a predecir para Double Play: "
            f"{fecha_proximo_sorteo} [{origen_fecha}]"
        )

        try:
            if self._prediction_exists(engine, fecha_proximo_sorteo):
                print(
                    "ℹ️ Ya existe una predicción de Double Play para "
                    f"{fecha_proximo_sorteo}; no se recalcula."
                )
                return
        except Exception:
            pass

        df3["Año"] = df3["fecha"].dt.year
        df3["Mes"] = df3["fecha"].dt.month
        df3["Día"] = df3["fecha"].dt.day
        df3["dia_semana"] = df3["fecha"].dt.dayofweek

        # Entrenamos con TODOS los sorteos reales, incluido el último.
        X_train = df3[self.features]

        target_ts = pd.Timestamp(fecha_proximo_sorteo)
        X_future = pd.DataFrame(
            [{
                "Año": target_ts.year,
                "Mes": target_ts.month,
                "Día": target_ts.day,
                "dia_semana": target_ts.dayofweek,
            }],
            columns=self.features,
        )

        # --- MODELO 1: Balotas blancas ---
        for n in range(1, self.max_white_ball + 1):
            df3[f"n_{n}"] = df3[
                ["balota1", "balota2", "balota3", "balota4", "balota5"]
            ].apply(lambda row: int(n in row.values), axis=1)

        predicciones_regular = {}
        for i in range(1, self.max_white_ball + 1):
            target_col = f"n_{i}"
            y_train = df3[target_col]

            if y_train.nunique() < 2:
                continue

            model_reg = XGBClassifier(
                n_estimators=100,
                learning_rate=0.1,
                max_depth=1,
                subsample=0.8,
                colsample_bytree=0.5,
                gamma=1,
                reg_alpha=0.1,
                reg_lambda=1,
                eval_metric="logloss",
                random_state=42,
            )

            model_reg.fit(X_train, y_train)
            proba = model_reg.predict_proba(X_future)[0, 1]
            predicciones_regular[i] = float(proba)

        if not predicciones_regular:
            print("⚠️ No fue posible generar ranking de balotas blancas.")
            return

        df_pred_reg = pd.DataFrame.from_dict(
            predicciones_regular,
            orient="index",
            columns=["Probabilidad"],
        ).sort_values("Probabilidad", ascending=False)

        numeros_prediccion = df_pred_reg.index.astype(int).tolist()

        # --- MODELO 2: balota especial ---
        y_train_roja = df3["balotaroja"] - 1
        valid_mask = (
            (y_train_roja >= 0)
            & (y_train_roja < self.max_special_ball)
        )

        X_train_roja = X_train.loc[valid_mask]
        y_train_roja = y_train_roja.loc[valid_mask]

        if y_train_roja.empty or y_train_roja.nunique() < 2:
            print("⚠️ No hay datos suficientes para entrenar la balota especial.")
            rojaprediccion = []
        else:
            clases_observadas = sorted(int(v) for v in y_train_roja.unique())
            clase_a_indice = {
                clase: idx for idx, clase in enumerate(clases_observadas)
            }
            indice_a_clase = {
                idx: clase for clase, idx in clase_a_indice.items()
            }
            y_encoded = y_train_roja.map(clase_a_indice).astype(int)

            model_roja = XGBClassifier(
                objective="multi:softprob",
                num_class=len(clases_observadas),
                eval_metric="mlogloss",
                random_state=42,
            )
            model_roja.fit(X_train_roja, y_encoded)

            probs_roja = model_roja.predict_proba(X_future)[0]
            ranking = sorted(
                enumerate(probs_roja),
                key=lambda item: item[1],
                reverse=True,
            )
            rojaprediccion = [
                int(indice_a_clase[idx]) + 1
                for idx, _ in ranking
            ]

        try:
            with engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS predicciones (
                        id SERIAL PRIMARY KEY,
                        loteria_id INTEGER REFERENCES loterias(id) ON DELETE CASCADE,
                        loteria_route VARCHAR(50) NOT NULL,
                        fecha DATE NOT NULL,
                        numeros INT[] NOT NULL,
                        balotaroja INT[],
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT uq_predicciones_loteria_fecha
                            UNIQUE (loteria_route, fecha)
                    );

                    CREATE INDEX IF NOT EXISTS idx_predicciones_route_fecha
                        ON predicciones (loteria_route, fecha DESC);

                    CREATE INDEX IF NOT EXISTS idx_predicciones_loteria_id
                        ON predicciones (loteria_id);
                """))

                conn.execute(text("""
                    DELETE FROM predicciones
                    WHERE LOWER(loteria_route) = 'double_play'
                      AND fecha < CURRENT_DATE - INTERVAL '15 days';
                """))

                conn.execute(
                    text("""
                        INSERT INTO predicciones (
                            loteria_id,
                            loteria_route,
                            fecha,
                            numeros,
                            balotaroja
                        )
                        VALUES (
                            (
                                SELECT id
                                FROM loterias
                                WHERE LOWER(TRIM(route)) = 'double_play'
                                   OR LOWER(TRIM(nombre)) = 'double play'
                                ORDER BY
                                    CASE
                                        WHEN LOWER(TRIM(route)) = 'double_play'
                                        THEN 0 ELSE 1
                                    END,
                                    id
                                LIMIT 1
                            ),
                            'double_play',
                            :fecha,
                            :numeros,
                            :balotaroja
                        )
                        ON CONFLICT (loteria_route, fecha)
                        DO UPDATE SET
                            numeros = EXCLUDED.numeros,
                            balotaroja = EXCLUDED.balotaroja,
                            loteria_id = EXCLUDED.loteria_id,
                            created_at = CURRENT_TIMESTAMP
                    """),
                    {
                        "fecha": fecha_proximo_sorteo,
                        "numeros": numeros_prediccion,
                        "balotaroja": rojaprediccion,
                    },
                )

            print(
                "✅ Predicción de Double Play guardada para la fecha: "
                f"{fecha_proximo_sorteo}"
            )
            print(
                "Top 20 números con mayor probabilidad: "
                f"{numeros_prediccion[:20]}"
            )
            print(
                "Top Double Play balota roja propuesta: "
                f"{rojaprediccion[:5]}"
            )

        except Exception as e:
            print(f"❌ Error al guardar predicciones de Double Play en BD: {e}")


if __name__ == "__main__":
    DoublePlayPredictor().run()
