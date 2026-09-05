import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import pandas as pd
import concurrent.futures
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
from psycopg2.extras import execute_values
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class CincoDeOroScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 34
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-UY,es-419;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.base_url = "https://www.combinacionganadora.com/uy/5-de-oro/resultados"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de 5 de Oro: Miércoles (2) y Domingos (6).
        Calcula la próxima fecha de sorteo válida que sea >= a hoy y posterior a la última fecha real.
        """
        dias_validos = {2, 6} # Miércoles (2), Domingo (6)
        hoy = datetime.now().date()
        base = max(ultima_fecha_real, hoy)
        
        if hoy.weekday() in dias_validos and ultima_fecha_real < hoy:
            return hoy
            
        candidate = base + timedelta(days=1)
        while candidate.weekday() not in dias_validos or candidate <= ultima_fecha_real:
            candidate += timedelta(days=1)
        return candidate

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo REAL registrado en la BD (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, sorteo
                    FROM resultados_5deoro
                    WHERE balota1 > 0
                    ORDER BY fecha DESC, sorteo ASC
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
        """Extrae el último sorteo REAL publicado en la fuente en vivo (InfoUruguay)."""
        try:
            live_draws, fecha_proximo_oficial, pozo_oficial = self.extraer_en_vivo_infouruguay()
            if live_draws:
                fecha_str = live_draws[0]["fecha"]
                return {
                    "fecha": fecha_str,
                    "live_draws": live_draws,
                    "fecha_proximo": fecha_proximo_oficial,
                    "pozo": pozo_oficial
                }
        except Exception as e:
            print(f"⚠️ Error extrayendo último sorteo de la fuente 5 de Oro: {e}")
        return None

    def extraer_en_vivo_infouruguay(self) -> tuple:
        """Extrae los últimos sorteos en vivo y la fecha/pozo oficial de InfoUruguay."""
        print("➡️ Consultando fuente en vivo de InfoUruguay...")
        live_draws = []
        fecha_proximo_oficial = None
        pozo_oficial = None

        try:
            r = requests.post("https://www.infouruguay.com.uy/RES_5_ORO.php", data="5 DE ORO", headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                spans = soup.find_all("span", style=re.compile(r"font-size:18px"))

                # 1. Extraer fecha del último sorteo
                m_fecha = re.search(r'([A-Za-zÁ-ÿ]+)\s+(\d{1,2})/(\d{1,2})/(\d{4})', r.text)
                if m_fecha and len(spans) >= 3:
                    dia, mes, anio = m_fecha.group(2), m_fecha.group(3), m_fecha.group(4)
                    fecha_ult_str = f"{anio}-{int(mes):02d}-{int(dia):02d}"

                    # Extraer números 5 de Oro (conservando orden exacto de extracción)
                    oro_txt = spans[0].get_text(strip=True)
                    oro_nums = [int(n) for n in re.findall(r'\d+', oro_txt)]
                    extra_num = int(re.search(r'\d+', spans[1].get_text(strip=True)).group(0)) if re.search(r'\d+', spans[1].get_text(strip=True)) else 0

                    # Extraer números Revancha (conservando orden exacto de extracción)
                    rev_txt = spans[2].get_text(strip=True)
                    rev_nums = [int(n) for n in re.findall(r'\d+', rev_txt)]

                    if len(oro_nums) >= 5:
                        live_draws.append({
                            "sorteo": "5 de Oro",
                            "fecha": fecha_ult_str,
                            "balota1": oro_nums[0],
                            "balota2": oro_nums[1],
                            "balota3": oro_nums[2],
                            "balota4": oro_nums[3],
                            "balota5": oro_nums[4],
                            "balotaroja": extra_num
                        })

                    if len(rev_nums) >= 5:
                        live_draws.append({
                            "sorteo": "Revancha",
                            "fecha": fecha_ult_str,
                            "balota1": rev_nums[0],
                            "balota2": rev_nums[1],
                            "balota3": rev_nums[2],
                            "balota4": rev_nums[3],
                            "balota5": rev_nums[4],
                            "balotaroja": 0
                        })

                    print(f"✅ Sorteo en vivo obtenido de InfoUruguay para fecha: {fecha_ult_str}")

                # 2. Extraer fecha oficial del próximo sorteo (considera traslados por feriados nacionales)
                m_prox = re.search(r'Pozos estimados para el pr.*?ximo sorteo.*?>\s*([A-Za-zÁ-ÿ]+)\s+(\d{1,2})/(\d{1,2})/(\d{4})', r.text, re.DOTALL | re.IGNORECASE)
                if m_prox:
                    d_p, m_p, y_p = m_prox.group(2), m_prox.group(3), m_prox.group(4)
                    fecha_proximo_oficial = f"{y_p}-{int(m_p):02d}-{int(d_p):02d}"
                    print(f"📅 Fecha oficial del próximo sorteo detectada: {fecha_proximo_oficial}")

                # 3. Extraer pozo acumulado para el próximo sorteo
                prox_section = re.search(r'Pozos estimados para el pr.*?ximo sorteo(.*?)RESULTADOS ANTERIORES', r.text, re.DOTALL | re.IGNORECASE)
                if prox_section:
                    sec_text = prox_section.group(1)
                    m_pozo_oro = re.search(r'Pozo de Oro:\s*<strong>\s*\$\s*([0-9\.,]+)\s*</strong>', sec_text)
                    m_pozo_rev = re.search(r'Pozo Revancha:\s*<strong>\s*\$\s*([0-9\.,]+)\s*</strong>', sec_text)
                    if m_pozo_oro and m_pozo_rev:
                        oro_val = int(m_pozo_oro.group(1).replace('.', '').replace(',', ''))
                        rev_val = int(m_pozo_rev.group(1).replace('.', '').replace(',', ''))
                        total_pozo = oro_val + rev_val
                        pozo_oficial = f"$ {total_pozo:,}".replace(',', '.')
                    elif m_pozo_oro:
                        pozo_oficial = f"$ {m_pozo_oro.group(1).replace(' ', '')}"
        except Exception as e:
            print(f"⚠️ Error consultando InfoUruguay: {e}")

        return live_draws, fecha_proximo_oficial, pozo_oficial

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

    def _parsear_sorteo_fecha(self, fecha_str: str) -> list:
        """Descarga y parsea el sorteo de una fecha específica retornando filas para 5 de Oro y Revancha."""
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

                    # Conservar orden exacto entregado por la fuente (sin sorted)
                    if len(main_balls) == 5:
                        items = [
                            {
                                "sorteo": "5 de Oro",
                                "fecha": fecha_str,
                                "balota1": main_balls[0],
                                "balota2": main_balls[1],
                                "balota3": main_balls[2],
                                "balota4": main_balls[3],
                                "balota5": main_balls[4],
                                "balotaroja": extra_ball
                            }
                        ]
                        if len(rev_balls) == 5:
                            items.append({
                                "sorteo": "Revancha",
                                "fecha": fecha_str,
                                "balota1": rev_balls[0],
                                "balota2": rev_balls[1],
                                "balota3": rev_balls[2],
                                "balota4": rev_balls[3],
                                "balota5": rev_balls[4],
                                "balotaroja": 0
                            })
                        return items
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
                if isinstance(res, list):
                    draws.extend(res)
                else:
                    draws.append(res)

        print(f"📊 Filas procesadas de 5 de Oro y Revancha: {len(draws)}")
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

        # 1. Detección temprana: comparar último sorteo real en BD vs fuente en vivo
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and ultimo_db and ultimo_fuente:
            fecha_db = str(ultimo_db.get("fecha"))
            fecha_fuente = str(ultimo_fuente.get("fecha"))

            if fecha_fuente and fecha_db and fecha_fuente <= fecha_db:
                print(f"ℹ️ Detección temprana: No hay sorteo nuevo para 5 de Oro y Revancha.")
                print(f"   BD: {fecha_db} vs Fuente: {fecha_fuente}")

                fecha_proximo_oficial = ultimo_fuente.get("fecha_proximo")
                if fecha_proximo_oficial:
                    proxima_fecha = datetime.strptime(fecha_proximo_oficial, "%Y-%m-%d").date()
                else:
                    try:
                        f_dt = datetime.strptime(fecha_db, "%Y-%m-%d").date()
                    except Exception:
                        f_dt = fecha_db
                    proxima_fecha = self._calcular_proximo_sorteo(f_dt)

                pozo_oficial = ultimo_fuente.get("pozo") or self.extraer_pozo_estimado()
                if pozo_oficial:
                    self.actualizar_jackpot(proxima_fecha.strftime("%Y-%m-%d"), pozo_oficial)

                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"{fecha_db}",
                    "proximo_esperado": f"{proxima_fecha.strftime('%d/%m/%Y')}"
                }

        # 2. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT concurso, loteria_id, sorteo, fecha, balota1, balota2, balota3, balota4, balota5, balotaroja FROM resultados_5deoro WHERE balota1 > 0;"), conn)
                print(f"📦 Registros históricos existentes en BD: {len(df_existente)}")
        except Exception:
            pass

        # 3. Descargar histórico si es necesario
        live_draws = ultimo_fuente.get("live_draws") if ultimo_fuente else []
        fecha_proximo_oficial = ultimo_fuente.get("fecha_proximo") if ultimo_fuente else None
        pozo_info = ultimo_fuente.get("pozo") if ultimo_fuente else None

        if not live_draws:
            live_draws, fecha_proximo_oficial, pozo_info = self.extraer_en_vivo_infouruguay()

        pozo_oficial = pozo_info or self.extraer_pozo_estimado()

        if backfill or df_existente.empty or len(df_existente) < 50:
            df_scraped = self.extraer_historico_concurrente(max_draws=350)
        else:
            df_scraped = pd.DataFrame()

        # Combinar en vivo + existente + histórico
        dfs_to_combine = []
        if not df_scraped.empty:
            dfs_to_combine.append(df_scraped)
        if live_draws:
            dfs_to_combine.append(pd.DataFrame(live_draws))
        if not df_existente.empty and 'sorteo' in df_existente.columns:
            dfs_to_combine.append(df_existente)

        if not dfs_to_combine:
            print("❌ No se pudieron obtener resultados de 5 de Oro.")
            return False

        df_combined = pd.concat(dfs_to_combine, ignore_index=True)
        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(by=['fecha', 'sorteo'], ascending=[False, True]).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return False

        # 4. Determinar fecha del próximo sorteo (usando la fecha oficial anunciada o cálculo automático)
        df_real = df_combined[df_combined['balota1'] > 0]
        ultima_fecha_real = df_real.iloc[0]['fecha']

        if fecha_proximo_oficial:
            proxima_fecha_str = fecha_proximo_oficial
            proxima_fecha = datetime.strptime(fecha_proximo_oficial, "%Y-%m-%d").date()
        else:
            proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
            proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")

        print(f"📅 Fecha del próximo sorteo oficial establecida para 5 de Oro: {proxima_fecha_str}")

        # Filas placeholder en ceros
        filas_proximo = [
            {
                "concurso": None,
                "loteria_id": self.loteria_id,
                "sorteo": "5 de Oro",
                "fecha": proxima_fecha,
                "balota1": 0,
                "balota2": 0,
                "balota3": 0,
                "balota4": 0,
                "balota5": 0,
                "balotaroja": 0
            },
            {
                "concurso": None,
                "loteria_id": self.loteria_id,
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

        # Guardado optimizado
        if backfill:
            df_to_save = pd.concat([pd.DataFrame(filas_proximo), df_combined], ignore_index=True)
        else:
            dfs_new = [pd.DataFrame(filas_proximo)]
            if live_draws:
                dfs_new.append(pd.DataFrame(live_draws))
            if not df_scraped.empty:
                dfs_new.append(df_scraped)
            df_to_save = pd.concat(dfs_new, ignore_index=True).drop_duplicates(subset=['fecha', 'sorteo'], keep='first')

        # 5. Guardar en PostgreSQL de manera segura (UPSERT sin destruir estructura ni foreign keys)
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_5deoro (
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
                CREATE UNIQUE INDEX IF NOT EXISTS uq_5deoro_fecha_sorteo ON resultados_5deoro (fecha, sorteo);
            """))

        # Limpiar posibles placeholders obsoletos anteriores a proxima_fecha
        # CONDICIÓN ESTRICTA: SOLO borrar si balota1 = 0 para jamás tocar un sorteo real
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_5deoro
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": proxima_fecha})

        insert_sql = """
            INSERT INTO resultados_5deoro (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_5deoro.concurso),
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
                int(r.get('balotaroja', 0))
            )
            for r in df_to_save.to_dict(orient='records')
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

        print(f"✅ Resultados de 5 de Oro y Revancha guardados exitosamente! Total filas procesadas: {len(df_to_save)}")
        self.actualizar_jackpot(proxima_fecha_str, pozo_oficial)

        return {
            "hubo_sorteo": True,
            "ultimo_sorteo": f"{ultima_fecha_real.strftime('%d/%m/%Y')}" if hasattr(ultima_fecha_real, 'strftime') else str(ultima_fecha_real),
            "proximo_esperado": f"{proxima_fecha.strftime('%d/%m/%Y')}"
        }

if __name__ == "__main__":
    scraper = CincoDeOroScraper()
    scraper.run(backfill=False)
