import sys
import re
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class EuroDreamsScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        }
        self.url_recientes = "https://www.combinacionganadora.com/eurodreams/resultados/"
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
        }

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """
        Los sorteos de EuroDreams se realizan los Lunes (weekday 0) y Jueves (weekday 3).
        """
        draw_days = (0, 3)
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_recientes(self) -> pd.DataFrame:
        """Extrae los últimos resultados disponibles desde combinacionganadora."""
        print(f"➡️ Solicitando resultados recientes de EuroDreams desde {self.url_recientes}...")
        try:
            r = requests.get(self.url_recientes, headers=self.headers, timeout=10)
            if r.status_code != 200:
                print(f"⚠️ Error al acceder a recientes: Status {r.status_code}")
                return pd.DataFrame()

            s = BeautifulSoup(r.text, "html.parser")
            blocks = s.find_all("div", class_="gameSummaryBlock")
            draws = []
            for b in blocks:
                date_span = b.find("span", class_=re.compile(r'fdEurodreams|fontSize', re.I))
                if not date_span:
                    continue
                date_txt = date_span.get_text(strip=True)
                m = re.search(r'(\d{1,2})\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+(\d{4})', date_txt)
                if not m:
                    continue
                day, mon_str, yr = m.groups()
                mon_num = self.meses.get(mon_str.lower().strip())
                if not mon_num:
                    continue
                fecha_str = f"{yr}-{mon_num}-{day.zfill(2)}"

                ul = b.find("ul", class_=re.compile(r'numbers', re.I))
                if not ul:
                    continue
                lis = ul.find_all("li")
                if len(lis) < 7:
                    continue

                nums = []
                for li in lis[:6]:
                    t = li.get_text(strip=True)
                    if t.isdigit():
                        nums.append(int(t))

                dream_m = re.search(r'(\d+)', lis[6].get_text(strip=True))
                dream = int(dream_m.group(1)) if dream_m else None

                if len(nums) == 6 and dream is not None:
                    draws.append({
                        "sorteo": "EuroDreams",
                        "fecha": fecha_str,
                        "balota1": nums[0],
                        "balota2": nums[1],
                        "balota3": nums[2],
                        "balota4": nums[3],
                        "balota5": nums[4],
                        "balota6": nums[5],
                        "balotaroja": dream
                    })

            return pd.DataFrame(draws)
        except Exception as e:
            print(f"❌ Error extrayendo recientes de EuroDreams: {e}")
            return pd.DataFrame()

    def extraer_historico_completo(self) -> pd.DataFrame:
        """
        Descarga todo el histórico de EuroDreams desde su sorteo inaugural (06/11/2023)
        mediante concurrencia multihilo.
        """
        print("📚 Iniciando extracción histórica completa de EuroDreams desde 2023...")
        start_date = datetime(2023, 11, 6).date()
        end_date = datetime.now().date()

        draw_dates = []
        curr = start_date
        while curr <= end_date:
            if curr.weekday() in (0, 3): # Lunes y Jueves
                draw_dates.append(curr.strftime("%Y-%m-%d"))
            curr += timedelta(days=1)

        print(f"⏳ Consultando {len(draw_dates)} fechas de sorteos históricos...")

        def _fetch_single_draw(date_str):
            url = f"https://www.combinacionganadora.com/eurodreams/resultados/{date_str}/"
            try:
                r = requests.get(url, headers=self.headers, timeout=8)
                if r.status_code == 200:
                    s = BeautifulSoup(r.text, "html.parser")
                    ul = s.find("ul", class_=re.compile(r'numbers|sexy', re.I))
                    if ul:
                        lis = ul.find_all("li")
                        if len(lis) >= 7:
                            nums = [int(li.get_text(strip=True)) for li in lis[:6] if li.get_text(strip=True).isdigit()]
                            dream_m = re.search(r'(\d+)', lis[6].get_text(strip=True))
                            dream = int(dream_m.group(1)) if dream_m else None
                            if len(nums) == 6 and dream is not None:
                                return {
                                    "sorteo": "EuroDreams",
                                    "fecha": date_str,
                                    "balota1": nums[0],
                                    "balota2": nums[1],
                                    "balota3": nums[2],
                                    "balota4": nums[3],
                                    "balota5": nums[4],
                                    "balota6": nums[5],
                                    "balotaroja": dream
                                }
            except Exception:
                pass
            return None

        results = []
        with ThreadPoolExecutor(max_workers=15) as executor:
            futures = {executor.submit(_fetch_single_draw, d): d for d in draw_dates}
            for f in as_completed(futures):
                res = f.result()
                if res:
                    results.append(res)

        df = pd.DataFrame(results)
        print(f"📊 Total sorteos históricos extraídos para EuroDreams: {len(df)}")
        return df

    def actualizar_jackpot(self, proxima_fecha: str):
        """Actualiza el premio de EuroDreams en la tabla loterias_jackpots."""
        jackpot_str = "20.000 €/mes durante 30 años"
        print(f"💰 Actualizando jackpot para eurodreams: {jackpot_str} (Fecha: {proxima_fecha})")
        try:
            with self.engine.connect() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS loterias_jackpots (
                        id SERIAL PRIMARY KEY,
                        loteria VARCHAR(50) NOT NULL,
                        fecha DATE NOT NULL,
                        jackpot VARCHAR(100) NOT NULL,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT uq_loteria_fecha UNIQUE (loteria, fecha)
                    );
                """))
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha)
                    DO UPDATE SET jackpot = EXCLUDED.jackpot, updated_at = CURRENT_TIMESTAMP;
                """), {
                    "loteria": "eurodreams",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_str
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para EuroDreams: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de EuroDreams (España / Europa)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_eurodreams WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar datos
        if backfill or df_existente.empty:
            df_scraped = self.extraer_historico_completo()
        else:
            df_scraped = self.extraer_recientes()

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de EuroDreams.")
            return

        # 3. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_existente, df_scraped], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values('fecha', ascending=False).reset_index(drop=True)

        # Filtrar fechas futuras accidentales
        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        # 4. Calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo agregada para EuroDreams: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "sorteo": "EuroDreams",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balota6": 0,
            "balotaroja": 0
        }
        df_final = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 5. Guardar en PostgreSQL
        dtypes = {
            'sorteo': String(50),
            'fecha': Date(),
            'balota1': Integer(),
            'balota2': Integer(),
            'balota3': Integer(),
            'balota4': Integer(),
            'balota5': Integer(),
            'balota6': Integer(),
            'balotaroja': Integer(),
        }

        with self.engine.connect() as conn:

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_eurodreams")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_eurodreams', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.commit()

        print(f"✅ Resultados de EuroDreams guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str)

if __name__ == "__main__":
    scraper = EuroDreamsScraper()
    scraper.run(backfill=True)
