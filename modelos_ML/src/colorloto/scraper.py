import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
import time
import unicodedata
import concurrent.futures
from datetime import datetime
from sqlalchemy import text
from psycopg2.extras import execute_values

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class ColorLotoScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 6
        self.base_url = "https://baloto.com/colorloto/resultados/?page={}"
        self.headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        self.COLOR_MAP = {
            "balota-yellow": "amarillo",
            "balota-blue": "azul",
            "balota-red": "rojo",
            "balota-green": "verde",
            "balota-white": "blanco",
            "balota-black": "negro"
        }
        self.MESES = {
            "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
            "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12
        }
        self.meses_es_en = {
            'Enero': 'January', 'Febrero': 'February', 'Marzo': 'March', 'Abril': 'April',
            'Mayo': 'May', 'Junio': 'June', 'Julio': 'July', 'Agosto': 'August',
            'Septiembre': 'September', 'Octubre': 'October', 'Noviembre': 'November', 'Diciembre': 'December'
        }

    def parse_fecha_es(self, fecha_str):
        fecha_str = fecha_str.lower()
        meses_str = {
            "enero": "01", "febrero": "02", "marzo": "03", "abril": "04",
            "mayo": "05", "junio": "06", "julio": "07", "agosto": "08",
            "septiembre": "09", "octubre": "10", "noviembre": "11", "diciembre": "12"
        }
        for mes, num in meses_str.items():
            fecha_str = re.sub(rf"\b{mes}\b", num, fecha_str)
        fecha_str = fecha_str.replace(" de ", "-")
        return pd.to_datetime(fecha_str, format="%d-%m-%Y")

    def normalizar_mes(self, mes):
        mes = mes.lower().strip()
        mes = mes.replace("de ", "")
        mes = unicodedata.normalize("NFD", mes)
        mes = mes.encode("ascii", "ignore").decode("utf-8")
        return mes

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

    def scrape_pagina(self, pagina: int) -> list:
        url = self.base_url.format(pagina)
        resultados_pagina = []
        for _ in range(3):
            try:
                response = requests.get(url, headers=self.headers, timeout=12)
                if response.status_code == 200:
                    soup = BeautifulSoup(response.text, "html.parser")
                    filas = soup.select("table.table-historic-colorloto tbody tr")
                    for fila in filas:
                        columnas = fila.find_all("td")
                        if len(columnas) < 2:
                            continue
                        fecha_raw = columnas[0].get_text(strip=True)

                        concurso_num = None
                        for a_tag in fila.find_all("a", href=True):
                            m_c = re.search(r'/colorloto/resultados/(\d+)', a_tag["href"])
                            if m_c:
                                concurso_num = int(m_c.group(1))
                                break

                        balotas = columnas[1].select("div.balota-bg")
                        if len(balotas) != 6:
                            continue
                        for posicion, balota in enumerate(balotas, start=1):
                            clases = balota.get("class", [])
                            color_clase = next(
                                (c for c in clases if c.startswith("balota-") and c != "balota-bg"),
                                None
                            )
                            color = self.COLOR_MAP.get(color_clase)
                            numero_txt = balota.select_one("strong")
                            if not color or not numero_txt:
                                continue
                            numero = int(numero_txt.get_text(strip=True))
                            resultados_pagina.append({
                                "concurso": concurso_num,
                                "loteria_id": self.loteria_id,
                                "fecha_raw": fecha_raw,
                                "posicion": posicion,
                                "color": color,
                                "numero": numero
                            })
                    return resultados_pagina
            except Exception:
                time.sleep(1)
        return resultados_pagina

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
            print(f"Error parseando fecha jackpot {fecha_str} para colorloto: {ex}")

        if not fecha:
            return

        try:
            with self.engine.connect() as conn:
                print(f"💰 Actualizando jackpot para colorloto: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": "colorloto", "fecha": fecha, "jackpot": jackpot})

                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": "colorloto"})
                conn.commit()
        except Exception as e:
            print(f"❌ Error actualizando jackpot colorloto en BD: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de ColorLoto (Colombia)...")
        try:
            r_first = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            num_paginas = self.obtener_num_paginas(r_first.text) if r_first.status_code == 200 else 1
        except Exception as e:
            print(f"❌ Error al conectar a ColorLoto: {e}")
            num_paginas = 1

        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(
                    text("SELECT concurso, loteria_id, fecha, color, numero FROM resultados_colorloto2 WHERE numero > 0;"),
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
            print("❌ No se lograron recuperar registros de ColorLoto.")
            return

        if resultados:
            df_scraped = pd.DataFrame(resultados)
            df_scraped['fecha'] = df_scraped['fecha_raw'].apply(self.parse_fecha_es)
            df_scraped['fecha'] = pd.to_datetime(df_scraped['fecha']).dt.date
            df_scraped = df_scraped[['concurso', 'loteria_id', 'fecha', 'posicion', 'color', 'numero']]
        else:
            df_scraped = pd.DataFrame()

        dfs_to_combine = []
        if not df_scraped.empty:
            dfs_to_combine.append(df_scraped)
        if not df_existente.empty:
            if 'posicion' not in df_existente.columns:
                df_existente['posicion'] = df_existente.groupby('fecha').cumcount() + 1
            dfs_to_combine.append(df_existente)

        df_final = pd.concat(dfs_to_combine, ignore_index=True)
        df_final['fecha'] = pd.to_datetime(df_final['fecha']).dt.date
        df_final = df_final.drop_duplicates(subset=['fecha', 'posicion'], keep='first').sort_values(by=['fecha', 'posicion'], ascending=[False, True]).reset_index(drop=True)

        # Buscar fecha del próximo sorteo en home
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
                        dia_raw = strong_tags[1].get_text(strip=True)
                        dia = int(dia_raw.split()[-1])
                        mes_raw = strong_tags[2].get_text(strip=True)
                        mes_es = self.normalizar_mes(mes_raw)
                        if mes_es in self.MESES:
                            mes = self.MESES[mes_es]
                            ano = datetime.now().year
                            if datetime.now().month == 12 and mes == 1:
                                ano += 1
                            proxima_fecha = datetime(ano, mes, dia).date()
        except Exception as e:
            print(f"⚠️ Error obteniendo fecha de próximo sorteo ColorLoto: {e}")

        concursos_validos = df_final[df_final['numero'] > 0]['concurso'].dropna()
        prox_concurso = (int(concursos_validos.max()) + 1) if not concursos_validos.empty else None

        if proxima_fecha:
            colores = ["amarillo", "azul", "rojo", "verde", "blanco", "negro"]
            filas_prox = [
                {
                    "concurso": prox_concurso,
                    "loteria_id": self.loteria_id,
                    "fecha": proxima_fecha,
                    "posicion": i + 1,
                    "color": c,
                    "numero": 0
                }
                for i, c in enumerate(colores)
            ]
            df_prox = pd.DataFrame(filas_prox)
            df_final = pd.concat([df_prox, df_final], ignore_index=True)
            df_final = df_final.drop_duplicates(subset=['fecha', 'posicion'], keep='first').reset_index(drop=True)

        # Guardar en resultados_colorloto2 vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_colorloto2 (
                    id SERIAL PRIMARY KEY,
                    concurso INT,
                    loteria_id INT REFERENCES loterias(id),
                    fecha DATE NOT NULL,
                    posicion INT NOT NULL,
                    color VARCHAR(20) NOT NULL,
                    numero INT NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_colorloto2_fecha_posicion ON resultados_colorloto2 (fecha, posicion);
            """))

        insert_sql2 = """
            INSERT INTO resultados_colorloto2 (
                concurso, loteria_id, fecha, posicion, color, numero, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, posicion)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_colorloto2.concurso),
                loteria_id = EXCLUDED.loteria_id,
                color = EXCLUDED.color,
                numero = EXCLUDED.numero,
                updated_at = CURRENT_TIMESTAMP;
        """

        data_tuples2 = [
            (
                int(r['concurso']) if pd.notna(r.get('concurso')) and r.get('concurso') else None,
                int(self.loteria_id),
                str(r['fecha']),
                int(r['posicion']),
                str(r['color']),
                int(r['numero'])
            )
            for r in df_final.to_dict(orient='records')
        ]

        raw_conn = self.engine.raw_connection()
        try:
            chunk_size = 500
            for i in range(0, len(data_tuples2), chunk_size):
                chunk = data_tuples2[i:i + chunk_size]
                with raw_conn.cursor() as cur:
                    execute_values(
                        cur, insert_sql2, chunk,
                        template="(%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ ¡DataFrame de ColorLoto guardado exitosamente en resultados_colorloto2! Total filas: {len(df_final)}")

        # También sincronizar tabla ancha resultados_colorloto
        try:
            df_wide = df_final.pivot_table(index=['fecha', 'concurso', 'loteria_id'], columns='color', values='numero', aggfunc='first').reset_index()
            cols_req = ['amarillo', 'azul', 'rojo', 'verde', 'blanco', 'negro']
            for col in cols_req:
                if col not in df_wide.columns:
                    df_wide[col] = 0
                else:
                    df_wide[col] = df_wide[col].fillna(0).astype(int)

            with self.engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS resultados_colorloto (
                        id SERIAL PRIMARY KEY,
                        concurso INT,
                        loteria_id INT REFERENCES loterias(id),
                        fecha DATE NOT NULL,
                        amarillo INT,
                        azul INT,
                        rojo INT,
                        verde INT,
                        blanco INT,
                        negro INT,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                    CREATE UNIQUE INDEX IF NOT EXISTS uq_colorloto_fecha ON resultados_colorloto (fecha);
                """))

            insert_wide = """
                INSERT INTO resultados_colorloto (
                    concurso, loteria_id, fecha,
                    amarillo, azul, rojo, verde, blanco, negro,
                    created_at, updated_at
                ) VALUES %s
                ON CONFLICT (fecha)
                DO UPDATE SET
                    concurso = COALESCE(EXCLUDED.concurso, resultados_colorloto.concurso),
                    loteria_id = EXCLUDED.loteria_id,
                    amarillo = EXCLUDED.amarillo,
                    azul = EXCLUDED.azul,
                    rojo = EXCLUDED.rojo,
                    verde = EXCLUDED.verde,
                    blanco = EXCLUDED.blanco,
                    negro = EXCLUDED.negro,
                    updated_at = CURRENT_TIMESTAMP;
            """
            data_wide = [
                (
                    int(r['concurso']) if pd.notna(r.get('concurso')) and r.get('concurso') else None,
                    int(self.loteria_id),
                    str(r['fecha']),
                    int(r.get('amarillo', 0) or 0),
                    int(r.get('azul', 0) or 0),
                    int(r.get('rojo', 0) or 0),
                    int(r.get('verde', 0) or 0),
                    int(r.get('blanco', 0) or 0),
                    int(r.get('negro', 0) or 0),
                )
                for r in df_wide.to_dict(orient='records')
            ]

            raw_conn = self.engine.raw_connection()
            try:
                for i in range(0, len(data_wide), 500):
                    chunk = data_wide[i:i + 500]
                    with raw_conn.cursor() as cur:
                        execute_values(
                            cur, insert_wide, chunk,
                            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                        )
                    raw_conn.commit()
            finally:
                raw_conn.close()
            print(f"✅ Tabla ancha resultados_colorloto sincronizada exitosamente! Total sorteos: {len(df_wide)}")
        except Exception as e:
            print(f"⚠️ Error sincronizando tabla ancha resultados_colorloto: {e}")

        # Actualizar Jackpot
        try:
            print("➡️ Consultando jackpot para ColorLoto desde la página de inicio...")
            r_main = requests.get("https://baloto.com/", headers=self.headers, timeout=15)
            if r_main.status_code == 200:
                soup_main = BeautifulSoup(r_main.text, "html.parser")
                colorloto_home = soup_main.find(class_="accumulated-colorloto-home")
                if colorloto_home:
                    integer = colorloto_home.find(class_="accum-integer")
                    jackpot_colorloto = integer.get_text(strip=True) + " millones" if integer else None
                    accum2 = colorloto_home.find(class_="accumulated-2")
                    fecha_str = accum2.find(class_="fs-5").get_text(strip=True) if accum2 and accum2.find(class_="fs-5") else None
                    if jackpot_colorloto and fecha_str:
                        self.update_jackpot(jackpot_colorloto, fecha_str)
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot ColorLoto: {e}")

        return True

if __name__ == "__main__":
    ColorLotoScraper().run(backfill=True)


