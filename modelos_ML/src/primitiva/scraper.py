import sys
import time
import re
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
import requests
from bs4 import BeautifulSoup

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine
from sqlalchemy import text
from psycopg2.extras import execute_values

class PrimitivaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 27
        self.base_url = "https://www.laprimitiva.info/"
        self.archive_url = "https://www.laprimitiva.info/historico/listado.html"
        self.game_name = "La Primitiva"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-ES,es;q=0.9,en;q=0.8"
        }
        # Sorteos: Lunes (0), Jueves (3), Sábado (5)
        self.draw_days = (0, 3, 5)
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
        }
        self.meses_abrev = {
            'ene': '01', 'feb': '02', 'mar': '03', 'abr': '04',
            'may': '05', 'jun': '06', 'jul': '07', 'ago': '08',
            'sep': '09', 'oct': '10', 'nov': '11', 'dic': '12'
        }

    def update_jackpot(self, engine, loteria, jackpot, fecha):
        if not jackpot or not fecha:
            return
        
        try:
            with engine.connect() as conn:
                print(f"💰 Actualizando jackpot para {loteria}: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": loteria, "fecha": fecha, "jackpot": jackpot})
                
                # Limpiar registros de jackpots más viejos a 5 días
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": loteria})
                conn.commit()
        except Exception as e:
            print(f"❌ Error actualizando jackpot para {loteria} en BD: {e}")

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo REAL registrado en la BD (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, sorteo
                    FROM resultados_primitiva
                    WHERE balota1 > 0
                    ORDER BY fecha DESC
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
        """Extrae el último sorteo REAL publicado en la página principal."""
        try:
            draws, jackpot_str, next_draw_date, concurso_reciente = self.scrape_recent_draws()
            if draws:
                d = draws[0]
                return {
                    "concurso": d.get("concurso"),
                    "fecha": d.get("fecha"),
                    "sorteo": d.get("sorteo"),
                    "balotas": [d["balota1"], d["balota2"], d["balota3"], d["balota4"], d["balota5"], d["balota6"]],
                    "complementario": d.get("balotaroja"),
                    "reintegro": d.get("balotaroja2"),
                    "jackpot_str": jackpot_str,
                    "next_draw_date": next_draw_date,
                    "raw_draws": draws
                }
        except Exception as e:
            print(f"⚠️ Error extrayendo último sorteo de la fuente La Primitiva: {e}")
        return None

    def scrape_recent_draws(self):
        """Extrae el sorteo más reciente y el bote desde la página principal de La Primitiva."""
        print(f"➡️ Solicitando resultados recientes desde {self.base_url}...")
        response = None
        for intento in range(3):
            try:
                response = requests.get(self.base_url, headers=self.headers, timeout=15)
                if response.status_code == 200:
                    break
            except Exception as e:
                if intento == 2:
                    print(f"❌ Error conectando a {self.base_url}: {e}")
                    return [], None, None, None
                time.sleep(2)

        if not response or response.status_code != 200:
            return [], None, None, None

        soup = BeautifulSoup(response.text, "html.parser")
        jackpot_str = None
        next_draw_date = None

        # 1. Extraer bote/jackpot y próxima fecha de sorteo
        txtpub_list = soup.find_all(class_=lambda c: c and ("txtpub" in c or "txtpubli" in c))
        for txtpub in txtpub_list:
            p_text = txtpub.get_text(" ", strip=True)
            if "primitiva" in p_text.lower() or "bote" in p_text.lower():
                m_num = re.search(r'([0-9\.,]+(?:\s*millon(?:es)?)?)\s*€?', p_text, re.IGNORECASE)
                if m_num:
                    val = m_num.group(1).strip()
                    num_clean = re.sub(r'[^\d]', '', val)
                    if num_clean and int(num_clean) >= 500000:
                        jackpot_str = f"{val} €"

                m_next = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)(?:\s+de\s+(\d{4}))?', p_text)
                if m_next:
                    d_day = m_next.group(1)
                    d_mon = m_next.group(2).lower().strip()
                    d_yr = m_next.group(3) or str(datetime.now().year)
                    mon_num = self.meses.get(d_mon)
                    if mon_num:
                        next_draw_date = f"{d_yr}-{mon_num}-{d_day.zfill(2)}"
                if jackpot_str:
                    break

        if not jackpot_str:
            jackpot_str = "5.000.000 €"

        # 2. Extraer último sorteo
        draws = []
        concurso_reciente = None
        art = soup.find("article", class_="result")
        if art:
            m_concurso = re.search(r'Sorteo\s+(\d+)', art.get_text())
            if m_concurso:
                concurso_reciente = int(m_concurso.group(1))

            date_p = art.find("p", class_="date")
            if date_p:
                date_txt = date_p.get_text(strip=True)
                m_date = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+de\s+(\d{4})', date_txt)
                if m_date:
                    day, month_str, year = m_date.groups()
                    month_clean = month_str.lower().strip()
                    mon_num = self.meses.get(month_clean)
                    if mon_num:
                        fecha_str = f"{year}-{mon_num}-{day.zfill(2)}"

                        combi_div = art.find("div", class_="combi")
                        if combi_div:
                            nums_divs = combi_div.find_all("div", class_="num")
                            num_vals = [int(nd.get_text(strip=True)) for nd in nums_divs if nd.get_text(strip=True).isdigit()]
                            if len(num_vals) >= 8:
                                # 6 regulares, 1 complementario, 1 reintegro (conservando orden exacto de extracción)
                                draws.append({
                                    "concurso": concurso_reciente,
                                    "loteria_id": self.loteria_id,
                                    "sorteo": self.game_name,
                                    "fecha": fecha_str,
                                    "balota1": num_vals[0],
                                    "balota2": num_vals[1],
                                    "balota3": num_vals[2],
                                    "balota4": num_vals[3],
                                    "balota5": num_vals[4],
                                    "balota6": num_vals[5],
                                    "balotaroja": num_vals[6], # Complementario
                                    "balotaroja2": num_vals[7] # Reintegro
                                })

        return draws, jackpot_str, next_draw_date, concurso_reciente

    def scrape_historical_years(self):
        """Extrae el histórico completo de sorteos de La Primitiva clasificados por año."""
        print(f"📚 Iniciando extracción histórica completa desde {self.archive_url}...")
        try:
            r = requests.get(self.archive_url, headers=self.headers, timeout=15)
            if r.status_code != 200:
                print("⚠️ Error accediendo al archivo histórico de La Primitiva.")
                return []
        except Exception as e:
            print(f"⚠️ Error conectando al archivo histórico de La Primitiva: {e}")
            return []

        soup = BeautifulSoup(r.text, "html.parser")
        year_links = []
        for a in soup.select("table a") or soup.find_all("a", href=True):
            txt = a.get_text(strip=True)
            if re.match(r'^(19\d{2}|20\d{2})$', txt):
                year_links.append((txt, a['href']))

        all_draws = []
        for year_text, href in year_links:
            if href.startswith("http"):
                year_url = href
            elif href.startswith("/"):
                year_url = f"https://www.laprimitiva.info{href}"
            else:
                clean_href = href.replace("../historico/", "")
                year_url = f"https://www.laprimitiva.info/historico/{clean_href}"

            print(f"   ⏳ Descargando sorteos de La Primitiva año {year_text} ({year_url})...")
            try:
                ry = requests.get(year_url, headers=self.headers, timeout=15)
                if ry.status_code != 200:
                    continue
                sy = BeautifulSoup(ry.text, "html.parser")
                table = sy.find("table")
                if not table:
                    continue

                rows = table.find_all("tr")
                seen_ene = False

                for row in rows:
                    tds = [td.get_text(strip=True) for td in row.find_all("td")]
                    
                    date_idx = None
                    for idx, text_val in enumerate(tds):
                        if re.match(r'^\d{1,2}-[a-z]{3}$', text_val.lower()):
                            date_idx = idx
                            break
                    if date_idx is None:
                        continue

                    concurso_val = None
                    if date_idx > 0:
                        m_c = re.search(r'/(\d+)', tds[0])
                        if m_c:
                            concurso_val = int(m_c.group(1))
                        elif tds[0].isdigit():
                            concurso_val = int(tds[0])

                    date_str = tds[date_idx].lower()
                    day_part, mon_part = date_str.split('-')
                    mon_num = self.meses_abrev.get(mon_part)
                    if not mon_num:
                        continue

                    if mon_part == 'ene':
                        seen_ene = True

                    draw_year = int(year_text)
                    if mon_part == 'dic' and not seen_ene:
                        draw_year -= 1

                    fecha_str = f"{draw_year}-{mon_num}-{day_part.zfill(2)}"

                    num_cols = tds[date_idx + 1: date_idx + 7]
                    comp_col = tds[date_idx + 7: date_idx + 8]
                    rein_col = tds[date_idx + 8: date_idx + 9]

                    try:
                        nums = [int(n) for n in num_cols if n.isdigit()]
                        comp = int(comp_col[0]) if comp_col and comp_col[0].isdigit() else 0
                        rein = int(rein_col[0]) if rein_col and rein_col[0].isdigit() else 0

                        # Corrección de errata histórica en la tabla web oficial para 2019-06-20
                        if fecha_str == "2019-06-20" and rein == 20:
                            rein = 2

                        if len(nums) == 6:
                            all_draws.append({
                                "concurso": concurso_val,
                                "loteria_id": self.loteria_id,
                                "sorteo": self.game_name,
                                "fecha": fecha_str,
                                "balota1": nums[0],
                                "balota2": nums[1],
                                "balota3": nums[2],
                                "balota4": nums[3],
                                "balota5": nums[4],
                                "balota6": nums[5],
                                "balotaroja": comp,
                                "balotaroja2": rein
                            })
                    except ValueError:
                        continue
                time.sleep(0.2)
            except Exception as ey:
                print(f"   ⚠️ Error en año {year_text}: {ey}")

        print(f"📊 Total sorteos históricos extraídos para La Primitiva: {len(all_draws)}")
        return all_draws

    def run(self, backfill=False):
        print("🚀 Iniciando Scraping de La Primitiva (España)...")

        # 1. Detección temprana: comparar último sorteo real en BD vs fuente
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and ultimo_db and ultimo_fuente:
            fecha_db = str(ultimo_db.get("fecha"))
            fecha_fuente = str(ultimo_fuente.get("fecha"))

            if fecha_fuente and fecha_db and fecha_fuente <= fecha_db:
                print(f"ℹ️ Detección temprana: No hay sorteo nuevo para La Primitiva.")
                print(f"   BD: {fecha_db} vs Fuente: {fecha_fuente}")

                next_draw_date = ultimo_fuente.get("next_draw_date")
                if next_draw_date:
                    cur_date = datetime.strptime(next_draw_date, "%Y-%m-%d").date()
                else:
                    try:
                        f_dt = datetime.strptime(fecha_db, "%Y-%m-%d").date()
                    except Exception:
                        f_dt = fecha_db
                    cur_date = f_dt + timedelta(days=1)
                    while cur_date.weekday() not in self.draw_days:
                        cur_date += timedelta(days=1)

                c_num = ultimo_db.get("concurso")
                prox_c = (c_num + 1) if c_num else None

                jackpot_str = ultimo_fuente.get("jackpot_str")
                if jackpot_str:
                    target_fecha = cur_date.strftime('%Y-%m-%d')
                    self.update_jackpot(self.engine, "primitiva", jackpot_str, target_fecha)

                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"{fecha_db} (#{c_num})" if c_num else f"{fecha_db}",
                    "proximo_esperado": f"{cur_date.strftime('%d/%m/%Y')} (#{prox_c})" if prox_c else f"{cur_date.strftime('%d/%m/%Y')}"
                }

        # 2. Obtener datos
        resultados = []
        if ultimo_fuente and "raw_draws" in ultimo_fuente:
            recent_draws = ultimo_fuente["raw_draws"]
            jackpot_str = ultimo_fuente.get("jackpot_str")
            next_draw_date = ultimo_fuente.get("next_draw_date")
            concurso_reciente = ultimo_fuente.get("concurso")
        else:
            recent_draws, jackpot_str, next_draw_date, concurso_reciente = self.scrape_recent_draws()
        resultados.extend(recent_draws)

        existing_df = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                existing_df = pd.read_sql(
                    "SELECT concurso, loteria_id, sorteo, fecha, balota1, balota2, balota3, balota4, balota5, balota6, balotaroja, balotaroja2 FROM resultados_primitiva WHERE balota1 > 0;",
                    conn
                )
                print(f"📦 Registros históricos existentes en BD: {len(existing_df)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        needs_backfill = backfill or (len(existing_df) < 100)

        if needs_backfill:
            hist_draws = self.scrape_historical_years()
            resultados.extend(hist_draws)

        df_new = pd.DataFrame(resultados) if resultados else pd.DataFrame()

        dfs_to_combine = []
        if not df_new.empty:
            dfs_to_combine.append(df_new)
        if not existing_df.empty:
            dfs_to_combine.append(existing_df)

        if not dfs_to_combine:
            print("❌ No se obtuvieron resultados de La Primitiva.")
            return False

        df_combined = pd.concat(dfs_to_combine, ignore_index=True)
        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce').dt.date
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]

        hoy_max = (datetime.now() + timedelta(days=1)).date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(by='fecha', ascending=False).reset_index(drop=True)
        df_final = df_combined

        # Determinar próximo sorteo y próximo concurso
        prox_concurso = (concurso_reciente + 1) if concurso_reciente else None
        if not prox_concurso and not df_final.empty:
            c_vals = df_final[df_final['concurso'].notna()]['concurso']
            if not c_vals.empty:
                prox_concurso = int(c_vals.max()) + 1

        fecha_max_hist = df_final['fecha'].max()
        try:
            if next_draw_date:
                cur_date = datetime.strptime(next_draw_date, "%Y-%m-%d").date()
            else:
                cur_date = fecha_max_hist + timedelta(days=1)
                while cur_date.weekday() not in self.draw_days:
                    cur_date += timedelta(days=1)

            df_prox = pd.DataFrame([{
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'sorteo': self.game_name,
                'fecha': cur_date,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0, 'balota6': 0,
                'balotaroja': 0, 'balotaroja2': 0
            }])
            print(f"📅 Fecha del próximo sorteo agregada para La Primitiva: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo La Primitiva: {e}")
            cur_date = fecha_max_hist + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)
            df_prox = pd.DataFrame([{
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'sorteo': self.game_name,
                'fecha': cur_date,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0, 'balota6': 0,
                'balotaroja': 0, 'balotaroja2': 0
            }])

        if backfill:
            df_to_save = pd.concat([df_prox, df_final], ignore_index=True)
        else:
            df_to_save = pd.concat([df_prox, df_new], ignore_index=True)
            df_to_save = df_to_save.drop_duplicates(subset=['fecha', 'sorteo'], keep='first')

        # Guardar en Base de Datos vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_primitiva (
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
                    balota6 INT NOT NULL,
                    balotaroja INT NOT NULL DEFAULT 0,
                    balotaroja2 INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_primitiva_fecha_sorteo ON resultados_primitiva (fecha, sorteo);
            """))

        # Eliminar posibles placeholders obsoletos anteriores a cur_date
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_primitiva
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": cur_date})

        insert_sql = """
            INSERT INTO resultados_primitiva (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balota6,
                balotaroja, balotaroja2, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_primitiva.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                balota6 = EXCLUDED.balota6,
                balotaroja = EXCLUDED.balotaroja,
                balotaroja2 = EXCLUDED.balotaroja2,
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
                int(r['balotaroja']),
                int(r['balotaroja2'])
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
                        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ Resultados de La Primitiva guardados exitosamente! Total filas procesadas: {len(df_to_save)}")

        if jackpot_str:
            target_fecha = next_draw_date if next_draw_date else cur_date.strftime('%Y-%m-%d')
            self.update_jackpot(self.engine, "primitiva", jackpot_str, target_fecha)

        return {
            "hubo_sorteo": True,
            "ultimo_sorteo": f"{fecha_max_hist.strftime('%d/%m/%Y')}" if hasattr(fecha_max_hist, 'strftime') else str(fecha_max_hist),
            "proximo_esperado": f"{cur_date.strftime('%d/%m/%Y')} (#{prox_concurso})" if prox_concurso else f"{cur_date.strftime('%d/%m/%Y')}"
        }

if __name__ == "__main__":
    PrimitivaScraper().run(backfill=False)
