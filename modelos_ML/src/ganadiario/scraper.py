import sys
import re
import requests
import pandas as pd
import concurrent.futures
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class GanaDiarioScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-PE,es-419;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.url_oficial = "https://www.latinka.com.pe/p/juega-ganadiario.html"
        self.url_sitemap = "https://tinkaresultados.com/sitemap.xml"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de Gana Diario: Todos los días (Diario)."""
        return ultima_fecha_real + timedelta(days=1)

    def extraer_premio_oficial(self) -> str:
        """Extrae el Premio Diario en tiempo real desde el portal oficial."""
        print(f"➡️ Consultando Premio Diario oficial en {self.url_oficial}...")
        try:
            r = requests.get(self.url_oficial, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                for tag in soup.find_all(["div", "span", "h1", "h2", "h3"]):
                    txt = tag.get_text(strip=True)
                    if "premio" in txt.lower() and "s/" in txt.lower():
                        m = re.search(r'S/\s*([0-9\',.]+)', txt)
                        if m:
                            clean_m = m.group(1).replace("'", ",").replace(" ", "")
                            return f"S/ {clean_m}"
        except Exception as e:
            print(f"⚠️ Error extrayendo Premio de Gana Diario: {e}")

        return "S/ 200,000"

    def _parsear_jugada(self, url: str) -> dict:
        """Descarga y parsea una página individual de sorteo de Gana Diario."""
        try:
            r = requests.get(url, headers=self.headers, timeout=6, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                txt = soup.get_text()

                m_date = re.search(r'Fecha:\s*(\d{1,2})/(\d{1,2})/(\d{4})', txt)
                if m_date:
                    d, m, y = m_date.groups()
                    fecha_iso = f"{y}-{m.zfill(2)}-{d.zfill(2)}"
                else:
                    return None

                # 5 números ganadores
                m_balls = re.search(r'(?:Jugada Ganadora|Fecha:\s*\d{1,2}/\d{1,2}/\d{4})\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.IGNORECASE)
                if m_balls:
                    balls = sorted([int(x) for x in m_balls.groups()])
                else:
                    return None

                return {
                    "sorteo": "Gana Diario",
                    "fecha": fecha_iso,
                    "balota1": balls[0],
                    "balota2": balls[1],
                    "balota3": balls[2],
                    "balota4": balls[3],
                    "balota5": balls[4],
                    "balotaroja": 0
                }
        except Exception:
            pass
        return None

    def extraer_historico_concurrente(self, max_draws: int = 500) -> pd.DataFrame:
        """Obtiene URLs del sitemap y descarga los sorteos históricos de Gana Diario concurrentemente."""
        print(f"➡️ Obteniendo lista de sorteos históricos de Gana Diario...")
        try:
            r = requests.get(self.url_sitemap, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                urls = re.findall(r'<loc>(.*?)</loc>', r.text)
                gd_urls = [u for u in urls if 'gana-diario' in u.lower() and 'sorteo-' in u.lower()][:max_draws]
                print(f"Descargando {len(gd_urls)} sorteos de Gana Diario concurrentemente...")

                draws = []
                with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
                    results = list(executor.map(self._parsear_jugada, gd_urls))

                for res in results:
                    if res:
                        draws.append(res)

                # También agregar el último sorteo de la página principal
                ultimo_res = self._parsear_jugada("https://www.tinkaresultados.com/gana-diario")
                if ultimo_res:
                    draws.append(ultimo_res)

                print(f"📊 Sorteos procesados de Gana Diario: {len(draws)}")
                return pd.DataFrame(draws)
        except Exception as e:
            print(f"⚠️ Error descargando histórico: {e}")

        return pd.DataFrame()

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el premio de Gana Diario en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "S/ 200,000"
        print(f"💰 Actualizando jackpot para Gana Diario: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "ganadiario",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Gana Diario: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Gana Diario (Perú)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_ganadiario WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar histórico y premio oficial
        premio_oficial = self.extraer_premio_oficial()

        if backfill or df_existente.empty or len(df_existente) < 50:
            df_scraped = self.extraer_historico_concurrente(max_draws=500)
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Gana Diario.")
            return

        # 3. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_existente, df_scraped], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values('fecha', ascending=False).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return

        # 4. Calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo agregada para Gana Diario: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "sorteo": "Gana Diario",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
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
            'balotaroja': Integer()
        }

        with self.engine.connect() as conn:

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                import pandas as pd
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_ganadiario")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_ganadiario', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.commit()

        print(f"✅ Resultados de Gana Diario guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, premio_oficial)

if __name__ == "__main__":
    scraper = GanaDiarioScraper()
    scraper.run(backfill=True)
