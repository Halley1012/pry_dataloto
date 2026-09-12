import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import time
import re
from pathlib import Path
from datetime import datetime, timedelta, date
import pandas as pd
import requests
import concurrent.futures
from bs4 import BeautifulSoup
from sqlalchemy import text
from psycopg2.extras import execute_values
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class BalotoScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 1
        self.base_url = "https://baloto.com/resultados?page={}"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-CO,es;q=0.9,en;q=0.8",
        }
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
        }
        self.meses_es_en = {
            'Enero': 'January', 'Febrero': 'February', 'Marzo': 'March', 'Abril': 'April',
            'Mayo': 'May', 'Junio': 'June', 'Julio': 'July', 'Agosto': 'August',
            'Septiembre': 'September', 'Octubre': 'October', 'Noviembre': 'November', 'Diciembre': 'December'
        }

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de Baloto: Lunes (0), Miércoles (2) y Sábados (5)."""
        dias_validos = {0, 2, 5}
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in dias_validos:
            candidate += timedelta(days=1)
        return candidate

    def convertir_fecha_manual(self, fecha_str: str) -> str:
        try:
            partes = fecha_str.lower().split(' de ')
            if len(partes) == 3:
                dia = partes[0].zfill(2)
                mes = self.meses[partes[1]]
                anio = partes[2]
                return f'{anio}-{mes}-{dia}'
        except Exception:
            return None
        return None

    def obtener_num_paginas(self, html: str) -> int:
        soup = BeautifulSoup(html, "html.parser")
        ultima_pagina = soup.find("a", string=lambda t: t and "Última" in t)
        if ultima_pagina:
            href = ultima_pagina.get("href", "")
            if "page=" in href:
                try:
                    return int(href.split("page=")[-1])
                except ValueError:
                    return 1
        return 1

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo REAL registrado en la BD (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, sorteo
                    FROM resultados_bloto
                    WHERE balota1 > 0
                    ORDER BY fecha DESC, concurso DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "concurso": int(row[0]) if row[0] is not None else None,
                        "fecha": row[1].strftime("%Y-%m-%d") if hasattr(row[1], 'strftime') else str(row[1]),
                        "sorteo": str(row[2])
                    }
        except Exception as e:
            print(f"⚠️ Error consultando último sorteo en BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        """Extrae el último sorteo REAL publicado en la fuente (página 1 de baloto.com/resultados)."""
        try:
            resp = requests.get(self.base_url.format(1), headers=self.headers, timeout=12)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                filas = soup.select("table.table.table-hover.gotham-book tbody tr")
                if filas:
                    f = filas[0]
                    cols = f.find_all("td")
                    if len(cols) >= 3:
                        links = [a.get("href") for a in f.find_all("a", href=True)]
                        m = re.search(r'/resultados-(?:baloto|revancha)/(\d+)', links[0]) if links else None
                        concurso_num = int(m.group(1)) if m else None
                        fecha_raw = cols[1].get_text(strip=True)
                        fecha_iso = self.convertir_fecha_manual(fecha_raw)
                        nums = [int(n) for n in re.findall(r'\d+', cols[2].get_text(' ', strip=True))]
                        if concurso_num and fecha_iso and len(nums) == 6:
                            return {
                                "concurso": concurso_num,
                                "fecha": fecha_iso,
                                "balotas": nums[:5],
                                "balotaroja": nums[5]
                            }
        except Exception as e:
            print(f"⚠️ Error extrayendo último sorteo de la fuente Baloto: {e}")
        return None

    def scrape_pagina(self, pagina: int) -> list:
        url = self.base_url.format(pagina)
        rows_data = []
        for intento in range(3):
            try:
                resp = requests.get(url, headers=self.headers, timeout=12)
                if resp.status_code == 200:
                    soup = BeautifulSoup(resp.text, "html.parser")
                    filas = soup.select("table.table.table-hover.gotham-book tbody tr")
                    for fila in filas:
                        columnas = fila.find_all("td")
                        if len(columnas) >= 3:
                            img_tag = columnas[0].find("img")
                            sorteo = "Desconocido"
                            if img_tag:
                                src = img_tag.get("src", "")
                                if "baloto-kind" in src:
                                    sorteo = "Baloto"
                                elif "revancha-kind" in src:
                                    sorteo = "Revancha"

                            concurso_num = None
                            for a_tag in fila.find_all("a", href=True):
                                m_c = re.search(r'/resultados-(?:baloto|revancha)/(\d+)', a_tag["href"])
                                if m_c:
                                    concurso_num = int(m_c.group(1))
                                    break

                            fecha_raw = columnas[1].get_text(strip=True)
                            fecha_iso = self.convertir_fecha_manual(fecha_raw)
                            numeros_texto = columnas[2].get_text(" ", strip=True)
                            numeros = [int(n) for n in re.findall(r"\d+", numeros_texto)]

                            # Conservar el orden original extraído de las balotas
                            if len(numeros) == 6 and fecha_iso and sorteo != "Desconocido":
                                rows_data.append({
                                    "concurso": concurso_num,
                                    "loteria_id": self.loteria_id,
                                    "sorteo": sorteo,
                                    "fecha": fecha_iso,
                                    "balota1": numeros[0],
                                    "balota2": numeros[1],
                                    "balota3": numeros[2],
                                    "balota4": numeros[3],
                                    "balota5": numeros[4],
                                    "balotaroja": numeros[5]
                                })
                    return rows_data
            except Exception:
                time.sleep(1)
        return rows_data

    def update_jackpot(self, loteria: str, jackpot: str, fecha_str: str):
        if not jackpot or not fecha_str:
            return
        fecha = None
        try:
            parts = fecha_str.strip().split(" de ")
            if len(parts) == 2:
                dia_part = parts[0].split()[-1]
                mes_es = parts[1].strip()
                mes_en = self.meses_es_en.get(mes_es.capitalize())
                if mes_en:
                    ano = datetime.now().year
                    if datetime.now().month == 12 and mes_es.lower() == 'enero':
                        ano += 1
                    fecha = datetime.strptime(f"{dia_part} {mes_en} {ano}", "%d %B %Y").date()
        except Exception as ex:
            print(f"Error parseando fecha jackpot {fecha_str} para {loteria}: {ex}")

        if not fecha:
            return

        try:
            with self.engine.connect() as conn:
                print(f"💰 Actualizando jackpot para {loteria}: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": loteria, "fecha": fecha, "jackpot": jackpot})

                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": loteria})
                conn.commit()
        except Exception as e:
            print(f"❌ Error actualizando jackpot {loteria} en BD: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Baloto y Revancha (Colombia)...")

        # 1. Detección temprana: comparar último sorteo en BD vs fuente
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and ultimo_db and ultimo_fuente:
            concurso_db = ultimo_db.get("concurso")
            concurso_fuente = ultimo_fuente.get("concurso")

            if concurso_fuente and concurso_db and concurso_fuente <= concurso_db:
                print(f"ℹ️ Detección temprana: No hay sorteo nuevo para Baloto.")
                print(f"   BD: #{concurso_db} ({ultimo_db.get('fecha')}) vs Fuente: #{concurso_fuente} ({ultimo_fuente.get('fecha')})")
                try:
                    f_dt = datetime.strptime(ultimo_db['fecha'], "%Y-%m-%d").date()
                except Exception:
                    f_dt = ultimo_db['fecha']
                proxima_fecha = self._calcular_proximo_sorteo(f_dt)
                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"{ultimo_db.get('fecha')} (#{concurso_db})",
                    "proximo_esperado": f"{proxima_fecha.strftime('%d/%m/%Y')} (#{concurso_db + 1})"
                }

        # 2. Obtener páginas disponibles
        try:
            resp = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            num_paginas = self.obtener_num_paginas(resp.text) if resp.status_code == 200 else 1
        except Exception as e:
            print(f"❌ Error al conectar a Baloto: {e}")
            num_paginas = 1

        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(
                    text("SELECT concurso, loteria_id, sorteo, fecha, balota1, balota2, balota3, balota4, balota5, balotaroja FROM resultados_bloto WHERE balota1 > 0;"),
                    conn
                )
        except Exception:
            pass

        if backfill or df_existente.empty or df_existente['concurso'].isna().sum() > 10:
            paginas_a_scrapear = list(range(1, num_paginas + 1))
            print(f"📄 Modo backfill/completo: scrapeando {len(paginas_a_scrapear)} páginas concurrentemente...")
        else:
            paginas_a_scrapear = list(range(1, min(6, num_paginas + 1)))
            print(f"📄 Modo incremental: scrapeando {len(paginas_a_scrapear)} páginas recientes...")

        resultados = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            future_to_page = {executor.submit(self.scrape_pagina, p): p for p in paginas_a_scrapear}
            for future in concurrent.futures.as_completed(future_to_page):
                data = future.result()
                if data:
                    resultados.extend(data)

        if not resultados and df_existente.empty:
            print("❌ No se lograron recuperar registros de Baloto.")
            return False

        df_scraped = pd.DataFrame(resultados) if resultados else pd.DataFrame()

        dfs_to_combine = []
        if not df_scraped.empty:
            dfs_to_combine.append(df_scraped)
        if not df_existente.empty:
            dfs_to_combine.append(df_existente)

        df_final = pd.concat(dfs_to_combine, ignore_index=True)
        df_final['fecha'] = pd.to_datetime(df_final['fecha']).dt.date
        df_final = df_final.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(by=['fecha', 'sorteo'], ascending=[False, True]).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_final = df_final[df_final['fecha'] <= hoy_max]

        if df_final.empty:
            print("❌ No hay datos válidos para procesar.")
            return False

        ultima_fecha_real = df_final.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)

        # Extraer fecha oficial del banner de próximo sorteo si está disponible
        try:
            r_home = requests.get(self.base_url.format(1), headers=self.headers, timeout=10)
            if r_home.status_code == 200:
                soup_home = BeautifulSoup(r_home.text, "html.parser")
                proxsorteo = soup_home.find("div", class_="bottom-pill--nextdraw")
                if proxsorteo:
                    fecha_divs = proxsorteo.find_all("div", class_="gotham-black yellow-color")
                    partes_fecha = [div.get_text(strip=True) for div in fecha_divs]
                    if len(partes_fecha) >= 2:
                        fecha_texto = partes_fecha[1]
                        dia, _, mes_es = fecha_texto.partition(" de ")
                        mes_en = self.meses_es_en.get(mes_es.strip())
                        if mes_en:
                            ano_actual = datetime.now().year
                            if datetime.now().month == 12 and mes_es.lower() == 'enero':
                                ano_actual += 1
                            proxima_fecha = datetime.strptime(f"{dia} {mes_en} {ano_actual}", "%d %B %Y").date()
        except Exception:
            pass

        concursos_validos = df_final[df_final['balota1'] > 0]['concurso'].dropna()
        max_concurso = int(concursos_validos.max()) if not concursos_validos.empty else None
        prox_concurso = max_concurso + 1 if max_concurso else None

        print(f"📅 Próximo sorteo Baloto / Revancha: #{prox_concurso} - Fecha: {proxima_fecha}")

        # Filas placeholder en ceros (una para Baloto y otra para Revancha)
        filas_proximo = [
            {
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'sorteo': 'Baloto',
                'fecha': proxima_fecha,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0, 'balotaroja': 0
            },
            {
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'sorteo': 'Revancha',
                'fecha': proxima_fecha,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0, 'balotaroja': 0
            }
        ]
        df_final = pd.concat([pd.DataFrame(filas_proximo), df_final], ignore_index=True)
        df_final = df_final.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').reset_index(drop=True)

        # Guardar en PostgreSQL de forma SEGURA (UPSERT sin DROP TABLE)
        try:
            with self.engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS resultados_bloto (
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
                    CREATE UNIQUE INDEX IF NOT EXISTS uq_bloto_fecha_sorteo ON resultados_bloto (fecha, sorteo);
                    CREATE INDEX IF NOT EXISTS idx_bloto_concurso ON resultados_bloto (concurso);
                    CREATE INDEX IF NOT EXISTS idx_bloto_loteria_id ON resultados_bloto (loteria_id);
                """))

            # Eliminar posibles placeholders obsoletos anteriores a la próxima fecha
            with self.engine.begin() as conn:
                conn.execute(text("""
                    DELETE FROM resultados_bloto
                    WHERE balota1 = 0 AND fecha < :proxima_fecha;
                """), {"proxima_fecha": proxima_fecha})

            insert_sql = """
                INSERT INTO resultados_bloto (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5,
                    balotaroja, created_at, updated_at
                ) VALUES %s
                ON CONFLICT (fecha, sorteo)
                DO UPDATE SET
                    concurso = COALESCE(EXCLUDED.concurso, resultados_bloto.concurso),
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

            print(f"✅ Resultados de Baloto guardados exitosamente! Total filas: {len(df_final)}")

            # Actualizar jackpots oficiales
            try:
                print("➡️ Consultando jackpots de Baloto & Revancha desde la página de inicio...")
                r_main = requests.get("https://baloto.com/", headers=self.headers, timeout=12)
                if r_main.status_code == 200:
                    soup_main = BeautifulSoup(r_main.text, "html.parser")
                    baloto_home = soup_main.find(class_="accumulated-baloto-home")
                    if baloto_home:
                        integers = baloto_home.find_all(class_="accum-integer")
                        jackpot_baloto = integers[0].get_text(strip=True) + " millones" if len(integers) > 0 else None
                        jackpot_revancha = integers[1].get_text(strip=True) + " millones" if len(integers) > 1 else None

                        accum2 = baloto_home.find(class_="accumulated-2")
                        fecha_str = accum2.find(class_="fs-5").get_text(strip=True) if accum2 and accum2.find(class_="fs-5") else None

                        if jackpot_baloto and fecha_str:
                            self.update_jackpot("baloto", jackpot_baloto, fecha_str)
                        if jackpot_revancha and fecha_str:
                            self.update_jackpot("revancha", jackpot_revancha, fecha_str)
            except Exception as e:
                print(f"⚠️ Error actualizando jackpots: {e}")

            return {
                "hubo_sorteo": True,
                "ultimo_sorteo": f"#{max_concurso} ({ultima_fecha_real.strftime('%d/%m/%Y')})",
                "proximo_esperado": f"#{prox_concurso} ({proxima_fecha.strftime('%d/%m/%Y')})"
            }

        except Exception as e:
            print(f"❌ Error guardando resultados de Baloto en PostgreSQL: {e}")
            raise e

if __name__ == "__main__":
    BalotoScraper().run(backfill=False)