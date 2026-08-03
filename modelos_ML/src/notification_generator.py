import sys
import pandas as pd
from pathlib import Path
from sqlalchemy import text
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class NotificationGenerator:
    def __init__(self):
        self.engine = get_engine()

    def run(self, loteria="all"):
        print(f"🔔 Iniciando Generador de Notificaciones para: {loteria}")
        if loteria in ["baloto", "all"]:
            self.procesar_baloto()
        if loteria in ["miloto", "all"]:
            self.procesar_miloto()

    def procesar_baloto(self):
        try:
            # Obtener último resultado
            res = pd.read_sql('SELECT * FROM resultados_bloto WHERE sorteo = \'Baloto\' ORDER BY fecha DESC LIMIT 1', self.engine)
            if res.empty: return
            
            fecha = res.iloc[0]['fecha']
            ganadores = set([res.iloc[0][f'balota{i}'] for i in range(1, 6)])
            super_ganadora = res.iloc[0]['balotaroja']

            # Obtener predicción para esa fecha
            pred = pd.read_sql(text('SELECT * FROM predicciones_bloto WHERE fecha = :fecha'), self.engine, params={"fecha": fecha})
            if pred.empty: return

            pred_nums = pred.iloc[0]['numeros']
            pred_rojas = pred.iloc[0]['balotaroja']

            # 1. Casi! (Top 10)
            top_10 = set(pred_nums[:10])
            coincidencias = ganadores.intersection(top_10)
            if len(coincidencias) >= 3:
                msj = f"¡Casi! De los 10 números con mayor probabilidad generados por la IA para Baloto, cayeron {len(coincidencias)} números ({', '.join(map(str, sorted(list(coincidencias))))})."
                self.guardar_notificacion(1, fecha, msj, "acierto_parcial")

            # 2. Superbalota
            if super_ganadora == pred_rojas[0]:
                msj = "¡La IA acertó la Superbalota en el sorteo de hoy!"
                self.guardar_notificacion(1, fecha, msj, "acierto_directo")

            # 3. Precisión Top 5
            top_5 = set(pred_nums[:5])
            coincidencias_5 = ganadores.intersection(top_5)
            efectividad = (len(coincidencias_5) / 5) * 100
            msj = f"En el sorteo de Baloto, el top 5 de números calientes tuvo una efectividad del {int(efectividad)}%."
            self.guardar_notificacion(1, fecha, msj, "precision")

        except Exception as e:
            print(f"❌ Error procesando notificaciones Baloto: {e}")

    def procesar_miloto(self):
        try:
            # Obtener último resultado
            res = pd.read_sql('SELECT * FROM resultados_mloto ORDER BY fecha DESC LIMIT 1', self.engine)
            if res.empty: return
            
            fecha = res.iloc[0]['fecha']
            ganadores = set([res.iloc[0][f'balota{i}'] for i in range(1, 6)])

            # Obtener predicción para esa fecha
            pred = pd.read_sql(text('SELECT * FROM predicciones_mloto WHERE fecha = :fecha'), self.engine, params={"fecha": fecha})
            if pred.empty: return

            pred_nums = pred.iloc[0]['numeros']

            # 1. Casi! (Top 10)
            top_10 = set(pred_nums[:10])
            coincidencias = ganadores.intersection(top_10)
            if len(coincidencias) >= 3:
                msj = f"¡Casi! De los 10 números con mayor probabilidad generados por la IA para Miloto, cayeron {len(coincidencias)} números ({', '.join(map(str, sorted(list(coincidencias))))})."
                self.guardar_notificacion(2, fecha, msj, "acierto_parcial")

            # 2. Precisión Top 5
            top_5 = set(pred_nums[:5])
            coincidencias_5 = ganadores.intersection(top_5)
            efectividad = (len(coincidencias_5) / 5) * 100
            msj = f"En el sorteo de Miloto, el top 5 de números calientes tuvo una efectividad del {int(efectividad)}%."
            self.guardar_notificacion(2, fecha, msj, "precision")

        except Exception as e:
            print(f"❌ Error procesando notificaciones Miloto: {e}")

    def guardar_notificacion(self, loteria_id, fecha, mensaje, tipo):
        try:
            with self.engine.connect() as conn:
                # Crear tabla si no existe (concurrencia segura)
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS notificaciones (
                        id SERIAL PRIMARY KEY,
                        usuario_id INT,
                        loteria_id INT,
                        fecha_sorteo DATE,
                        mensaje TEXT,
                        tipo VARCHAR(50),
                        leido BOOLEAN DEFAULT FALSE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                """))
                conn.commit()

                # Verificar si ya existe una notificación idéntica para evitar duplicados
                existe = conn.execute(text("""
                    SELECT 1 FROM notificaciones 
                    WHERE loteria_id = :l_id AND fecha_sorteo = :fecha AND mensaje = :msj
                """), {"l_id": loteria_id, "fecha": fecha, "msj": mensaje}).fetchone()

                if not existe:
                    conn.execute(text("""
                        INSERT INTO notificaciones (loteria_id, fecha_sorteo, mensaje, tipo)
                        VALUES (:l_id, :fecha, :msj, :tipo)
                    """), {"l_id": loteria_id, "fecha": fecha, "msj": mensaje, "tipo": tipo})
                    conn.commit()
                    print(f"✅ Notificación guardada: {tipo}")
        except Exception as e:
            print(f"❌ Error al guardar notificación: {e}")

if __name__ == "__main__":
    lot = sys.argv[1] if len(sys.argv) > 1 else "all"
    NotificationGenerator().run(lot)
