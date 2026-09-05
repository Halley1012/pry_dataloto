import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import pandas as pd
import concurrent.futures
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

# Sorteos con error HTTP 500 en el backend del servidor tinkaresultados.com
# Verificados con fuentes oficiales (El Comercio, La República, Líbero, Transmisión Oficial América TV / YouTube)
FALLBACK_HISTORICO_500 = {
    796: {"fecha": "2021-07-21", "balotas": [8, 37, 20, 5, 21, 42], "boliyapa": 45},
    797: {"fecha": "2021-07-25", "balotas": [28, 40, 26, 37, 22, 1], "boliyapa": 19},
    798: {"fecha": "2021-07-28", "balotas": [44, 17, 33, 35, 22, 7], "boliyapa": 36},
    799: {"fecha": "2021-08-01", "balotas": [31, 28, 13, 42, 5, 12], "boliyapa": 9},
    834: {"fecha": "2021-12-01", "balotas": [6, 15, 18, 29, 32, 36], "boliyapa": 2},
    835: {"fecha": "2021-12-05", "balotas": [1, 6, 9, 16, 17, 29], "boliyapa": 41},
    836: {"fecha": "2021-12-08", "balotas": [10, 42, 16, 19, 13, 1], "boliyapa": 15},
    837: {"fecha": "2021-12-12", "balotas": [20, 41, 9, 44, 16, 8], "boliyapa": 24},
}

class LaTinkaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 19
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-PE,es-419;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.url_oficial = "https://www.latinka.com.pe/p/juega-tinka.html"
        self.url_home = "https://tinkaresultados.com/"
        self.url_sitemap = "https://tinkaresultados.com/sitemap.xml"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de La Tinka: Miércoles (2) y Domingos (6)."""
        dias_validos = {2, 6}
        hoy = datetime.now().date()
        base = max(ultima_fecha_real, hoy)
        
        if hoy.weekday() in dias_validos and ultima_fecha_real < hoy:
            return hoy
            
        candidate = base + timedelta(days=1)
        while candidate.weekday() not in dias_validos or candidate <= ultima_fecha_real:
            candidate += timedelta(days=1)
        return candidate

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Consulta el último sorteo real registrado en la base de datos (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha
                    FROM resultados_latinka
                    WHERE balota1 > 0
                    ORDER BY concurso DESC NULLS LAST, fecha DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "concurso": int(row[0]) if row[0] is not None else None,
                        "fecha": row[1]
                    }
        except Exception as e:
            print(f"⚠️ Error consultando último sorteo de La Tinka en BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        """Extrae la información del último sorteo publicado en la página principal."""
        try:
            r = requests.get(self.url_home, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                txt = soup.get_text(separator=' ')

                m_concurso = re.search(r'Tinka\s+Sorteo\s*(\d+)', txt, re.IGNORECASE)
                m_fecha = re.search(r'Fecha:\s*(\d{1,2})[/-](\d{1,2})[/-](\d{4})', txt, re.IGNORECASE)
                m_balls = re.search(r'Jugada Ganadora\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.IGNORECASE)
                m_by = re.search(r'Boliyapa\s*(\d{1,2})', txt, re.IGNORECASE)

                if m_concurso and m_fecha and m_balls:
                    concurso = int(m_concurso.group(1))
                    d, m, y = m_fecha.groups()
                    fecha_iso = f"{y}-{m.zfill(2)}-{d.zfill(2)}"
                    balls = [int(x) for x in m_balls.groups()]
                    boliyapa = int(m_by.group(1)) if m_by else 0

                    return {
                        "concurso": concurso,
                        "fecha": datetime.strptime(fecha_iso, "%Y-%m-%d").date(),
                        "balotas": balls,
                        "boliyapa": boliyapa
                    }
        except Exception as e:
            print(f"⚠️ Error consultando último sorteo de La Tinka en la fuente: {e}")
        return None

    def extraer_pozo_oficial(self) -> str:
        """Extrae el Pozo Millonario acumulado en tiempo real desde el portal oficial."""
        print(f"➡️ Consultando Pozo Millonario oficial en {self.url_oficial}...")
        try:
            r = requests.get(self.url_oficial, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                for tag in soup.find_all(["div", "span", "h1", "h2", "h3"]):
                    txt = tag.get_text(strip=True)
                    if "pozo millonario" in txt.lower() and "s/" in txt.lower():
                        m = re.search(r'S/\s*([0-9\',.]+)', txt)
                        if m:
                            clean_m = m.group(1).replace("'", ",").replace(" ", "")
                            return f"S/ {clean_m}"
        except Exception as e:
            print(f"⚠️ Error extrayendo Pozo de La Tinka: {e}")

        return "S/ 25,507,198"

    def _parsear_jugada(self, url: str) -> dict:
        """Descarga y parsea una página individual de sorteo de La Tinka conservando el orden original."""
        m_concurso_url = re.search(r'jugada-(\d+)', url)
        if m_concurso_url:
            c_num = int(m_concurso_url.group(1))
            if c_num in FALLBACK_HISTORICO_500:
                fb = FALLBACK_HISTORICO_500[c_num]
                return {
                    "concurso": c_num,
                    "loteria_id": self.loteria_id,
                    "sorteo": "La Tinka",
                    "fecha": fb["fecha"],
                    "balota1": fb["balotas"][0],
                    "balota2": fb["balotas"][1],
                    "balota3": fb["balotas"][2],
                    "balota4": fb["balotas"][3],
                    "balota5": fb["balotas"][4],
                    "balota6": fb["balotas"][5],
                    "balotaroja": fb["boliyapa"]
                }

        try:
            r = requests.get(url, headers=self.headers, timeout=6, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                txt = soup.get_text()

                m_date_url = re.search(r'del-(\d{1,2})-(\d{1,2})-(\d{4})', url)
                if m_date_url:
                    d, m, y = m_date_url.groups()
                    fecha_iso = f"{y}-{m.zfill(2)}-{d.zfill(2)}"
                else:
                    return None

                m_balls = re.search(r'Jugada Ganadora\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.IGNORECASE)
                if m_balls:
                    # ORDEN ORIGINAL DE EXTRACCIÓN (sin sorted)
                    balls = [int(x) for x in m_balls.groups()]
                else:
                    return None

                m_by = re.search(r'Boliyapa\s*(\d{1,2})', txt, re.IGNORECASE)
                boliyapa = int(m_by.group(1)) if m_by else 0

                m_concurso = re.search(r'Sorteo\s*(?:Nro\.?|número)?\s*(\d+)', txt, re.IGNORECASE)
                if not m_concurso:
                    m_concurso = re.search(r'jugada-(\d+)', url)
                concurso_num = int(m_concurso.group(1)) if m_concurso else None

                return {
                    "concurso": concurso_num,
                    "loteria_id": self.loteria_id,
                    "sorteo": "La Tinka",
                    "fecha": fecha_iso,
                    "balota1": balls[0],
                    "balota2": balls[1],
                    "balota3": balls[2],
                    "balota4": balls[3],
                    "balota5": balls[4],
                    "balota6": balls[5],
                    "balotaroja": boliyapa
                }
        except Exception:
            pass
        return None

    def extraer_historico_concurrente(self, max_draws: int = 400, desde_concurso: int = None, hasta_concurso: int = None) -> pd.DataFrame:
        """Obtiene URLs y descarga los sorteos históricos concurrentemente."""
        print("➡️ Obteniendo lista de sorteos históricos de La Tinka...")

        if desde_concurso is not None and hasta_concurso is not None:
            # Modo Rango Sistemático (para Backfill completo)
            sitemap_map = {}
            try:
                r = requests.get(self.url_sitemap, headers=self.headers, timeout=10, verify=False)
                if r.status_code == 200:
                    urls = re.findall(r'<loc>(.*?)</loc>', r.text)
                    for u in urls:
                        if 'jugada-' in u.lower():
                            m_c = re.search(r'jugada-(\d+)', u)
                            if m_c:
                                sitemap_map[int(m_c.group(1))] = u
            except Exception as e:
                print(f"⚠️ Error consultando sitemap: {e}")

            cal_cur = date(2021, 3, 17) # #760
            cal_urls = {}
            for c in range(761, 1018):
                nxt = cal_cur + timedelta(days=1)
                while nxt.weekday() not in (2, 6):
                    nxt += timedelta(days=1)
                cal_cur = nxt
                cal_urls[c] = f"https://www.tinkaresultados.com/sorteos-historicos/jugada-{c}-del-{cal_cur.day}-{cal_cur.month}-{cal_cur.year}"
            cal_urls[1020] = "https://www.tinkaresultados.com/sorteos-historicos/jugada-1020-del-13-9-2023"

            tinka_urls = []
            for c in range(desde_concurso, hasta_concurso + 1):
                if c in sitemap_map:
                    tinka_urls.append(sitemap_map[c])
                elif c in cal_urls:
                    tinka_urls.append(cal_urls[c])
                else:
                    tinka_urls.append(f"https://www.tinkaresultados.com/sorteos-historicos/jugada-{c}")

        else:
            # Modo Normal / Recientes
            urls_set = set()
            try:
                r_home = requests.get(self.url_home, headers=self.headers, timeout=10, verify=False)
                if r_home.status_code == 200:
                    soup = BeautifulSoup(r_home.text, "html.parser")
                    for a in soup.find_all("a", href=True):
                        href = a["href"]
                        if "jugada-" in href:
                            if not href.startswith("http"):
                                href = "https://www.tinkaresultados.com" + href
                            urls_set.add(href)
            except Exception as e:
                print(f"⚠️ Error obteniendo URLs desde home: {e}")

            try:
                r = requests.get(self.url_sitemap, headers=self.headers, timeout=10, verify=False)
                if r.status_code == 200:
                    urls = re.findall(r'<loc>(.*?)</loc>', r.text)
                    for u in urls:
                        if 'jugada-' in u:
                            urls_set.add(u)
            except Exception as e:
                print(f"⚠️ Error consultando sitemap: {e}")

            if not urls_set:
                print("❌ No se encontraron URLs para descargar sorteos.")
                return pd.DataFrame()

            def get_date_key(u: str) -> str:
                m = re.search(r'del-(\d{1,2})-(\d{1,2})-(\d{4})', u)
                if m:
                    d, mo, y = m.groups()
                    return f"{y}-{mo.zfill(2)}-{d.zfill(2)}"
                m_num = re.search(r'jugada-(\d+)', u)
                return str(m_num.group(1)).zfill(6) if m_num else ""

            tinka_urls = sorted(list(urls_set), key=get_date_key, reverse=True)[:max_draws]

        print(f"Descargando {len(tinka_urls)} sorteos de La Tinka concurrentemente...")
        draws = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
            results = list(executor.map(self._parsear_jugada, tinka_urls))

        for res in results:
            if res:
                draws.append(res)

        print(f"📊 Sorteos procesados de La Tinka: {len(draws)}")
        return pd.DataFrame(draws)

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el pozo de La Tinka en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "S/ 25,507,198"
        print(f"💰 Actualizando jackpot para La Tinka: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "latinka",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para La Tinka: {e}")

    def run(self, backfill: bool = False, desde_concurso: int = None, hasta_concurso: int = None):
        print("🚀 Iniciando Scraping de La Tinka (Perú)...")

        # 1. Detección temprana: comparar último sorteo en fuente vs BD
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and desde_concurso is None and ultimo_db and ultimo_fuente:
            concurso_db = ultimo_db.get("concurso")
            fecha_db = ultimo_db.get("fecha")
            concurso_fuente = ultimo_fuente.get("concurso")
            fecha_fuente = ultimo_fuente.get("fecha")

            if concurso_fuente is not None and concurso_db is not None:
                es_mismo = (concurso_fuente <= concurso_db)
            else:
                es_mismo = (fecha_fuente <= fecha_db)

            if es_mismo:
                proximo = self._calcular_proximo_sorteo(fecha_db)
                print(f"ℹ️ Detección temprana: Sorteo en fuente (#{concurso_fuente} del {fecha_fuente}) ya registrado en BD (#{concurso_db} del {fecha_db}).")
                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"#{concurso_db} ({fecha_db.strftime('%d/%m/%Y')})",
                    "proximo_esperado": f"{proximo.strftime('%d/%m/%Y')}"
                }

        # 2. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_latinka WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 3. Descargar histórico y pozo oficial
        pozo_oficial = self.extraer_pozo_oficial()

        if desde_concurso is not None and hasta_concurso is not None:
            df_scraped = self.extraer_historico_concurrente(desde_concurso=desde_concurso, hasta_concurso=hasta_concurso)
        elif backfill or df_existente.empty or len(df_existente) < 50:
            df_scraped = self.extraer_historico_concurrente(desde_concurso=731, hasta_concurso=1330)
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de La Tinka.")
            return False

        # 4. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_scraped, df_existente], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values('fecha', ascending=False).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return False

        # 5. Calcular próximo sorteo y agregar fila placeholder
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo agregada para La Tinka: {proxima_fecha_str}")

        max_concurso = df_combined['concurso'].dropna().max()
        prox_concurso = int(max_concurso) + 1 if pd.notna(max_concurso) else None

        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": "La Tinka",
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

        # 6. Guardar en PostgreSQL (UPSERT seguro sin destruir la tabla)
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_latinka (
                    id SERIAL PRIMARY KEY,
                    concurso INTEGER,
                    loteria_id INTEGER DEFAULT 19 REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INTEGER NOT NULL,
                    balota2 INTEGER NOT NULL,
                    balota3 INTEGER NOT NULL,
                    balota4 INTEGER NOT NULL,
                    balota5 INTEGER NOT NULL,
                    balota6 INTEGER NOT NULL,
                    balotaroja INTEGER NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_latinka_fecha_sorteo ON resultados_latinka (fecha, sorteo);
                CREATE INDEX IF NOT EXISTS idx_latinka_concurso ON resultados_latinka (concurso);
                CREATE INDEX IF NOT EXISTS idx_latinka_loteria_id ON resultados_latinka (loteria_id);
            """))

        insert_sql = """
            INSERT INTO resultados_latinka (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balota6, balotaroja,
                created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo) DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_latinka.concurso),
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

        print(f"✅ Resultados de La Tinka guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, pozo_oficial)

        return {
            "hubo_sorteo": True,
            "ultimo_sorteo": f"#{max_concurso} ({ultima_fecha_real.strftime('%d/%m/%Y')})",
            "proximo_esperado": f"{proxima_fecha.strftime('%d/%m/%Y')}"
        }

if __name__ == "__main__":
    scraper = LaTinkaScraper()
    scraper.run(backfill=False)
