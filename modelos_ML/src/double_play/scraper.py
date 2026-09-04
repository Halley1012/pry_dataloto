import sys
import time
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
import requests
from bs4 import BeautifulSoup
from urllib.parse import parse_qs, urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine
from sqlalchemy import text
from psycopg2.extras import execute_values

class DoublePlayScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 13
        self.base_url = "https://www.powerball.com/es/sorteos-anteriores"
        self.game_code = "pb-double-play"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "X-Requested-With": "XMLHttpRequest"
        }
        self.draw_days = (0, 2, 5) # Lunes, Miércoles, Sábados

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

    def run(self, max_pages=None):
        print("🚀 Iniciando Scraping de Double Play...")
        
        existing_df = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                res = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'resultados_double_play';")).scalar()
                if res > 0:
                    existing_df = pd.read_sql(text("SELECT * FROM resultados_double_play WHERE balota1 > 0;"), conn)
                    print(f"📦 Registros históricos existentes en BD: {len(existing_df)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        pages_to_scrape = max_pages
        if pages_to_scrape is None:
            pages_to_scrape = 5 if len(existing_df) > 100 else 100

        resultados = []
        pagina = 1
        while True:
            if pagina > pages_to_scrape:
                print(f"🛑 Se alcanzó el límite de páginas a scrapear ({pages_to_scrape}).")
                break
            print(f"➡️ Scrapeando página {pagina} de Double Play...")
            params = {"gc": self.game_code, "pg": pagina}
            response = None
            max_intentos = 3

            for intento in range(max_intentos):
                try:
                    response = requests.get(self.base_url, params=params, headers=self.headers, timeout=15)
                    if response.status_code == 200:
                        break
                except requests.exceptions.RequestException as e:
                    if intento < max_intentos - 1:
                        wait = (intento + 1) * 3
                        print(f"🔄 Error de conexión en pág {pagina} ({e}). Reintentando en {wait}s...")
                        time.sleep(wait)

            if not response or response.status_code != 200:
                print(f"⚠️ Saltando página {pagina} por error de respuesta.")
                break

            soup = BeautifulSoup(response.text, "html.parser")
            cards = soup.select("a.card")
            if not cards:
                print(f"📄 No se encontraron más tarjetas en la página {pagina}. Finalizando recorrido.")
                break

            for card in cards:
                href = card.get("href", "")
                parsed_url = urlparse(href)
                query_params = parse_qs(parsed_url.query)
                
                fecha_str = query_params.get("date", [None])[0]
                if not fecha_str:
                    continue

                ball_group = card.select_one(".game-ball-group")
                if not ball_group:
                    continue

                ball_divs = ball_group.select(".form-control div")
                numeros = []
                for b in ball_divs:
                    txt = b.get_text(strip=True)
                    if txt.isdigit():
                        numeros.append(int(txt))

                if len(numeros) == 6:
                    resultados.append(["Double Play", fecha_str] + numeros)

            pagina += 1
            time.sleep(0.3)

        columns = ["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"]
        df_new = pd.DataFrame(resultados, columns=columns) if resultados else pd.DataFrame(columns=columns)

        if not existing_df.empty:
            df_combined = pd.concat([df_new, existing_df], ignore_index=True)
        else:
            df_combined = df_new

        if df_combined.empty:
            print("❌ No se lograron recuperar registros históricos de Double Play.")
            return

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce')
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values(by='fecha', ascending=False).reset_index(drop=True)
        df_final = df_combined

        # --- Agregar fila del próximo sorteo en cero ---
        cur_date = None
        try:
            fecha_max_hist = df_final['fecha'].max()
            cur_date = fecha_max_hist + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)

            if df_final['fecha'].max() < cur_date:
                df_prox = pd.DataFrame([{
                    'concurso': None,
                    'loteria_id': self.loteria_id,
                    'sorteo': 'Double Play',
                    'fecha': cur_date,
                    'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0,
                    'balotaroja': 0
                }])
                df_final = pd.concat([df_prox, df_final], ignore_index=True)
                print(f"📅 Fecha del próximo sorteo agregada para Double Play: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Double Play: {e}")

        df_final = df_final.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(by='fecha', ascending=False).reset_index(drop=True)

        # Guardar en PostgreSQL vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_double_play (
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
                CREATE UNIQUE INDEX IF NOT EXISTS uq_double_play_fecha_sorteo ON resultados_double_play (fecha, sorteo);
            """))

        insert_sql = """
            INSERT INTO resultados_double_play (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_double_play.concurso),
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
            print(f"✅ Resultados de Double Play guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        # Double Play jackpot fijo de $10 Millones
        if cur_date:
            fecha_guardar = cur_date.date() if hasattr(cur_date, 'date') else cur_date
            self.update_jackpot(self.engine, "double_play", "$10 Million", fecha_guardar)

        return True

if __name__ == "__main__":
    DoublePlayScraper().run()
