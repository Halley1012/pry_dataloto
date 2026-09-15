import sys
import time
import re
from pathlib import Path
from datetime import datetime, timedelta, date
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

class EuromillonesScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 25
        self.base_url = "https://www.euromillones.com.es/resultados-anteriores.html"
        self.archive_url = "https://www.euromillones.com.es/historico/euromillones-anos-anteriores.html"
        self.game_name = "Euromillones"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-ES,es;q=0.9,en;q=0.8"
        }
        # Sorteos: Martes (1), Viernes (4)
        self.draw_days = (1, 4)
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
                    FROM resultados_euromillones
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
        """Extrae el último sorteo REAL publicado en la fuente."""
        try:
            draws, jackpot_str, next_draw_date = self.scrape_recent_draws()
            if draws:
                d = draws[0]
                return {
                    "concurso": None,
                    "sorteo": d[0],
                    "fecha": d[1],
                    "balotas": [d[2], d[3], d[4], d[5], d[6]],
                    "estrellas": [d[7], d[8]],
                    "jackpot_str": jackpot_str,
                    "next_draw_date": next_draw_date,
                    "raw_draws": draws
                }
        except Exception as e:
            print(f"⚠️ Error extrayendo último sorteo de la fuente Euromillones: {e}")
        return None

    def scrape_recent_draws(self):
        """Extrae los sorteos más recientes y la información del jackpot desde la página principal de resultados."""
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
                    return [], None, None
                time.sleep(2)

        if not response or response.status_code != 200:
            return [], None, None

        soup = BeautifulSoup(response.text, "html.parser")
        
        # 1. Extraer Jackpot y fecha del próximo sorteo
        jackpot_str = None
        next_draw_date = None
        txtpub = soup.find(class_=lambda c: c and ("txtpub" in c or "txtpubli" in c))
        if txtpub:
            h3 = txtpub.find("h3")
            if h3:
                jackpot_str = h3.get_text(" ", strip=True)
            p = txtpub.find("p")
            if p:
                p_text = p.get_text(strip=True)
                m_next = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+de\s+(\d{4})', p_text)
                if m_next:
                    d_day, d_mon, d_yr = m_next.groups()
                    mon_clean = d_mon.lower().strip()
                    mon_num = self.meses.get(mon_clean)
                    if mon_num:
                        next_draw_date = f"{d_yr}-{mon_num}-{d_day.zfill(2)}"

        # 2. Extraer lista de sorteos (conservando orden natural de extracción)
        items = soup.select("article#sorteosant ul.listado li.blq")
        draws = []
        for item in items:
            h4 = item.find("h4")
            if not h4:
                continue
            h4_text = h4.get_text(strip=True)
            m = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+de\s+(\d{4})', h4_text)
            if not m:
                continue
            day, month_str, year = m.groups()
            month_clean = month_str.lower().strip()
            month_num = self.meses.get(month_clean)
            if not month_num:
                continue
            fecha_str = f"{year}-{month_num}-{day.zfill(2)}"

            num_lis = item.select("li.numeros")
            estrella_lis = item.select("li.estrellas")

            nums = [int(li.get_text(strip=True)) for li in num_lis if li.get_text(strip=True).isdigit()]
            stars = [int(li.get_text(strip=True)) for li in estrella_lis if li.get_text(strip=True).isdigit()]

            if len(nums) == 5 and len(stars) >= 1:
                star1 = stars[0]
                star2 = stars[1] if len(stars) > 1 else 0
                draws.append([self.game_name, fecha_str, nums[0], nums[1], nums[2], nums[3], nums[4], star1, star2])

        return draws, jackpot_str, next_draw_date

    def scrape_historical_years(self):
        """Extrae el histórico completo de sorteos clasificados por año desde 2004 al presente."""
        print(f"📚 Iniciando extracción histórica completa desde {self.archive_url}...")
        try:
            r = requests.get(self.archive_url, headers=self.headers, timeout=15)
            if r.status_code != 200:
                print("⚠️ Error accediendo al archivo histórico general.")
                return []
        except Exception as e:
            print(f"⚠️ Error conectando al archivo histórico: {e}")
            return []

        soup = BeautifulSoup(r.text, "html.parser")
        year_links = soup.select("table.histoeuro a")
        
        all_draws = []
        for a in year_links:
            year_text = a.get_text(strip=True)
            if not year_text.isdigit():
                continue
            href = a.get("href", "")
            if not href:
                continue
            
            if href.startswith("http"):
                year_url = href
            elif href.startswith("/"):
                year_url = f"https://www.euromillones.com.es{href}"
            else:
                year_url = f"https://www.euromillones.com.es/historico/{href}"

            print(f"   ⏳ Descargando sorteos del año {year_text} ({year_url})...")
            try:
                ry = requests.get(year_url, headers=self.headers, timeout=15)
                if ry.status_code != 200:
                    continue
                sy = BeautifulSoup(ry.text, "html.parser")
                table = sy.find("table", class_="histoeuro")
                if not table:
                    continue

                rows = table.find_all("tr")
                for row in rows:
                    tds = row.find_all("td")
                    td_texts = [td.get_text(strip=True) for td in tds]
                    
                    date_idx = None
                    for idx, text_val in enumerate(td_texts):
                        if re.match(r'^\d{1,2}-[a-z]{3}$', text_val.lower()):
                            date_idx = idx
                            break
                    if date_idx is None:
                        continue

                    date_str = td_texts[date_idx].lower()
                    day_part, mon_part = date_str.split('-')
                    mon_num = self.meses_abrev.get(mon_part)
                    if not mon_num:
                        continue

                    draw_year = int(year_text)
                    if mon_part == 'dic' and date_idx > 0 and len(td_texts) > date_idx - 1:
                        first_col = td_texts[0]
                        if first_col == '1' and int(td_texts[1]) > 90:
                            draw_year -= 1

                    fecha_str = f"{draw_year}-{mon_num}-{day_part.zfill(2)}"

                    num_cols = td_texts[date_idx + 1: date_idx + 6]
                    star_cols = td_texts[date_idx + 6: date_idx + 8]

                    try:
                        nums = [int(n) for n in num_cols if n.isdigit()]
                        stars = [int(s) for s in star_cols if s.isdigit()]
                        if len(nums) == 5 and len(stars) == 2:
                            all_draws.append([self.game_name, fecha_str, nums[0], nums[1], nums[2], nums[3], nums[4], stars[0], stars[1]])
                    except ValueError:
                        continue
                time.sleep(0.3)
            except Exception as ey:
                print(f"   ⚠️ Error en año {year_text}: {ey}")

        print(f"📊 Total sorteos históricos extraídos de archivos anuales: {len(all_draws)}")
        return all_draws

    def run(self, backfill=False):
        print("🚀 Iniciando Scraping de Euromillones (España)...")

        # 1. Detección temprana: comparar último sorteo real en BD vs fuente
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and ultimo_db and ultimo_fuente:
            fecha_db = str(ultimo_db.get("fecha"))
            fecha_fuente = str(ultimo_fuente.get("fecha"))

            if fecha_fuente and fecha_db and fecha_fuente <= fecha_db:
                print(f"ℹ️ Detección temprana: No hay sorteo nuevo para Euromillones.")
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
                    self.update_jackpot(self.engine, "euromillones", jackpot_str, target_fecha)

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
        else:
            recent_draws, jackpot_str, next_draw_date = self.scrape_recent_draws()
        resultados.extend(recent_draws)

        existing_df = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                res = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'resultados_euromillones';")).scalar()
                if res > 0:
                    existing_df = pd.read_sql(text("SELECT * FROM resultados_euromillones WHERE balota1 > 0;"), conn)
                    print(f"📦 Registros históricos existentes en BD: {len(existing_df)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        needs_backfill = backfill or (len(existing_df) < 100)

        if needs_backfill:
            hist_draws = self.scrape_historical_years()
            resultados.extend(hist_draws)

        columns = ["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja", "balotaroja2"]
        df_new = pd.DataFrame(resultados, columns=columns) if resultados else pd.DataFrame(columns=columns)

        if not existing_df.empty:
            df_combined = pd.concat([df_new, existing_df], ignore_index=True)
        else:
            df_combined = df_new

        if df_combined.empty:
            print("❌ No se obtuvieron resultados de Euromillones.")
            return False

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce')
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]
        hoy_max = pd.to_datetime('now') + timedelta(days=1)
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values('fecha', ascending=True).reset_index(drop=True)

        # Asignar concurso secuencial desde 2004
        df_combined['concurso'] = range(1, len(df_combined) + 1)

        # --- Agregar fila del próximo sorteo en cero ---
        prox_concurso = int(df_combined['concurso'].max()) + 1
        try:
            if next_draw_date:
                cur_date = pd.to_datetime(next_draw_date)
            else:
                fecha_max_hist = df_combined['fecha'].max()
                cur_date = fecha_max_hist + timedelta(days=1)
                while cur_date.weekday() not in self.draw_days:
                    cur_date += timedelta(days=1)

            df_prox = pd.DataFrame([{
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'sorteo': self.game_name,
                'fecha': cur_date,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0,
                'balotaroja': 0, 'balotaroja2': 0
            }])
            print(f"📅 Fecha del próximo sorteo agregada para Euromillones: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Euromillones: {e}")
            cur_date = df_combined['fecha'].max() + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)
            df_prox = pd.DataFrame([{
                'concurso': prox_concurso,
                'loteria_id': self.loteria_id,
                'sorteo': self.game_name,
                'fecha': cur_date,
                'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0,
                'balotaroja': 0, 'balotaroja2': 0
            }])

        if backfill:
            df_to_save = pd.concat([df_prox, df_combined.sort_values('fecha', ascending=False)], ignore_index=True)
        else:
            df_to_save = pd.concat([df_prox, df_new], ignore_index=True)
            df_to_save = df_to_save.drop_duplicates(subset=['fecha', 'sorteo'], keep='first')

        # Guardar en Base de Datos vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_euromillones (
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
                    balotaroja2 INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_euromillones_fecha_sorteo ON resultados_euromillones (fecha, sorteo);
            """))

        # Eliminar posibles placeholders obsoletos anteriores a cur_date
        c_date_val = cur_date.date() if hasattr(cur_date, 'date') else cur_date
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_euromillones
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": c_date_val})

        insert_sql = """
            INSERT INTO resultados_euromillones (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, balotaroja2, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_euromillones.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                balotaroja = EXCLUDED.balotaroja,
                balotaroja2 = EXCLUDED.balotaroja2,
                updated_at = CURRENT_TIMESTAMP;
        """

        records = []
        for _, row in df_to_save.iterrows():
            c_val = int(row['concurso']) if pd.notnull(row.get('concurso')) and row.get('concurso') is not None else None
            f_val = row['fecha'].date() if hasattr(row['fecha'], 'date') else row['fecha']
            records.append((
                c_val,
                self.loteria_id,
                str(row['sorteo']),
                f_val,
                int(row['balota1']),
                int(row['balota2']),
                int(row['balota3']),
                int(row['balota4']),
                int(row['balota5']),
                int(row.get('balotaroja', 0)),
                int(row.get('balotaroja2', 0)),
                datetime.now(),
                datetime.now()
            ))

        raw_conn = self.engine.raw_connection()
        try:
            chunk_size = 500
            for i in range(0, len(records), chunk_size):
                chunk = records[i:i + chunk_size]
                with raw_conn.cursor() as cur:
                    execute_values(cur, insert_sql, chunk, page_size=500)
                raw_conn.commit()
            print(f"✅ Resultados de Euromillones guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        if jackpot_str:
            target_fecha = next_draw_date if next_draw_date else cur_date.strftime('%Y-%m-%d')
            self.update_jackpot(self.engine, "euromillones", jackpot_str, target_fecha)

        ultimo_real = df_combined.iloc[-1]['fecha']
        return {
            "hubo_sorteo": True,
            "ultimo_sorteo": f"{ultimo_real.strftime('%d/%m/%Y')}" if hasattr(ultimo_real, 'strftime') else str(ultimo_real),
            "proximo_esperado": f"{cur_date.strftime('%d/%m/%Y')} (#{prox_concurso})"
        }

if __name__ == "__main__":
    EuromillonesScraper().run(backfill=False)
