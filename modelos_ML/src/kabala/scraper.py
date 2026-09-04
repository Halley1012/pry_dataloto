import sys
import re
import requests
import pandas as pd
import concurrent.futures
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class KabalaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 32
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-PE,es-419;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.url_oficial = "https://www.latinka.com.pe/p/juega-kabala.html"
        self.url_sitemap = "https://tinkaresultados.com/sitemap.xml"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de Kábala: Martes (1), Jueves (3) y Sábados (5)."""
        dias_validos = {1, 3, 5}
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in dias_validos:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_oficial(self) -> str:
        """Extrae el Pozo Buenazo en tiempo real desde el portal oficial."""
        print(f"➡️ Consultando Pozo Buenazo oficial en {self.url_oficial}...")
        try:
            r = requests.get(self.url_oficial, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                for tag in soup.find_all(["div", "span", "h1", "h2", "h3"]):
                    txt = tag.get_text(strip=True)
                    if "pozo" in txt.lower() and "s/" in txt.lower():
                        m = re.search(r'S/\s*([0-9\',.]+)', txt)
                        if m:
                            clean_m = m.group(1).replace("'", ",").replace(" ", "")
                            return f"S/ {clean_m}"
        except Exception as e:
            print(f"⚠️ Error extrayendo Pozo de Kábala: {e}")

        return "S/ 351,140"

    def _parsear_jugada(self, url: str) -> list[dict]:
        """Descarga y parsea una página individual de sorteo de Kábala (Pozo Buenazo + Chau Chamba)."""
        try:
            r = requests.get(url, headers=self.headers, timeout=6, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                txt = soup.get_text()

                m_date = re.search(r'Fecha:\s*(\d{1,2})/(\d{1,2})/(\d{4})', txt)
                if not m_date:
                    return []
                d, m, y = m_date.groups()
                fecha_iso = f"{y}-{m.zfill(2)}-{d.zfill(2)}"

                buenazo_balls = []
                chamba_balls = []

                # Extracción desde tablas HTML
                for table in soup.find_all('table'):
                    t_txt = table.get_text()
                    td_nums = [int(td.get_text(strip=True)) for td in table.find_all(['td', 'span', 'div']) if td.get_text(strip=True).isdigit() and 1 <= int(td.get_text(strip=True)) <= 40]
                    
                    if 'buenazo' in t_txt.lower() or ('chau chamba' not in t_txt.lower() and not buenazo_balls):
                        if len(td_nums) >= 6 and not buenazo_balls:
                            buenazo_balls = td_nums[:6]
                    if 'chau chamba' in t_txt.lower() or 'chamba' in t_txt.lower():
                        if len(td_nums) >= 6 and not chamba_balls:
                            chamba_balls = td_nums[:6]

                # Fallback por expresiones regulares si no se encontró en tablas
                if not buenazo_balls:
                    m_b = re.search(r'Pozo Buenazo\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.I)
                    if m_b:
                        buenazo_balls = [int(x) for x in m_b.groups()]

                if not chamba_balls:
                    m_c = re.search(r'Chau Chamba\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.I)
                    if m_c:
                        chamba_balls = [int(x) for x in m_c.groups()]

                m_sorteo = re.search(r'Sorteo\s*(?:Nro\.?|número)?\s*(\d+)', txt, re.I)
                if not m_sorteo:
                    m_sorteo = re.search(r'sorteo-(\d+)', url)
                concurso_num = int(m_sorteo.group(1)) if m_sorteo else None

                items = []
                if len(buenazo_balls) == 6:
                    b_sorted = sorted(buenazo_balls)
                    items.append({
                        "concurso": concurso_num,
                        "loteria_id": self.loteria_id,
                        "sorteo": "Kábala",
                        "fecha": fecha_iso,
                        "balota1": b_sorted[0],
                        "balota2": b_sorted[1],
                        "balota3": b_sorted[2],
                        "balota4": b_sorted[3],
                        "balota5": b_sorted[4],
                        "balota6": b_sorted[5],
                        "balotaroja": 0
                    })

                if len(chamba_balls) == 6:
                    c_sorted = sorted(chamba_balls)
                    items.append({
                        "concurso": concurso_num,
                        "loteria_id": self.loteria_id,
                        "sorteo": "Chau Chamba",
                        "fecha": fecha_iso,
                        "balota1": c_sorted[0],
                        "balota2": c_sorted[1],
                        "balota3": c_sorted[2],
                        "balota4": c_sorted[3],
                        "balota5": c_sorted[4],
                        "balota6": c_sorted[5],
                        "balotaroja": 0
                    })

                return items
        except Exception:
            pass
        return []

    def extraer_historico_concurrente(self, max_draws: int = 350) -> pd.DataFrame:
        """Obtiene URLs del sitemap y descarga los sorteos históricos de Kábala concurrentemente."""
        print(f"➡️ Obteniendo lista de sorteos históricos de Kábala...")
        try:
            r = requests.get(self.url_sitemap, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                urls = re.findall(r'<loc>(.*?)</loc>', r.text)
                kabala_urls = [u for u in urls if 'kabala' in u.lower() and 'sorteo-' in u.lower()][:max_draws]
                print(f"Descargando {len(kabala_urls)} sorteos de Kábala y Chau Chamba concurrentemente...")

                draws = []
                with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
                    results = list(executor.map(self._parsear_jugada, kabala_urls))

                for res in results:
                    if res:
                        draws.extend(res)

                # Último sorteo desde la página principal de Kábala
                ultimo_res = self._parsear_jugada("https://www.tinkaresultados.com/kabala")
                if ultimo_res:
                    draws.extend(ultimo_res)

                print(f"📊 Sorteos procesados de Kábala y Chau Chamba: {len(draws)}")
                return pd.DataFrame(draws)
        except Exception as e:
            print(f"⚠️ Error descargando histórico: {e}")

        return pd.DataFrame()

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el pozo de Kábala en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "S/ 351,140"
        print(f"💰 Actualizando jackpot para Kábala: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "kabala",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Kábala: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Kábala y Chau Chamba (Perú)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_kabala WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar histórico y pozo oficial
        pozo_oficial = self.extraer_pozo_oficial()

        # Si no hay datos previos, o contiene las columnas antiguas 'revancha1', o hay pocos datos, o se pide backfill
        if backfill or df_existente.empty or len(df_existente) < 50 or 'revancha1' in df_existente.columns:
            df_scraped = self.extraer_historico_concurrente(max_draws=350)
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Kábala.")
            return

        # 3. Combinar y limpiar (df_scraped primero para que prevalezcan los datos con concurso)
        if not df_existente.empty and not df_scraped.empty:
            df_combined = pd.concat([df_scraped, df_existente], ignore_index=True)
        elif not df_scraped.empty:
            df_combined = df_scraped
        else:
            df_combined = df_existente

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(['fecha', 'sorteo'], ascending=[False, False]).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return

        # 4. Calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        
        ultimo_concurso = df_combined.iloc[0].get('concurso')
        prox_concurso = int(ultimo_concurso) + 1 if pd.notna(ultimo_concurso) and ultimo_concurso else None
        print(f"📅 Próximo sorteo Kábala / Chau Chamba: #{prox_concurso} - Fecha: {proxima_fecha_str}")

        # Filas placeholder en ceros (una para Kábala y otra para Chau Chamba)
        filas_proximo = [
            {
                "concurso": prox_concurso,
                "loteria_id": self.loteria_id,
                "sorteo": "Kábala",
                "fecha": proxima_fecha,
                "balota1": 0,
                "balota2": 0,
                "balota3": 0,
                "balota4": 0,
                "balota5": 0,
                "balota6": 0,
                "balotaroja": 0
            },
            {
                "concurso": prox_concurso,
                "loteria_id": self.loteria_id,
                "sorteo": "Chau Chamba",
                "fecha": proxima_fecha,
                "balota1": 0,
                "balota2": 0,
                "balota3": 0,
                "balota4": 0,
                "balota5": 0,
                "balota6": 0,
                "balotaroja": 0
            }
        ]
        df_final = pd.concat([pd.DataFrame(filas_proximo), df_combined], ignore_index=True)
        df_final['loteria_id'] = self.loteria_id

        # 5. Guardar en PostgreSQL de forma SEGURA (UPSERT sin DROP TABLE)
        try:
            with self.engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS resultados_kabala (
                        concurso INTEGER,
                        loteria_id INTEGER NOT NULL DEFAULT 32 REFERENCES loterias(id),
                        sorteo VARCHAR(50) NOT NULL,
                        fecha DATE NOT NULL,
                        balota1 INTEGER NOT NULL,
                        balota2 INTEGER NOT NULL,
                        balota3 INTEGER NOT NULL,
                        balota4 INTEGER NOT NULL,
                        balota5 INTEGER NOT NULL,
                        balota6 INTEGER NOT NULL,
                        balotaroja INTEGER NOT NULL DEFAULT 0,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                    CREATE UNIQUE INDEX IF NOT EXISTS uq_kabala_fecha_sorteo ON resultados_kabala (fecha, sorteo);
                    CREATE INDEX IF NOT EXISTS idx_kabala_concurso ON resultados_kabala (concurso);
                    CREATE INDEX IF NOT EXISTS idx_kabala_loteria_id ON resultados_kabala (loteria_id);
                """))

            insert_sql = """
                INSERT INTO resultados_kabala (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balota6, balotaroja,
                    created_at, updated_at
                ) VALUES %s
                ON CONFLICT (fecha, sorteo) DO UPDATE SET
                    concurso = COALESCE(EXCLUDED.concurso, resultados_kabala.concurso),
                    loteria_id = EXCLUDED.loteria_id,
                    balota1 = EXCLUDED.balota1,
                    balota2 = EXCLUDED.balota2,
                    balota3 = EXCLUDED.balota3,
                    balota4 = EXCLUDED.balota4,
                    balota5 = EXCLUDED.balota5,
                    balota6 = EXCLUDED.balota6,
                    balotaroja = EXCLUDED.balotaroja,
                    updated_at = CURRENT_TIMESTAMP;
            """

            data_tuples = [
                (
                    int(r['concurso']) if pd.notna(r.get('concurso')) and r.get('concurso') else None,
                    int(self.loteria_id),
                    str(r['sorteo']),
                    str(r['fecha']),
                    int(r['balota1']),
                    int(r['balota2']),
                    int(r['balota3']),
                    int(r['balota4']),
                    int(r['balota5']),
                    int(r['balota6']),
                    int(r['balotaroja'])
                )
                for r in df_final.to_dict(orient='records')
            ]

            raw_conn = self.engine.raw_connection()
            try:
                chunk_size = 500
                for i in range(0, len(data_tuples), chunk_size):
                    chunk = data_tuples[i:i + chunk_size]
                    with raw_conn.cursor() as cur:
                        execute_values(
                            cur, insert_sql, chunk,
                            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                        )
                    raw_conn.commit()
            finally:
                raw_conn.close()

            print(f"✅ Resultados de Kábala y Chau Chamba guardados exitosamente! Total filas: {len(df_final)}")
            self.actualizar_jackpot(proxima_fecha_str, pozo_oficial)
            return True

        except Exception as e:
            print(f"❌ Error guardando resultados de Kábala en PostgreSQL: {e}")
            raise e

if __name__ == "__main__":
    scraper = KabalaScraper()
    scraper.run(backfill=True)
