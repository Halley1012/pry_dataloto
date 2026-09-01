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

class LottoCostaRicaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-CR,es;q=0.9,en;q=0.8",
        }
        self.base_url = "https://www.combinacionganadora.com/cr/lotto-costa-rica/resultados"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de Lotto Costa Rica: Lunes (0), Miércoles (2) y Sábados (5)."""
        dias_validos = {0, 2, 5}
        hoy = datetime.now().date()
        base = max(ultima_fecha_real, hoy)
        
        if hoy.weekday() in dias_validos and ultima_fecha_real < hoy:
            return hoy
            
        candidate = base + timedelta(days=1)
        while candidate.weekday() not in dias_validos or candidate <= ultima_fecha_real:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_estimado(self) -> str:
        """Extrae el pozo acumulado para el próximo sorteo en Colones (CRC)."""
        print("➡️ Consultando pozo estimado de Lotto Costa Rica...")
        try:
            r = requests.get("https://www.combinacionganadora.com/cr/lotto-costa-rica/", headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                for tag in soup.find_all(["div", "span", "p", "h1", "h2", "h3"]):
                    txt = tag.get_text(strip=True)
                    if any(k in txt.lower() for k in ["bote", "acumulado", "pozo", "premio", "estimado"]) and ("₡" in txt or "CRC" in txt or "millones" in txt.lower()):
                        m = re.search(r'([0-9\',.]+)\s*(?:millones|₡|CRC)', txt, re.IGNORECASE)
                        if m:
                            val = m.group(1).replace("'", ",").replace(" ", "")
                            if "millon" in txt.lower():
                                return f"₡ {val} millones"
                            return f"₡ {val}"
        except Exception as e:
            print(f"⚠️ Error consultando pozo de Lotto CR: {e}")

        return "₡ 125.000.000"

    def _parsear_sorteo_fecha(self, fecha_str: str) -> list:
        """Descarga y parsea el sorteo de una fecha retornando filas para Lotto y Revancha."""
        url = f"{self.base_url}/{fecha_str}/"
        try:
            r = requests.get(url, headers=self.headers, timeout=6, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                uls = soup.find_all("ul", class_=re.compile(r"numbers"))
                if len(uls) >= 1:
                    # Primer UL: Lotto (5 números)
                    lotto_items = [int(re.search(r'\d+', li.get_text(strip=True)).group(0)) for li in uls[0].find_all("li") if re.search(r'\d+', li.get_text(strip=True))]
                    
                    # Segundo UL: Revancha (5 números)
                    rev_items = []
                    if len(uls) >= 2:
                        rev_items = [int(re.search(r'\d+', li.get_text(strip=True)).group(0)) for li in uls[1].find_all("li") if re.search(r'\d+', li.get_text(strip=True))]

                    items = []
                    if len(lotto_items) == 5:
                        lotto_sorted = sorted(lotto_items)
                        items.append({
                            "sorteo": "Lotto",
                            "fecha": fecha_str,
                            "balota1": lotto_sorted[0],
                            "balota2": lotto_sorted[1],
                            "balota3": lotto_sorted[2],
                            "balota4": lotto_sorted[3],
                            "balota5": lotto_sorted[4],
                            "balotaroja": 0
                        })

                    if len(rev_items) == 5:
                        rev_sorted = sorted(rev_items)
                        items.append({
                            "sorteo": "Revancha",
                            "fecha": fecha_str,
                            "balota1": rev_sorted[0],
                            "balota2": rev_sorted[1],
                            "balota3": rev_sorted[2],
                            "balota4": rev_sorted[3],
                            "balota5": rev_sorted[4],
                            "balotaroja": 0
                        })
                    
                    if items:
                        return items
        except Exception:
            pass
        return None

    def extraer_historico_concurrente(self, max_draws: int = 350) -> pd.DataFrame:
        """Genera fechas pasadas de Lunes, Miércoles y Sábados y descarga los sorteos concurrentemente."""
        print(f"➡️ Generando fechas de sorteos pasados (Lunes, Miércoles y Sábados)...")
        fechas = []
        curr = datetime.now().date()
        while len(fechas) < max_draws:
            if curr.weekday() in (0, 2, 5): # Lunes (0), Miércoles (2), Sábado (5)
                fechas.append(curr.strftime("%Y-%m-%d"))
            curr -= timedelta(days=1)

        print(f"Descargando {len(fechas)} sorteos de Lotto Costa Rica concurrentemente...")
        draws = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
            results = list(executor.map(self._parsear_sorteo_fecha, fechas))

        for res in results:
            if res:
                if isinstance(res, list):
                    draws.extend(res)
                else:
                    draws.append(res)

        print(f"📊 Filas procesadas de Lotto y Revancha CR: {len(draws)}")
        return pd.DataFrame(draws)

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el pozo de Lotto Costa Rica en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "₡ 125.000.000"
        print(f"💰 Actualizando jackpot para Lotto CR: {jackpot_val} (Fecha: {proxima_fecha})")
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
                for route_key in ["lotto_cr", "lotto / revancha", "lotto costa rica"]:
                    conn.execute(text("""
                        INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                        VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                        ON CONFLICT (loteria, fecha)
                        DO UPDATE SET jackpot = EXCLUDED.jackpot, updated_at = CURRENT_TIMESTAMP;
                    """), {
                        "loteria": route_key,
                        "fecha": proxima_fecha,
                        "jackpot": jackpot_val
                    })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Lotto CR: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Lotto y Revancha (Costa Rica)...")

        pozo_oficial = self.extraer_pozo_estimado()

        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT sorteo, fecha, balota1, balota2, balota3, balota4, balota5, balotaroja FROM resultados_lotto_cr WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar histórico concurrente
        if backfill or df_existente.empty or len(df_existente) < 50:
            df_scraped = self.extraer_historico_concurrente(max_draws=350)
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        # Combinar existente + histórico
        dfs_to_combine = []
        if not df_existente.empty and 'sorteo' in df_existente.columns:
            dfs_to_combine.append(df_existente)
        if not df_scraped.empty:
            dfs_to_combine.append(df_scraped)

        if not dfs_to_combine:
            print("❌ No se pudieron obtener resultados de Lotto Costa Rica.")
            return

        df_combined = pd.concat(dfs_to_combine, ignore_index=True)
        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo']).sort_values(by=['fecha', 'sorteo'], ascending=[False, True]).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return

        # 3. Determinar fecha del próximo sorteo
        df_real = df_combined[df_combined['balota1'] > 0]
        ultima_fecha_real = df_real.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")

        print(f"📅 Fecha del próximo sorteo establecida para Lotto CR: {proxima_fecha_str}")

        # Filas placeholder en ceros
        filas_proximo = [
            {
                "sorteo": "Lotto",
                "fecha": proxima_fecha,
                "balota1": 0,
                "balota2": 0,
                "balota3": 0,
                "balota4": 0,
                "balota5": 0,
                "balotaroja": 0
            },
            {
                "sorteo": "Revancha",
                "fecha": proxima_fecha,
                "balota1": 0,
                "balota2": 0,
                "balota3": 0,
                "balota4": 0,
                "balota5": 0,
                "balotaroja": 0
            }
        ]
        df_final = pd.concat([pd.DataFrame(filas_proximo), df_combined], ignore_index=True)

        # 4. Guardar en PostgreSQL
        dtypes = {
            'sorteo': String(50),
            'fecha': Date(),
            'balota1': Integer(),
            'balota2': Integer(),
            'balota3': Integer(),
            'balota4': Integer(),
            'balota5': Integer(),
            'balotaroja': Integer(),
        }

        with self.engine.connect() as conn:
            df_final.to_sql('resultados_lotto_cr', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.commit()

        print(f"✅ Resultados de Lotto y Revancha CR guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, pozo_oficial)

if __name__ == "__main__":
    scraper = LottoCostaRicaScraper()
    scraper.run(backfill=True)
