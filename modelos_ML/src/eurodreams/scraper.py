import sys
import re
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
from concurrent.futures import ThreadPoolExecutor, as_completed
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class EuroDreamsScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 29
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        }
        self.url_recientes = "https://www.combinacionganadora.com/eurodreams/resultados/"
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
        }

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """
        Los sorteos de EuroDreams se realizan los Lunes (weekday 0) y Jueves (weekday 3).
        """
        draw_days = (0, 3)
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in draw_days:
            candidate += timedelta(days=1)
        return candidate

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo REAL registrado en la BD (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, sorteo
                    FROM resultados_eurodreams
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
            df_rec = self.extraer_recientes()
            if not df_rec.empty:
                d = df_rec.iloc[0]
                return {
                    "concurso": None,
                    "fecha": str(d.get("fecha")),
                    "sorteo": str(d.get("sorteo", "EuroDreams")),
                    "balotas": [int(d["balota1"]), int(d["balota2"]), int(d["balota3"]), int(d["balota4"]), int(d["balota5"]), int(d["balota6"])],
                    "sueno": int(d.get("balotaroja")),
                    "df_rec": df_rec
                }
        except Exception as e:
            print(f"⚠️ Error extrayendo último sorteo de la fuente EuroDreams: {e}")
        return None

    def extraer_recientes(self) -> pd.DataFrame:
        """Extrae los últimos resultados disponibles desde combinacionganadora."""
        print(f"➡️ Solicitando resultados recientes de EuroDreams desde {self.url_recientes}...")
        try:
            r = requests.get(self.url_recientes, headers=self.headers, timeout=10)
            if r.status_code != 200:
                print(f"⚠️ Error al acceder a recientes: Status {r.status_code}")
                return pd.DataFrame()

            s = BeautifulSoup(r.text, "html.parser")
            blocks = s.find_all("div", class_="gameSummaryBlock")
            draws = []
            for b in blocks:
                date_span = b.find("span", class_=re.compile(r'fdEurodreams|fontSize', re.I))
                if not date_span:
                    continue
                date_txt = date_span.get_text(strip=True)
                m = re.search(r'(\d{1,2})\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+(\d{4})', date_txt)
                if not m:
                    continue
                day, mon_str, yr = m.groups()
                mon_num = self.meses.get(mon_str.lower().strip())
                if not mon_num:
                    continue
                fecha_str = f"{yr}-{mon_num}-{day.zfill(2)}"

                ul = b.find("ul", class_=re.compile(r'numbers', re.I))
                if not ul:
                    continue
                lis = ul.find_all("li")
                if len(lis) < 7:
                    continue

                nums = []
                for li in lis[:6]:
                    t = li.get_text(strip=True)
                    if t.isdigit():
                        nums.append(int(t))

                dream_m = re.search(r'(\d+)', lis[6].get_text(strip=True))
                dream = int(dream_m.group(1)) if dream_m else None

                if len(nums) == 6 and dream is not None:
                    draws.append({
                        "sorteo": "EuroDreams",
                        "fecha": fecha_str,
                        "balota1": nums[0],
                        "balota2": nums[1],
                        "balota3": nums[2],
                        "balota4": nums[3],
                        "balota5": nums[4],
                        "balota6": nums[5],
                        "balotaroja": dream
                    })

            return pd.DataFrame(draws)
        except Exception as e:
            print(f"❌ Error extrayendo recientes de EuroDreams: {e}")
            return pd.DataFrame()

    def extraer_historico_completo(self) -> pd.DataFrame:
        """
        Descarga todo el histórico de EuroDreams desde su sorteo inaugural (06/11/2023)
        mediante concurrencia multihilo.
        """
        print("📚 Iniciando extracción histórica completa de EuroDreams desde 2023...")
        start_date = datetime(2023, 11, 6).date()
        end_date = datetime.now().date()

        draw_dates = []
        curr = start_date
        while curr <= end_date:
            if curr.weekday() in (0, 3): # Lunes y Jueves
                draw_dates.append(curr.strftime("%Y-%m-%d"))
            curr += timedelta(days=1)

        print(f"⏳ Consultando {len(draw_dates)} fechas de sorteos históricos...")

        def _fetch_single_draw(date_str):
            url = f"https://www.combinacionganadora.com/eurodreams/resultados/{date_str}/"
            try:
                r = requests.get(url, headers=self.headers, timeout=8)
                if r.status_code == 200:
                    s = BeautifulSoup(r.text, "html.parser")
                    ul = s.find("ul", class_=re.compile(r'numbers|sexy', re.I))
                    if ul:
                        lis = ul.find_all("li")
                        if len(lis) >= 7:
                            nums = [int(li.get_text(strip=True)) for li in lis[:6] if li.get_text(strip=True).isdigit()]
                            dream_m = re.search(r'(\d+)', lis[6].get_text(strip=True))
                            dream = int(dream_m.group(1)) if dream_m else None
                            if len(nums) == 6 and dream is not None:
                                return {
                                    "sorteo": "EuroDreams",
                                    "fecha": date_str,
                                    "balota1": nums[0],
                                    "balota2": nums[1],
                                    "balota3": nums[2],
                                    "balota4": nums[3],
                                    "balota5": nums[4],
                                    "balota6": nums[5],
                                    "balotaroja": dream
                                }
            except Exception:
                pass
            return None

        results = []
        with ThreadPoolExecutor(max_workers=15) as executor:
            futures = {executor.submit(_fetch_single_draw, d): d for d in draw_dates}
            for f in as_completed(futures):
                res = f.result()
                if res:
                    results.append(res)

        df = pd.DataFrame(results)
        print(f"📊 Total sorteos históricos extraídos para EuroDreams: {len(df)}")
        return df

    def actualizar_jackpot(self, proxima_fecha: str):
        """Actualiza el premio de EuroDreams en la tabla loterias_jackpots."""
        jackpot_str = "20.000 €/mes durante 30 años"
        print(f"💰 Actualizando jackpot para eurodreams: {jackpot_str} (Fecha: {proxima_fecha})")
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
                    "loteria": "eurodreams",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_str
                })
                
                # Cleanup older than 5 days
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = 'eurodreams' AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """))
                conn.commit()
        except Exception as e:
            print(f"❌ Error actualizando jackpot para eurodreams en BD: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de EuroDreams...")

        # 1. Detección temprana: comparar último sorteo real en BD vs fuente
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and ultimo_db and ultimo_fuente:
            fecha_db = str(ultimo_db.get("fecha"))
            fecha_fuente = str(ultimo_fuente.get("fecha"))

            if fecha_fuente and fecha_db and fecha_fuente <= fecha_db:
                print(f"ℹ️ Detección temprana: No hay sorteo nuevo para EuroDreams.")
                print(f"   BD: {fecha_db} vs Fuente: {fecha_fuente}")

                try:
                    f_dt = datetime.strptime(fecha_db, "%Y-%m-%d").date()
                except Exception:
                    f_dt = fecha_db
                cur_date = self._calcular_proximo_sorteo(f_dt)
                c_num = ultimo_db.get("concurso")
                prox_c = (c_num + 1) if c_num else None

                self.actualizar_jackpot(cur_date.strftime("%Y-%m-%d"))

                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"{fecha_db} (#{c_num})" if c_num else f"{fecha_db}",
                    "proximo_esperado": f"{cur_date.strftime('%d/%m/%Y')} (#{prox_c})" if prox_c else f"{cur_date.strftime('%d/%m/%Y')}"
                }

        # 2. Leer registros existentes
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                res = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'resultados_eurodreams';")).scalar()
                if res > 0:
                    df_existente = pd.read_sql(text("SELECT * FROM resultados_eurodreams WHERE balota1 > 0;"), conn)
                    print(f"📦 Registros históricos existentes en BD: {len(df_existente)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        # 3. Scrapear recientes o histórico
        if backfill or len(df_existente) < 10:
            df_scraped = self.extraer_historico_completo()
        else:
            if ultimo_fuente and "df_rec" in ultimo_fuente:
                df_scraped = ultimo_fuente["df_rec"]
            else:
                df_scraped = self.extraer_recientes()

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de EuroDreams.")
            return False

        # 4. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_scraped, df_existente], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values('fecha', ascending=True).reset_index(drop=True)

        # Filtrar fechas futuras accidentales
        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        # Asignar concurso secuencial (desde fecha inaugural 2023-11-06)
        df_combined['concurso'] = range(1, len(df_combined) + 1)

        # 5. Calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[-1]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        prox_concurso = int(df_combined['concurso'].max()) + 1
        print(f"📅 Fecha del próximo sorteo agregada para EuroDreams: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": "EuroDreams",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balota6": 0,
            "balotaroja": 0
        }

        if backfill:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_combined.sort_values('fecha', ascending=False)], ignore_index=True)
        else:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_scraped], ignore_index=True)
            df_to_save = df_to_save.drop_duplicates(subset=['fecha', 'sorteo'], keep='first')

        # 6. Guardar en Base de Datos vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_eurodreams (
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
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_eurodreams_fecha_sorteo ON resultados_eurodreams (fecha, sorteo);
            """))

        # Eliminar posibles placeholders obsoletos anteriores a proxima_fecha
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_eurodreams
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": proxima_fecha})

        insert_sql = """
            INSERT INTO resultados_eurodreams (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balota6,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_eurodreams.concurso),
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

        records = []
        for _, row in df_to_save.iterrows():
            c_val = int(row['concurso']) if pd.notnull(row.get('concurso')) and row.get('concurso') is not None else None
            f_val = row['fecha'] if isinstance(row['fecha'], date) else pd.to_datetime(row['fecha']).date()
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
                int(row['balota6']),
                int(row.get('balotaroja', 0)),
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
            print(f"✅ Resultados de EuroDreams guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        self.actualizar_jackpot(proxima_fecha_str)

        return {
            "hubo_sorteo": True,
            "ultimo_sorteo": f"{ultima_fecha_real.strftime('%d/%m/%Y')}" if hasattr(ultima_fecha_real, 'strftime') else str(ultima_fecha_real),
            "proximo_esperado": f"{proxima_fecha.strftime('%d/%m/%Y')} (#{prox_concurso})"
        }

if __name__ == "__main__":
    scraper = EuroDreamsScraper()
    scraper.run(backfill=False)
