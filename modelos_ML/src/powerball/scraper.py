import sys
import time
from pathlib import Path
from datetime import datetime, timedelta, date
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

class PowerballScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 5
        self.base_url = "https://www.powerball.com/es/sorteos-anteriores"
        self.game_code = "powerball"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "X-Requested-With": "XMLHttpRequest"
        }
        # Sorteos: Lunes (0), Miércoles (2), Sábados (5)
        self.draw_days = (0, 2, 5)

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in self.draw_days:
            candidate += timedelta(days=1)
        return candidate

    def obtener_ultimo_sorteo_db(self) -> dict:
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja
                    FROM resultados_powerball
                    WHERE balota1 > 0
                    ORDER BY fecha DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "fecha": row[0],
                        "balotas": [row[1], row[2], row[3], row[4], row[5]],
                        "powerball": row[6]
                    }
        except Exception as e:
            print(f"⚠️ Error obteniendo último sorteo de BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        try:
            r = requests.get(self.base_url, params={"gc": self.game_code, "pg": 1}, headers=self.headers, timeout=10)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                card = soup.select_one("a.card")
                if card:
                    href = card.get("href", "")
                    fecha_str = parse_qs(urlparse(href).query).get("date", [None])[0]
                    ball_divs = card.select(".game-ball-group .form-control div")
                    balls = [int(b.get_text(strip=True)) for b in ball_divs if b.get_text(strip=True).isdigit()]
                    if fecha_str and len(balls) == 6:
                        return {
                            "fecha": fecha_str,
                            "balotas": balls[:5],
                            "powerball": balls[5]
                        }
        except Exception as e:
            print(f"⚠️ Error consultando powerball.com: {e}")
        return None

    def update_jackpot(self, engine, loteria, jackpot, fecha_str):
        if not jackpot or not fecha_str:
            return
        fecha = None
        try:
            fecha = datetime.strptime(fecha_str.strip(), "%a, %b %d, %Y").date()
        except Exception:
            try:
                fecha = pd.to_datetime(fecha_str).date()
            except Exception as ex:
                print(f"Error parsing date {fecha_str} for {loteria}: {ex}")
        
        if not fecha:
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
                conn.commit()
        except Exception as e:
            print(f"Error updating jackpot for {loteria} in DB: {e}")

    def _actualizar_jackpot_oficial(self):
        try:
            r_main = requests.get("https://www.powerball.com/", headers={"User-Agent": "Mozilla/5.0"}, timeout=10)
            if r_main.status_code == 200:
                soup_main = BeautifulSoup(r_main.text, "html.parser")
                date_el = soup_main.find(class_="title-date")
                fecha_str = date_el.get_text(strip=True) if date_el else None
                jackpot = None
                for group in soup_main.find_all(class_="game-detail-group"):
                    title_el = group.find(class_="game-title")
                    if title_el and "estimated jackpot" in title_el.get_text().lower():
                        num_el = group.find(class_="game-jackpot-number")
                        if num_el:
                            jackpot = num_el.get_text(strip=True)
                            break
                            
                if jackpot and fecha_str:
                    self.update_jackpot(self.engine, "powerball", jackpot, fecha_str)
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Powerball: {e}")

    def _asegurar_placeholder(self, ultima_fecha_real: date):
        prox_date = self._calcular_proximo_sorteo(ultima_fecha_real)
        prox_fecha_str = prox_date.strftime("%Y-%m-%d")

        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_powerball
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": prox_fecha_str})

            conn.execute(text("""
                INSERT INTO resultados_powerball (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balotaroja,
                    created_at, updated_at
                ) VALUES (
                    NULL, :loteria_id, 'Powerball', :fecha,
                    0, 0, 0, 0, 0, 0,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
                ON CONFLICT (fecha, sorteo) DO UPDATE SET
                    balota1 = 0, balota2 = 0, balota3 = 0,
                    balota4 = 0, balota5 = 0, balotaroja = 0,
                    updated_at = CURRENT_TIMESTAMP;
            """), {
                "loteria_id": self.loteria_id,
                "fecha": prox_fecha_str
            })

        print(f"🎯 Placeholder verificado para Powerball ({prox_fecha_str})")
        return prox_fecha_str

    def run(self, max_pages=None):
        print("🚀 Iniciando Scraping de Powerball...")
        
        # 1. Asegurar tabla e índices
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_powerball (
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
                CREATE UNIQUE INDEX IF NOT EXISTS uq_powerball_fecha_sorteo ON resultados_powerball (fecha, sorteo);
            """))

        # 2. Detección temprana
        db_ultimo = self.obtener_ultimo_sorteo_db()
        fuente_info = self.extraer_ultimo_sorteo_fuente()

        if fuente_info and db_ultimo:
            fecha_fuente = str(fuente_info.get("fecha"))
            fecha_db = str(db_ultimo.get("fecha"))

            if fecha_fuente <= fecha_db:
                print(f"\nℹ️ [DETECCIÓN TEMPRANA] No hay sorteos nuevos para Powerball.")
                print(f"  Último sorteo en fuente: {fecha_fuente}")
                print(f"  Último sorteo en BD:     {fecha_db}")
                
                self._actualizar_jackpot_oficial()
                prox_f = self._asegurar_placeholder(db_ultimo["fecha"])

                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"Fecha {fecha_db}",
                    "proximo_esperado": f"Fecha {prox_f}"
                }

        # 3. Scraping paginado
        existing_df = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                existing_df = pd.read_sql(text("SELECT * FROM resultados_powerball WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        pages_to_scrape = max_pages or (5 if len(existing_df) > 100 else 100)
        resultados = []
        pagina = 1
        while pagina <= pages_to_scrape:
            print(f"➡️ Scrapeando página {pagina} de Powerball...")
            params = {"gc": self.game_code, "pg": pagina}
            try:
                response = requests.get(self.base_url, params=params, headers=self.headers, timeout=15)
                if response.status_code == 200:
                    soup = BeautifulSoup(response.text, "html.parser")
                    cards = soup.select("a.card")
                    if not cards:
                        break

                    for card in cards:
                        href = card.get("href", "")
                        fecha_str = parse_qs(urlparse(href).query).get("date", [None])[0]
                        if not fecha_str:
                            continue

                        ball_group = card.select_one(".game-ball-group")
                        if not ball_group:
                            continue

                        ball_divs = ball_group.select(".form-control div")
                        numeros = [int(b.get_text(strip=True)) for b in ball_divs if b.get_text(strip=True).isdigit()]

                        if len(numeros) == 6:
                            resultados.append(["Powerball", fecha_str] + numeros)
                else:
                    break
            except Exception as e:
                print(f"⚠️ Error en página {pagina}: {e}")
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
            print("❌ No se lograron recuperar registros de Powerball.")
            return False

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce')
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values(by='fecha', ascending=False).reset_index(drop=True)

        ultima_fecha_real = df_combined.iloc[0]['fecha'].date()
        prox_date = self._calcular_proximo_sorteo(ultima_fecha_real)

        fila_proximo = {
            'concurso': None,
            'loteria_id': self.loteria_id,
            'sorteo': 'Powerball',
            'fecha': prox_date,
            'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0,
            'balotaroja': 0
        }

        if not existing_df.empty:
            fechas_existentes = set(pd.to_datetime(existing_df['fecha']).dt.date)
            df_nuevos = df_combined[~df_combined['fecha'].dt.date.isin(fechas_existentes)]
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_nuevos], ignore_index=True)
        else:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 4. Limpieza segura de placeholders obsoletos
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_powerball
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": prox_date})

        # 5. Guardar en PostgreSQL
        insert_sql = """
            INSERT INTO resultados_powerball (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_powerball.concurso),
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
        for _, row in df_to_save.iterrows():
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
                int(row.get('balotaroja', 0))
            ))

        raw_conn = self.engine.raw_connection()
        try:
            with raw_conn.cursor() as cur:
                execute_values(
                    cur, insert_sql, records,
                    template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                )
            raw_conn.commit()
            print(f"✅ Resultados de Powerball guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        self._actualizar_jackpot_oficial()
        return True

if __name__ == "__main__":
    PowerballScraper().run()
