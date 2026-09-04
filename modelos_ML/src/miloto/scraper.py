import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import time
import re
from pathlib import Path
from datetime import datetime
import pandas as pd
import requests
import concurrent.futures
from bs4 import BeautifulSoup
from sqlalchemy import text
from psycopg2.extras import execute_values

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class MilotoScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 2
        self.base_url = "https://baloto.com/miloto/resultados/?page={}"
        self.headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
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

    def convertir_fecha_manual(self, fecha_str):
        try:
            partes = fecha_str.lower().split(' de ')
            if len(partes) == 3:
                dia = partes[0].zfill(2)
                mes = self.meses[partes[1]]
                anio = partes[2]
                return f'{anio}-{mes}-{dia}'
        except Exception:
            return None

    def obtener_num_paginas(self, html):
        soup = BeautifulSoup(html, "html.parser")
        ultima_pagina = soup.find("a", string=lambda text: text and "Última" in text)
        if ultima_pagina:
            href = ultima_pagina.get("href", "")
            if "page=" in href:
                try:
                    return int(href.split("page=")[-1])
                except ValueError:
                    pass
        return 1

    def scrape_pagina(self, page: int) -> list:
        url = self.base_url.format(page)
        rows_data = []
        for _ in range(3):
            try:
                resp = requests.get(url, headers=self.headers, timeout=12)
                if resp.status_code == 200:
                    soup = BeautifulSoup(resp.text, "html.parser")
                    filas = soup.select("table.table-points-miloto tbody tr")
                    for fila in filas:
                        columnas = fila.find_all("td")
                        if len(columnas) >= 2:
                            fecha_raw = columnas[0].text.strip()
                            fecha_iso = self.convertir_fecha_manual(fecha_raw)

                            concurso_num = None
                            for a_tag in fila.find_all("a", href=True):
                                m_c = re.search(r'/resultados-miloto/(\d+)', a_tag["href"])
                                if m_c:
                                    concurso_num = int(m_c.group(1))
                                    break

                            numeros_span = columnas[1].select("span")
                            numeros = [int(span.text.strip()) for span in numeros_span if span.text.strip().isdigit()]

                            if len(numeros) == 5 and fecha_iso:
                                rows_data.append({
                                    "concurso": concurso_num,
                                    "loteria_id": self.loteria_id,
                                    "fecha": fecha_iso,
                                    "balota1": numeros[0],
                                    "balota2": numeros[1],
                                    "balota3": numeros[2],
                                    "balota4": numeros[3],
                                    "balota5": numeros[4]
                                })
                    return rows_data
            except Exception:
                time.sleep(1)
        return rows_data

    def update_jackpot(self, jackpot: str, fecha_str: str):
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
            print(f"Error parseando fecha jackpot {fecha_str} para miloto: {ex}")

        if not fecha:
            return

        try:
            with self.engine.connect() as conn:
                print(f"💰 Actualizando jackpot para miloto: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": "miloto", "fecha": fecha, "jackpot": jackpot})

                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": "miloto"})
                conn.commit()
        except Exception as e:
            print(f"❌ Error actualizando jackpot miloto en BD: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Miloto (Colombia)...")
        try:
            r_first = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            total_paginas = self.obtener_num_paginas(r_first.text) if r_first.status_code == 200 else 1
        except Exception as e:
            print(f"❌ Error conectando a Miloto: {e}")
            total_paginas = 1

        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(
                    text("SELECT concurso, loteria_id, fecha, balota1, balota2, balota3, balota4, balota5 FROM resultados_mloto WHERE balota1 > 0;"),
                    conn
                )
        except Exception:
            pass

        if backfill or df_existente.empty or df_existente['concurso'].isna().sum() > 10:
            paginas_a_scrapear = list(range(1, total_paginas + 1))
            print(f"📄 Modo backfill/completo: scrapeando {len(paginas_a_scrapear)} páginas concurrentemente...")
        else:
            paginas_a_scrapear = list(range(1, min(6, total_paginas + 1)))
            print(f"📄 Modo incremental: scrapeando {len(paginas_a_scrapear)} páginas recientes...")

        resultados = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            future_to_page = {executor.submit(self.scrape_pagina, p): p for p in paginas_a_scrapear}
            for future in concurrent.futures.as_completed(future_to_page):
                data = future.result()
                if data:
                    resultados.extend(data)

        if not resultados and df_existente.empty:
            print("❌ No se lograron recuperar registros de Miloto.")
            return

        df_scraped = pd.DataFrame(resultados) if resultados else pd.DataFrame()

        dfs_to_combine = []
        if not df_scraped.empty:
            dfs_to_combine.append(df_scraped)
        if not df_existente.empty:
            dfs_to_combine.append(df_existente)

        df_final = pd.concat(dfs_to_combine, ignore_index=True)
        df_final['fecha'] = pd.to_datetime(df_final['fecha']).dt.date
        df_final = df_final.drop_duplicates(subset=['fecha'], keep='first').sort_values(by='fecha', ascending=False).reset_index(drop=True)

        # Buscar bloque del próximo sorteo en home
        proxima_fecha = None
        try:
            r_home = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            if r_home.status_code == 200:
                soup_home = BeautifulSoup(r_home.text, "html.parser")
                proxsorteo = soup_home.find('div', class_='col-md-3 col-4 dark-blue text-center')
                if proxsorteo:
                    mobile = proxsorteo.find('div', class_='mobile')
                    strong_tags = mobile.find_all('strong') if mobile else []
                    if len(strong_tags) >= 3:
                        dia = strong_tags[1].get_text(strip=True).split()[-1]
                        mes_es = strong_tags[2].get_text(strip=True).replace("de ", "")
                        mes_en = self.meses_es_en.get(mes_es.capitalize())
                        if mes_en:
                            ano = datetime.now().year
                            if datetime.now().month == 12 and mes_es.lower() == 'enero':
                                ano += 1
                            proxima_fecha = datetime.strptime(f"{dia} {mes_en} {ano}", "%d %B %Y").date()
        except Exception as e:
            print(f"⚠️ Error obteniendo próximo sorteo Miloto: {e}")

        concursos_validos = df_final[df_final['balota1'] > 0]['concurso'].dropna()
        prox_concurso = (int(concursos_validos.max()) + 1) if not concursos_validos.empty else None

        if proxima_fecha:
            df2 = pd.DataFrame([{
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'fecha': proxima_fecha,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0
            }])
            df_final = pd.concat([df2, df_final], ignore_index=True)
            df_final = df_final.drop_duplicates(subset=['fecha'], keep='first').reset_index(drop=True)

        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_mloto (
                    id SERIAL PRIMARY KEY,
                    concurso INT,
                    loteria_id INT REFERENCES loterias(id),
                    fecha DATE NOT NULL,
                    balota1 INT NOT NULL,
                    balota2 INT NOT NULL,
                    balota3 INT NOT NULL,
                    balota4 INT NOT NULL,
                    balota5 INT NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_mloto_fecha ON resultados_mloto (fecha);
            """))

        insert_sql = """
            INSERT INTO resultados_mloto (
                concurso, loteria_id, fecha,
                balota1, balota2, balota3, balota4, balota5,
                created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_mloto.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                updated_at = CURRENT_TIMESTAMP;
        """

        data_tuples = [
            (
                int(r['concurso']) if pd.notna(r.get('concurso')) and r.get('concurso') else None,
                int(self.loteria_id),
                str(r['fecha']),
                int(r['balota1']),
                int(r['balota2']),
                int(r['balota3']),
                int(r['balota4']),
                int(r['balota5'])
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
                        template="(%s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ Resultados de Miloto guardados exitosamente! Total filas: {len(df_final)}")

        try:
            print("➡️ Consultando jackpot de Miloto desde la página de inicio...")
            r_main = requests.get("https://baloto.com/", headers=self.headers, timeout=15)
            if r_main.status_code == 200:
                soup_main = BeautifulSoup(r_main.text, "html.parser")
                miloto_home = soup_main.find(class_="accumulated-miloto-home")
                if miloto_home:
                    integer = miloto_home.find(class_="accum-integer")
                    jackpot_miloto = integer.get_text(strip=True) + " millones" if integer else None
                    accum2 = miloto_home.find(class_="accumulated-2")
                    fecha_str = accum2.find(class_="fs-5").get_text(strip=True) if accum2 and accum2.find(class_="fs-5") else None
                    if jackpot_miloto and fecha_str:
                        self.update_jackpot(jackpot_miloto, fecha_str)
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot Miloto: {e}")

        return True

if __name__ == "__main__":
    MilotoScraper().run(backfill=True)