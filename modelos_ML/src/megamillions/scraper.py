import sys
import time
import json
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
import requests

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class MegaMillionsScraper:
    def __init__(self):
        self.api_url = "https://www.megamillions.com/cmspages/utilservice.asmx/GetDrawingPagingData"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Content-Type": "application/json; charset=utf-8"
        }
        self.draw_days = (1, 4) # Martes (1), Viernes (4)

    def update_jackpot(self, engine, loteria, jackpot, fecha):
        if not jackpot or not fecha:
            return
        
        from sqlalchemy import text
        try:
            with engine.connect() as conn:
                print(f"Updating jackpot for {loteria}: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": loteria, "fecha": fecha, "jackpot": jackpot})
                
                # Cleanup older than 5 days
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": loteria})
                conn.commit()
        except Exception as e:
            print(f"Error updating jackpot for {loteria} in DB: {e}")

    def run(self, max_pages=None, page_size=100):
        print("🚀 Iniciando Scraping de Mega Millions...")
        resultados = []

        pagina = 1
        while True:
            if max_pages is not None and pagina > max_pages:
                print(f"🛑 Se alcanzó el límite máximo de páginas especificado ({max_pages}).")
                break
            print(f"➡️ Solicitando datos de la página {pagina} para Mega Millions...")
            payload = {
                "pageNumber": pagina,
                "pageSize": page_size,
                "startDate": "",
                "endDate": ""
            }

            response = None
            max_intentos = 3

            for intento in range(max_intentos):
                try:
                    response = requests.post(self.api_url, headers=self.headers, json=payload, timeout=15)
                    if response.status_code == 200:
                        break
                except requests.exceptions.RequestException as e:
                    if intento < max_intentos - 1:
                        wait = (intento + 1) * 3
                        print(f"🔄 Error de conexión en pág {pagina} ({e}). Reintentando en {wait}s...")
                        time.sleep(wait)

            if not response or response.status_code != 200:
                print(f"⚠️ Saltando página {pagina} debido a error en respuesta API Mega Millions.")
                break

            try:
                res_json = response.json()
                d_str = res_json.get("d", "{}")
                data_dict = json.loads(d_str)
                drawing_data = data_dict.get("DrawingData", [])

                if not drawing_data:
                    print(f"📄 No se encontraron más registros en la página {pagina}.")
                    break

                for d in drawing_data:
                    raw_date = d.get("PlayDate", "")
                    if raw_date:
                        fecha_str = raw_date.split("T")[0]
                        n1 = d.get("N1")
                        n2 = d.get("N2")
                        n3 = d.get("N3")
                        n4 = d.get("N4")
                        n5 = d.get("N5")
                        mball = d.get("MBall")

                        if all(v is not None for v in [n1, n2, n3, n4, n5, mball]):
                            resultados.append(["Mega Millions", fecha_str, int(n1), int(n2), int(n3), int(n4), int(n5), int(mball)])

            except Exception as e:
                print(f"❌ Error al procesar respuesta JSON en pág {pagina}: {e}")
                break

            pagina += 1
            time.sleep(0.5)

        if resultados:
            df = pd.DataFrame(resultados, columns=["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"])
            df['fecha'] = pd.to_datetime(df['fecha'], errors='coerce')
            df = df.drop_duplicates(subset=['fecha']).reset_index(drop=True)
            df_final = df
        else:
            print("❌ No se lograron recuperar registros históricos de Mega Millions.")
            return

        try:
            fecha_max_hist = df_final['fecha'].max()
            cur_date = fecha_max_hist + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)

            df_prox = pd.DataFrame({
                'sorteo': ['Mega Millions'],
                'fecha': [cur_date],
                'balota1': [0], 'balota2': [0], 'balota3': [0], 'balota4': [0], 'balota5': [0],
                'balotaroja': [0]
            })
            df_final = pd.concat([df_final, df_prox], ignore_index=True)
            print(f"📅 Fecha del próximo sorteo agregada para Mega Millions: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Mega Millions: {e}")

        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True)

        try:
            from sqlalchemy.types import Date
            engine = get_engine()

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                import pandas as pd
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_megamillions")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_megamillions', engine, if_exists='replace', index=False, dtype={'fecha': Date()})
            print(f"DataFrame de Mega Millions guardado exitosamente! Total filas: {len(df_final)}")
            return True
            
            # Scrape and save jackpot for Mega Millions
            print("Scraping jackpot for Mega Millions via ASMX service...")
            url_latest = "https://www.megamillions.com/cmspages/utilservice.asmx/GetLatestDrawData"
            resp_latest = requests.post(url_latest, headers=self.headers, json={}, timeout=15)
            if resp_latest.status_code == 200:
                data_latest = resp_latest.json()
                d_dict = json.loads(data_latest.get("d", "{}"))
                jackpot_data = d_dict.get("Jackpot", {})
                
                next_prize = jackpot_data.get("NextPrizePool", 0)
                if next_prize > 0:
                    jackpot = f"${int(next_prize / 1000000)} Million"
                    
                    # Fetch next drawing date
                    url_next = "https://www.megamillions.com/cmspages/utilservice.asmx/GetNextDrawingDate"
                    resp_next = requests.post(url_next, headers=self.headers, json={}, timeout=15)
                    if resp_next.status_code == 200:
                        d_next = resp_next.json().get("d", "")
                        import re
                        match = re.search(r'\d+', d_next)
                        if match:
                            ts = int(match.group()) / 1000
                            from datetime import timezone
                            fecha_next = datetime.fromtimestamp(ts, tz=timezone.utc).date()
                            self.update_jackpot(engine, "megamillions", jackpot, fecha_next)
            else:
                print(f"Warning: GetLatestDrawData returned status {resp_latest.status_code}")
        except Exception as e:
            print(f"Error saving results or jackpot for Mega Millions: {e}")

if __name__ == "__main__":
    MegaMillionsScraper().run()
