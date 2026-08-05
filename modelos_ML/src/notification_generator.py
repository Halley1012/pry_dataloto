import sys
import pandas as pd
from pathlib import Path
from sqlalchemy import text
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class NotificationGenerator:
    def __init__(self):
        self.engine = get_engine()

    def _get_mitad(self, pred_nums):
        total = len(pred_nums)
        if total <= 43:
            return 20  # Baloto (43) y Miloto (39): 20 más probables
        return round(total / 2)  # Powerball(35), MegaMillions(35), LottoAmerica(26), MillionaireLife(30), DoublePlay(35)

    def run(self, loteria="all"):
        print(f"🔔 Iniciando Generador de Notificaciones para: {loteria}")
        if loteria in ["baloto", "all"]:
            self.procesar_baloto()
        if loteria in ["miloto", "all"]:
            self.procesar_miloto()
        if loteria in ["powerball", "all"]:
            self.procesar_generico("powerball", "Powerball", "resultados_powerball", "predicciones_powerball", 3)
        if loteria in ["lotto_america", "all"]:
            self.procesar_generico("lotto_america", "Lotto America", "resultados_lotto_america", "predicciones_lotto_america", 4)
        if loteria in ["double_play", "all"]:
            self.procesar_generico("double_play", "Double Play", "resultados_double_play", "predicciones_double_play", 5)
        if loteria in ["millionaire_life", "all"]:
            self.procesar_generico("millionaire_life", "Millionaire for Life", "resultados_millionaire_life", "predicciones_millionaire_life", 6)
        if loteria in ["megamillions", "all"]:
            self.procesar_generico("megamillions", "Mega Millions", "resultados_megamillions", "predicciones_megamillions", 7)

    def procesar_baloto(self):
        try:
            # Obtener último resultado con balotas válidas (> 0)
            res = pd.read_sql('SELECT * FROM resultados_bloto WHERE sorteo = \'Baloto\' AND balota1 > 0 ORDER BY fecha DESC LIMIT 1', self.engine)
            if res.empty: return
            
            fecha = res.iloc[0]['fecha']
            ganadores = set([res.iloc[0][f'balota{i}'] for i in range(1, 6)])
            super_ganadora = res.iloc[0]['balotaroja']

            # Obtener predicción para esa fecha
            pred = pd.read_sql(text('SELECT * FROM predicciones_bloto WHERE fecha = :fecha'), self.engine, params={"fecha": fecha})
            if pred.empty: return

            pred_nums = pred.iloc[0]['numeros']
            pred_rojas = pred.iloc[0]['balotaroja']

            mitad = self._get_mitad(pred_nums)
            top_mitad = set(pred_nums[:mitad])
            coincidencias = ganadores.intersection(top_mitad)

            # 1. Casi! (Acierto parcial en el top de más probables)
            if len(coincidencias) >= 3:
                msj = f"¡Casi! De los {mitad} números con mayor probabilidad generados por la IA para Baloto, cayeron {len(coincidencias)} números ({', '.join(map(str, sorted(list(coincidencias))))})."
                self.guardar_notificacion(1, fecha, msj, "acierto_parcial")

            # 2. Superbalota
            if super_ganadora == pred_rojas[0]:
                msj = "¡La IA acertó la Superbalota en el sorteo de hoy de Baloto!"
                self.guardar_notificacion(1, fecha, msj, "acierto_directo")

            # 3. Precisión sobre los números más probables (mitad de balotas)
            efectividad = (len(coincidencias) / 5) * 100
            msj = f"En el sorteo de Baloto, los {mitad} números más probables tuvieron una efectividad del {int(efectividad)}% ({len(coincidencias)} de 5 aciertos)."
            self.guardar_notificacion(1, fecha, msj, "precision")

        except Exception as e:
            print(f"❌ Error procesando notificaciones Baloto: {e}")

    def procesar_miloto(self):
        try:
            # Obtener último resultado con balotas válidas (> 0)
            res = pd.read_sql('SELECT * FROM resultados_mloto WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1', self.engine)
            if res.empty: return
            
            fecha = res.iloc[0]['fecha']
            ganadores = set([res.iloc[0][f'balota{i}'] for i in range(1, 6)])

            # Obtener predicción para esa fecha
            pred = pd.read_sql(text('SELECT * FROM predicciones_mloto WHERE fecha = :fecha'), self.engine, params={"fecha": fecha})
            if pred.empty: return

            pred_nums = pred.iloc[0]['numeros']
            mitad = self._get_mitad(pred_nums)
            top_mitad = set(pred_nums[:mitad])
            coincidencias = ganadores.intersection(top_mitad)

            # 1. Casi!
            if len(coincidencias) >= 3:
                msj = f"¡Casi! De los {mitad} números con mayor probabilidad generados por la IA para Miloto, cayeron {len(coincidencias)} números ({', '.join(map(str, sorted(list(coincidencias))))})."
                self.guardar_notificacion(2, fecha, msj, "acierto_parcial")

            # 2. Precisión
            efectividad = (len(coincidencias) / 5) * 100
            msj = f"En el sorteo de Miloto, los {mitad} números más probables tuvieron una efectividad del {int(efectividad)}% ({len(coincidencias)} de 5 aciertos)."
            self.guardar_notificacion(2, fecha, msj, "precision")

        except Exception as e:
            print(f"❌ Error procesando notificaciones Miloto: {e}")

    def procesar_generico(self, clave_loteria, nombre_display, tabla_resultados, tabla_predicciones, loteria_id):
        try:
            res = pd.read_sql(f'SELECT * FROM {tabla_resultados} WHERE balota1 > 0 ORDER BY fecha DESC LIMIT 1', self.engine)
            if res.empty: return

            fecha = res.iloc[0]['fecha']
            ganadores = set([res.iloc[0][f'balota{i}'] for i in range(1, 6)])
            super_ganadora = res.iloc[0].get('balotaroja', None)

            pred = pd.read_sql(text(f'SELECT * FROM {tabla_predicciones} WHERE fecha = :fecha'), self.engine, params={"fecha": fecha})
            if pred.empty: return

            pred_nums = pred.iloc[0]['numeros']
            pred_rojas = pred.iloc[0].get('balotaroja', None)

            mitad = self._get_mitad(pred_nums)
            top_mitad = set(pred_nums[:mitad])
            coincidencias = ganadores.intersection(top_mitad)

            if len(coincidencias) >= 3:
                msj = f"¡Casi! De los {mitad} números con mayor probabilidad generados por la IA para {nombre_display}, cayeron {len(coincidencias)} números ({', '.join(map(str, sorted(list(coincidencias))))})."
                self.guardar_notificacion(loteria_id, fecha, msj, "acierto_parcial")

            if super_ganadora is not None and pred_rojas is not None and len(pred_rojas) > 0:
                if super_ganadora == pred_rojas[0]:
                    msj = f"¡La IA acertó la balota especial en el sorteo de hoy de {nombre_display}!"
                    self.guardar_notificacion(loteria_id, fecha, msj, "acierto_directo")

            efectividad = (len(coincidencias) / 5) * 100
            msj = f"En el sorteo de {nombre_display}, los {mitad} números más probables tuvieron una efectividad del {int(efectividad)}% ({len(coincidencias)} de 5 aciertos)."
            self.guardar_notificacion(loteria_id, fecha, msj, "precision")

        except Exception as e:
            print(f"❌ Error procesando notificaciones {nombre_display}: {e}")

    def guardar_notificacion(self, loteria_id, fecha, mensaje, tipo):
        try:
            with self.engine.connect() as conn:
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

                # Reemplazar o actualizar si ya existe para esa lotería, fecha y tipo
                conn.execute(text("""
                    DELETE FROM notificaciones 
                    WHERE loteria_id = :l_id AND fecha_sorteo = :fecha AND tipo = :tipo
                """), {"l_id": loteria_id, "fecha": fecha, "tipo": tipo})
                conn.commit()

                conn.execute(text("""
                    INSERT INTO notificaciones (loteria_id, fecha_sorteo, mensaje, tipo)
                    VALUES (:l_id, :fecha, :msj, :tipo)
                """), {"l_id": loteria_id, "fecha": fecha, "msj": mensaje, "tipo": tipo})
                conn.commit()
                print(f"✅ Notificación guardada/actualizada ({tipo}): {mensaje}")
        except Exception as e:
            print(f"❌ Error al guardar notificación: {e}")

if __name__ == "__main__":
    lot = sys.argv[1] if len(sys.argv) > 1 else "all"
    NotificationGenerator().run(lot)

