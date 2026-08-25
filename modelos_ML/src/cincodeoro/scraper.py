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

class CincoDeOroScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-UY,es-419;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.base_url = "https://www.combinacionganadora.com/uy/5-de-oro/resultados"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de 5 de Oro: Miércoles (2) y Domingos (6)."""
        dias_validos = {2, 6}
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in dias_validos:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_estimado(self) -> str:
        """Extrae el pozo acumulado para el próximo sorteo."""
        print(f"➡️ Consultando pozo estimado de 5 de Oro...")
        try:
            r = requests.get(f"{self.base_url}/", headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                for tag in soup.find_all(["div", "span", "p", "h1", "h2", "h3"]):
                    txt = tag.get_text(strip=True)
                    if any(k in txt.lower() for k in ["pozo de oro", "pozo estimado", "acumulado", "pozos"]) and "$" in txt:
                        m = re.search(r'\$\s*([0-9\',.]+)', txt)
                        if m:
                            clean_m = m.group(1).replace("'", ",").replace(" ", "")
                            return f"$ {clean_m}"
        except Exception as e:
            print(f"⚠️ Error consultando pozo de 5 de Oro: {e}")

        return "$ 48.000.000"

    def _parsear_sorteo_fecha(self, fecha_str: str) -> dict:
        """Descarga y parsea el sorteo de una fecha específica."""
        url = f"{self.base_url}/{fecha_str}/"
        try:
            r = requests.get(url, headers=self.headers, timeout=6, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                uls = soup.find_all("ul", class_=re.compile(r"numbers"))
                if len(uls) >= 1:
                    # Primer UL: Pozo de Oro (5 números + Extra)
                    oro_items = [li.get_text(strip=True) for li in uls[0].find_all("li")]
                    main_balls = []
                    extra_ball = 0
                    for item in oro_items:
                        if "E" in item:
                            m_e = re.search(r'(\d+)', item)
                            if m_e:
                                extra_ball = int(m_e.group(1))
                        else:
                            m_b = re.search(r'(\d+)', item)
                            if m_b:
                                main_balls.append(int(m_b.group(1)))

                    # Segundo UL: Pozo Revancha (5 números)
                    rev_balls = []
                    if len(uls) >= 2:
                        for li in uls[1].find_all("li"):
                            m_r = re.search(r'(\d+)', li.get_text(strip=True))
                            if m_r:
                                rev_balls.append(int(m_r.group(1)))

                    if len(main_balls) == 5:
                        main_sorted = sorted(main_balls)
                        rev_sorted = sorted(rev_balls) if len(rev_balls) == 5 else [0, 0, 0, 0, 0]
                        return {
                            "sorteo": "5 de Oro",
                            "fecha": fecha_str,
                            "balota1": main_sorted[0],
                            "balota2": main_sorted[1],
                            "balota3": main_sorted[2],
                            "balota4": main_sorted[3],
                            "balota5": main_sorted[4],
                            "balotaroja": extra_ball,
                            "revancha1": rev_sorted[0],
                            "revancha2": rev_sorted[1],
                            "revancha3": rev_sorted[2],
                            "revancha4": rev_sorted[3],
                            "revancha5": rev_sorted[4]
                        }
        except Exception:
            pass
        return None

    def extraer_historico_concurrente(self, max_draws: int = 350) -> pd.DataFrame:
        """Genera fechas pasadas de Miércoles y Domingos y descarga los sorteos concurrentemente."""
        print(f"➡️ Generando fechas de sorteos pasados (Miércoles y Domingos)...")
        fechas = []
        curr = datetime.now().date()
        while len(fechas) < max_draws:
            if curr.weekday() in (2, 6): # Miércoles (2), Domingo (6)
                fechas.append(curr.strftime("%Y-%m-%d"))
            curr -= timedelta(days=1)

        print(f"Descargando {len(fechas)} sorteos históricos de 5 de Oro concurrentemente...")
        draws = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
            results = list(executor.map(self._parsear_sorteo_fecha, fechas))

        for res in results:
            if res:
                draws.append(res)

        print(f"📊 Sorteos procesados de 5 de Oro: {len(draws)}")
        return pd.DataFrame(draws)

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el pozo de 5 de Oro en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "$ 48.000.000"
        print(f"💰 Actualizando jackpot para 5 de Oro: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "5deoro",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para 5 de Oro: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de 5 de Oro y Revancha (Uruguay)...")

        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_5deoro WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar histórico y pozo estimado
        pozo_oficial = self.extraer_pozo_estimado()

        if backfill or df_existente.empty or len(df_existente) < 50:
            df_scraped = self.extraer_historico_concurrente(max_draws=350)
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de 5 de Oro.")
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
        print(f"📅 Fecha del próximo sorteo agregada para 5 de Oro: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "sorteo": "5 de Oro",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balotaroja": 0,
            "revancha1": 0,
            "revancha2": 0,
            "revancha3": 0,
            "revancha4": 0,
            "revancha5": 0
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
            'balotaroja': Integer(),
            'revancha1': Integer(),
            'revancha2': Integer(),
            'revancha3': Integer(),
            'revancha4': Integer(),
            'revancha5': Integer()
        }

        with self.engine.connect() as conn:
            df_final.to_sql('resultados_5deoro', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.commit()

        print(f"✅ Resultados de 5 de Oro guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, pozo_oficial)

if __name__ == "__main__":
    scraper = CincoDeOroScraper()
    scraper.run(backfill=True)
