import sys
import time
import json
import re
from pathlib import Path
from datetime import datetime, timedelta, timezone
import pandas as pd
import requests

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine
from sqlalchemy import text
from psycopg2.extras import execute_values

class MegaMillionsScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 12
        self.api_url = "https://www.megamillions.com/cmspages/utilservice.asmx/GetDrawingPagingData"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Content-Type": "application/json; charset=utf-8"
        }
        self.draw_days = (1, 4) # Martes (1), Viernes (4)

    def update_jackpot(self, engine, loteria, jackpot, fecha):
        if not jackpot or not fecha:
            return
        
        try:
            with engine.connect() as conn:
                print(f"💰 Actualizando jackpot para {loteria}: {jackpot} (Fecha: {fecha})")
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
        
        existing_df = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                res = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'resultados_megamillions';")).scalar()
                if res > 0:
                    existing_df = pd.read_sql(text("SELECT * FROM resultados_megamillions WHERE balota1 > 0;"), conn)
                    print(f"📦 Registros históricos existentes en BD: {len(existing_df)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        pages_to_scrape = max_pages
        if pages_to_scrape is None:
            pages_to_scrape = 2 if len(existing_df) > 100 else 100

        resultados = []
        pagina = 1
        while True:
            if pagina > pages_to_scrape:
                print(f"🛑 Se alcanzó el límite de páginas a scrapear ({pages_to_scrape}).")
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

                        if all(val is not None for val in [n1, n2, n3, n4, n5, mball]):
                            resultados.append(["Mega Millions", fecha_str, int(n1), int(n2), int(n3), int(n4), int(n5), int(mball)])

            except Exception as e:
                print(f"⚠️ Error procesando el JSON de la página {pagina}: {e}")
                break

            pagina += 1
            time.sleep(0.3)

        columns = ["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"]
        df_new = pd.DataFrame(resultados, columns=columns) if resultados else pd.DataFrame(columns=columns)

        if not existing_df.empty:
            df_combined = pd.concat([df_new, existing_df], ignore_index=True)
        else:
            df_combined = df_new

        if df_combined.empty:
            print("❌ No se lograron recuperar registros históricos de Mega Millions.")
            return

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce')
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values(by='fecha', ascending=False).reset_index(drop=True)
        df_final = df_combined

        # --- Agregar fila del próximo sorteo en cero ---
        try:
            fecha_max_hist = df_final['fecha'].max()
            cur_date = fecha_max_hist + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)

            if df_final['fecha'].max() < cur_date:
                df_prox = pd.DataFrame([{
                    'concurso': None,
                    'loteria_id': self.loteria_id,
                    'sorteo': 'Mega Millions',
                    'fecha': cur_date,
                    'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0,
                    'balotaroja': 0
                }])
                df_final = pd.concat([df_prox, df_final], ignore_index=True)
                print(f"📅 Fecha del próximo sorteo agregada para Mega Millions: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Mega Millions: {e}")

        df_final = df_final.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(by='fecha', ascending=False).reset_index(drop=True)

        # Guardar en PostgreSQL vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_megamillions (
                    id SERIAL PRIMARY KEY,
                    concurso INT,
                    loteria_id INT REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INT NOT NULL,
                    balota2 INT NOT NULL,
                    balota3 INT NOT NULL,
                    balota4 INT NOT NULL,
                    balota5 INT NOT NULL,
                    balotaroja INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_megamillions_fecha_sorteo ON resultados_megamillions (fecha, sorteo);
            """))

        insert_sql = """
            INSERT INTO resultados_megamillions (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_megamillions.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                balotaroja = EXCLUDED.balotaroja,
                updated_at = CURRENT_TIMESTAMP;
        """

        records = []
        for _, row in df_final.iterrows():
            c_val = int(row['concurso']) if pd.notnull(row.get('concurso')) and row.get('concurso') is not None else None
            f_val = row['fecha'].date() if hasattr(row['fecha'], 'date') else row['fecha']
            records.append((
                c_val,
                self.loteria_id,
                str(row['sorteo']),
                f_val,
                int(row['balota1']),
                int(row['balota2']),
                int(row['balota3']),
                int(row['balota4']),
                int(row['balota5']),
                int(row.get('balotaroja', 0)),
                datetime.now(),
                datetime.now()
            ))

        raw_conn = self.engine.raw_connection()
        try:
            with raw_conn.cursor() as cur:
                execute_values(cur, insert_sql, records, page_size=1000)
            raw_conn.commit()
            print(f"✅ Resultados de Mega Millions guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        # Scrape and save jackpot for Mega Millions
        try:
            print("💰 Scrapeando jackpot para Mega Millions via ASMX service...")
            url_latest = "https://www.megamillions.com/cmspages/utilservice.asmx/GetLatestDrawData"
            resp_latest = requests.post(url_latest, headers=self.headers, json={}, timeout=15)
            if resp_latest.status_code == 200:
                data_latest = resp_latest.json()
                d_dict = json.loads(data_latest.get("d", "{}"))
                jackpot_data = d_dict.get("Jackpot", {})
                
                next_prize = jackpot_data.get("NextPrizePool", 0)
                if next_prize > 0:
                    jackpot = f"${int(next_prize / 1000000)} Million"
                    
                    url_next = "https://www.megamillions.com/cmspages/utilservice.asmx/GetNextDrawingDate"
                    resp_next = requests.post(url_next, headers=self.headers, json={}, timeout=15)
                    if resp_next.status_code == 200:
                        d_next = resp_next.json().get("d", "")
                        match = re.search(r'\d+', d_next)
                        if match:
                            ts = int(match.group()) / 1000
                            fecha_next = datetime.fromtimestamp(ts, tz=timezone.utc).date()
                            self.update_jackpot(self.engine, "megamillions", jackpot, fecha_next)
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Mega Millions: {e}")

        return True

if __name__ == "__main__":
    MegaMillionsScraper().run()
