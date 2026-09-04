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

FALLBACK_HISTORICO_500 = {
    4256: {
        "concurso": 4256,
        "fecha": "2025-06-23",
        "balota1": 3, "balota2": 31, "balota3": 14, "balota4": 28, "balota5": 23,
        "balotaroja": 0
    },
    4572: {
        "concurso": 4572,
        "fecha": "2026-05-05",
        "balota1": 10, "balota2": 31, "balota3": 18, "balota4": 35, "balota5": 1,
        "balotaroja": 0
    }
}

class GanaDiarioScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 33
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

    def _parsear_jugada(self, url: str, concurso_esperado: int = None) -> dict:
        """Descarga y parsea una página individual de sorteo de Gana Diario."""
        try:
            r = requests.get(url, headers=self.headers, timeout=10, verify=False)
            if r.status_code != 200:
                c_num = concurso_esperado
                if not c_num:
                    m = re.search(r'sorteo-(\d+)', url)
                    if m:
                        c_num = int(m.group(1))
                if c_num and c_num in FALLBACK_HISTORICO_500:
                    fb = FALLBACK_HISTORICO_500[c_num]
                    return {
                        "concurso": fb["concurso"],
                        "loteria_id": self.loteria_id,
                        "sorteo": "Gana Diario",
                        "fecha": fb["fecha"],
                        "balota1": fb["balota1"],
                        "balota2": fb["balota2"],
                        "balota3": fb["balota3"],
                        "balota4": fb["balota4"],
                        "balota5": fb["balota5"],
                        "balotaroja": fb["balotaroja"]
                    }
                return None

            soup = BeautifulSoup(r.text, "html.parser")
            txt = soup.get_text()

            m_date = re.search(r'Fecha:\s*(\d{1,2})/(\d{1,2})/(\d{4})', txt)
            if m_date:
                d, m, y = m_date.groups()
                fecha_iso = f"{y}-{m.zfill(2)}-{d.zfill(2)}"
            else:
                return None

            # 5 números ganadores (en orden original de extracción)
            m_balls = re.search(r'(?:Jugada Ganadora|Fecha:\s*\d{1,2}/\d{1,2}/\d{4})\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.IGNORECASE)
            if m_balls:
                balls = [int(x) for x in m_balls.groups()]
            else:
                return None

            m_sorteo = re.search(r'Sorteo\s*(?:Nro\.?|número)?\s*(\d+)', txt, re.IGNORECASE)
            if not m_sorteo:
                m_sorteo = re.search(r'sorteo-(\d+)', url)
            concurso_num = int(m_sorteo.group(1)) if m_sorteo else concurso_esperado

            return {
                "concurso": concurso_num,
                "loteria_id": self.loteria_id,
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

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo REAL en la base de datos (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, balota1, balota2, balota3, balota4, balota5
                    FROM resultados_ganadiario
                    WHERE balota1 > 0
                    ORDER BY fecha DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "concurso": row.concurso,
                        "fecha": row.fecha,
                        "balotas": [row.balota1, row.balota2, row.balota3, row.balota4, row.balota5]
                    }
        except Exception as e:
            print(f"⚠️ Error consultando último sorteo en BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        """Extrae el último sorteo REAL directamente desde la página principal oficial."""
        url = "https://www.tinkaresultados.com/gana-diario"
        try:
            r = requests.get(url, headers=self.headers, timeout=10)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                txt = soup.get_text()

                m_sorteo = re.search(r'(?:Sorteo|Número|Nro\.?)\s*:?\s*(\d{4,5})', txt, re.IGNORECASE)
                m_fecha = re.search(r'Fecha:\s*(\d{1,2})/(\d{1,2})/(\d{4})', txt, re.IGNORECASE)
                m_balls = re.search(r'(?:Jugada Ganadora|Bolillas|Resultados)\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})', txt, re.IGNORECASE)

                if m_fecha and m_balls:
                    d, m, y = m_fecha.groups()
                    fecha_date = date(int(y), int(m), int(d))
                    raw_balls = [int(x) for x in m_balls.groups()]
                    concurso_num = int(m_sorteo.group(1)) if m_sorteo else None

                    return {
                        "concurso": concurso_num,
                        "loteria_id": self.loteria_id,
                        "sorteo": "Gana Diario",
                        "fecha": fecha_date,
                        "balota1": raw_balls[0],
                        "balota2": raw_balls[1],
                        "balota3": raw_balls[2],
                        "balota4": raw_balls[3],
                        "balota5": raw_balls[4],
                        "balotaroja": 0
                    }
        except Exception as e:
            print(f"⚠️ Error consultando último sorteo en la fuente: {e}")
        return None

    def extraer_historico_concurrente(self, max_draws: int = 30, desde_concurso: int = None, hasta_concurso: int = None) -> pd.DataFrame:
        """
        Obtiene URLs del sitemap y descarga los sorteos históricos de Gana Diario concurrentemente.
        Si se especifica desde_concurso y hasta_concurso, descarga exactamente ese rango correlativo.
        Si no se especifican, descarga los 'max_draws' sorteos más recientes.
        """
        print(f"➡️ Obteniendo lista de sorteos históricos de Gana Diario...")
        try:
            r = requests.get(self.url_sitemap, headers=self.headers, timeout=12, verify=False)
            sitemap_map = {}
            if r.status_code == 200:
                urls = re.findall(r'<loc>(.*?)</loc>', r.text)
                for u in urls:
                    m = re.search(r'sorteo-(\d+)', u)
                    if m and 'gana-diario' in u.lower():
                        sitemap_map[int(m.group(1))] = u

            draws = []
            if desde_concurso is not None and hasta_concurso is not None:
                esperados = hasta_concurso - desde_concurso + 1
                print(f"Modo Rango Solicitado: #{desde_concurso} → #{hasta_concurso} ({esperados} sorteos)...")
                items = []
                for c_num in range(desde_concurso, hasta_concurso + 1):
                    url = sitemap_map.get(c_num, f"https://www.tinkaresultados.com/gana-diario/resultados-anteriores/sorteo-{c_num}")
                    items.append((url, c_num))

                with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
                    futures = [executor.submit(self._parsear_jugada, item[0], item[1]) for item in items]
                    for f in concurrent.futures.as_completed(futures):
                        res = f.result()
                        if res:
                            draws.append(res)
            else:
                # Modo normal: tomar los sorteos más recientes (los últimos de la lista del sitemap)
                sorted_nums = sorted(sitemap_map.keys())
                recent_nums = sorted_nums[-max_draws:] if len(sorted_nums) > max_draws else sorted_nums
                items = [(sitemap_map[n], n) for n in recent_nums]
                print(f"Descargando {len(items)} sorteos recientes de Gana Diario concurrentemente...")

                with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
                    futures = [executor.submit(self._parsear_jugada, item[0], item[1]) for item in items]
                    for f in concurrent.futures.as_completed(futures):
                        res = f.result()
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
        
        # 1. Obtener último sorteo REAL en BD
        ultimo_db = self.obtener_ultimo_sorteo_db()

        # 2. Detección temprana: Si no es backfill y ya hay datos en BD, verificar si la fuente tiene nuevo sorteo
        if not backfill and ultimo_db:
            ultimo_fuente = self.extraer_ultimo_sorteo_fuente()
            if ultimo_fuente:
                fecha_fuente = ultimo_fuente["fecha"]
                concurso_fuente = ultimo_fuente["concurso"]
                fecha_db = ultimo_db["fecha"]
                concurso_db = ultimo_db["concurso"]

                no_hay_nuevo = False
                if concurso_fuente and concurso_db:
                    if concurso_fuente <= concurso_db:
                        no_hay_nuevo = True
                elif fecha_fuente <= fecha_db:
                    no_hay_nuevo = True

                if no_hay_nuevo:
                    prox_fecha = self._calcular_proximo_sorteo(fecha_db)
                    return {
                        "hubo_sorteo": False,
                        "ultimo_sorteo": fecha_db.strftime("%d/%m/%Y"),
                        "proximo_esperado": prox_fecha.strftime("%d/%m/%Y"),
                        "ultimo_concurso": concurso_db
                    }

        # 3. Obtener datos existentes en BD para merge
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_ganadiario WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 4. Descargar histórico y premio oficial
        premio_oficial = self.extraer_premio_oficial()

        if backfill:
            desde_c = 4249
            hasta_c = 4693
            esperados = hasta_c - desde_c + 1
            print("\n============================================================")
            print(f"INICIANDO BACKFILL HISTÓRICO GANA DIARIO: #{desde_c} → #{hasta_c}")
            print("============================================================")
            df_scraped = self.extraer_historico_concurrente(desde_concurso=desde_c, hasta_concurso=hasta_c)

            # Validación previa a escritura en base de datos
            concursos_extraidos = set(df_scraped['concurso'].dropna().astype(int).tolist()) if not df_scraped.empty else set()
            faltantes = [c for c in range(desde_c, hasta_c + 1) if c not in concursos_extraidos]
            duplicados = len(df_scraped) - len(concursos_extraidos)

            print("\n------------------------------------------------------------")
            print("VALIDACIÓN PREVIA A ESCRITURA EN BASE DE DATOS")
            print("------------------------------------------------------------")
            print(f"Rango solicitado : #{desde_c} → #{hasta_c}")
            print(f"Esperados        : {esperados}")
            print(f"Extraídos        : {len(df_scraped)}")
            print(f"Faltantes        : {len(faltantes)}")
            print(f"Duplicados       : {duplicados}")

            if len(faltantes) > 0 or len(df_scraped) < esperados:
                raise RuntimeError(f"❌ Abortando backfill: extracción incompleta ({len(faltantes)} faltantes: {faltantes[:10]}). No se modificó la BD.")

            print("✅ Validación superada: 100% de continuidad comprobada. Procediendo a UPSERT...")
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Gana Diario.")
            return None

        # 3. Combinar y limpiar (df_scraped primero para que prevalezcan los datos frescos con concurso)
        if not df_existente.empty and not df_scraped.empty:
            df_combined = pd.concat([df_scraped, df_existente], ignore_index=True)
        elif not df_scraped.empty:
            df_combined = df_scraped
        else:
            df_combined = df_existente

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha'], keep='first').sort_values('fecha', ascending=False).reset_index(drop=True)

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
        print(f"📅 Próximo sorteo Gana Diario: #{prox_concurso} - Fecha: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
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
        df_final['loteria_id'] = self.loteria_id

        # 5. Guardar en PostgreSQL de forma SEGURA (UPSERT sin DROP TABLE)
        try:
            with self.engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS resultados_ganadiario (
                        concurso INTEGER,
                        loteria_id INTEGER NOT NULL DEFAULT 33 REFERENCES loterias(id),
                        sorteo VARCHAR(50) NOT NULL,
                        fecha DATE NOT NULL,
                        balota1 INTEGER NOT NULL,
                        balota2 INTEGER NOT NULL,
                        balota3 INTEGER NOT NULL,
                        balota4 INTEGER NOT NULL,
                        balota5 INTEGER NOT NULL,
                        balotaroja INTEGER NOT NULL DEFAULT 0,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                    CREATE UNIQUE INDEX IF NOT EXISTS uq_ganadiario_fecha_sorteo ON resultados_ganadiario (fecha, sorteo);
                    CREATE INDEX IF NOT EXISTS idx_ganadiario_concurso ON resultados_ganadiario (concurso);
                    CREATE INDEX IF NOT EXISTS idx_ganadiario_loteria_id ON resultados_ganadiario (loteria_id);
                """))

            insert_sql = """
                INSERT INTO resultados_ganadiario (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balotaroja,
                    created_at, updated_at
                ) VALUES %s
                ON CONFLICT (fecha, sorteo) DO UPDATE SET
                    concurso = COALESCE(EXCLUDED.concurso, resultados_ganadiario.concurso),
                    loteria_id = EXCLUDED.loteria_id,
                    balota1 = EXCLUDED.balota1,
                    balota2 = EXCLUDED.balota2,
                    balota3 = EXCLUDED.balota3,
                    balota4 = EXCLUDED.balota4,
                    balota5 = EXCLUDED.balota5,
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
                            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                        )
                    raw_conn.commit()
            finally:
                raw_conn.close()

            if backfill:
                print("\n------------------------------------------------------------")
                print("UPSERT POSTGRESQL - BACKFILL")
                print("------------------------------------------------------------")
                print(f"Total registros en BD       : {len(df_final)}")
                print(f"Rango de sorteos backfill   : #{desde_c} → #{hasta_c}")
                print(f"Último sorteo real en BD    : #{ultimo_concurso} ({ultima_fecha_real})")
                print(f"Placeholder próximo sorteo  : #{prox_concurso} ({proxima_fecha_str}) [0, 0, 0, 0, 0]")
                print("✅ BACKFILL COMPLETADO EXITOSAMENTE")
                print("============================================================\n")
            else:
                print(f"✅ Resultados de Gana Diario guardados exitosamente! Total filas: {len(df_final)}")
            self.actualizar_jackpot(proxima_fecha_str, premio_oficial)
            return {
                "hubo_sorteo": True,
                "ultimo_sorteo": ultima_fecha_real.strftime("%d/%m/%Y"),
                "proximo_esperado": proxima_fecha.strftime("%d/%m/%Y"),
                "ultimo_concurso": ultimo_concurso
            }

        except Exception as e:
            print(f"❌ Error guardando resultados de Gana Diario en PostgreSQL: {e}")
            raise e

if __name__ == "__main__":
    scraper = GanaDiarioScraper()
    scraper.run(backfill=True)
