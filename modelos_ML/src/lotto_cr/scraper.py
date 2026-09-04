import sys
import re
import requests
import pandas as pd
import concurrent.futures
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class LottoCostaRicaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 35
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-CR,es;q=0.9,en;q=0.8",
        }
        self.base_url = "https://www.combinacionganadora.com/cr/lotto-costa-rica/resultados"

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Sorteos de Lotto Costa Rica: Lunes (0), Miércoles (2) y Sábados (5)."""
        dias_validos = {0, 2, 5}
        hoy = datetime.now().date()
        base = max(ultima_fecha_real, hoy)
        
        if hoy.weekday() in dias_validos and ultima_fecha_real < hoy:
            return hoy
            
        candidate = base + timedelta(days=1)
        while candidate.weekday() not in dias_validos or candidate <= ultima_fecha_real:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_estimado(self) -> str:
        """Extrae el pozo acumulado para el próximo sorteo en Colones (CRC)."""
        print("➡️ Consultando pozo estimado de Lotto Costa Rica...")
        try:
            r = requests.get("https://www.combinacionganadora.com/cr/lotto-costa-rica/", headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                for tag in soup.find_all(["div", "span", "p", "h1", "h2", "h3"]):
                    txt = tag.get_text(strip=True)
                    if any(k in txt.lower() for k in ["bote", "acumulado", "pozo", "premio", "estimado"]) and ("₡" in txt or "CRC" in txt or "millones" in txt.lower()):
                        m = re.search(r'([0-9\',.]+)\s*(?:millones|₡|CRC)', txt, re.IGNORECASE)
                        if m:
                            val = m.group(1).replace("'", ",").replace(" ", "")
                            if "millon" in txt.lower():
                                return f"₡ {val} millones"
                            return f"₡ {val}"
        except Exception as e:
            print(f"⚠️ Error consultando pozo de Lotto CR: {e}")

        return "₡ 125.000.000"

    def _parsear_sorteo_fecha(self, fecha_str: str) -> list:
        """Descarga y parsea el sorteo de una fecha retornando filas para Lotto y Revancha."""
        url = f"{self.base_url}/{fecha_str}/"
        try:
            r = requests.get(url, headers=self.headers, timeout=6, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                uls = soup.find_all("ul", class_=re.compile(r"numbers"))
                if len(uls) >= 1:
                    # Primer UL: Lotto (5 números)
                    lotto_items = [int(re.search(r'\d+', li.get_text(strip=True)).group(0)) for li in uls[0].find_all("li") if re.search(r'\d+', li.get_text(strip=True))]
                    
                    # Segundo UL: Revancha (5 números)
                    rev_items = []
                    if len(uls) >= 2:
                        rev_items = [int(re.search(r'\d+', li.get_text(strip=True)).group(0)) for li in uls[1].find_all("li") if re.search(r'\d+', li.get_text(strip=True))]

                    items = []
                    if len(lotto_items) == 5:
                        lotto_sorted = sorted(lotto_items)
                        items.append({
                            "sorteo": "Lotto",
                            "fecha": fecha_str,
                            "balota1": lotto_sorted[0],
                            "balota2": lotto_sorted[1],
                            "balota3": lotto_sorted[2],
                            "balota4": lotto_sorted[3],
                            "balota5": lotto_sorted[4],
                            "balotaroja": 0
                        })

                    if len(rev_items) == 5:
                        rev_sorted = sorted(rev_items)
                        items.append({
                            "sorteo": "Revancha",
                            "fecha": fecha_str,
                            "balota1": rev_sorted[0],
                            "balota2": rev_sorted[1],
                            "balota3": rev_sorted[2],
                            "balota4": rev_sorted[3],
                            "balota5": rev_sorted[4],
                            "balotaroja": 0
                        })

                    return items
        except Exception:
            pass
        return []

    def extraer_historico_concurrente(self, max_draws: int = 30) -> pd.DataFrame:
        """Genera fechas pasadas de sorteos válidos y descarga resultados concurrentemente."""
        print(f"📚 Descargando hasta {max_draws} sorteos de Lotto Costa Rica...")
        dias_sorteo = {0, 2, 5}
        fechas_candidatas = []
        cur = datetime.now().date()
        
        while len(fechas_candidatas) < max_draws:
            if cur.weekday() in dias_sorteo:
                fechas_candidatas.append(cur.strftime("%Y-%m-%d"))
            cur -= timedelta(days=1)

        registros = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futuros = {executor.submit(self._parsear_sorteo_fecha, f): f for f in fechas_candidatas}
            for fut in concurrent.futures.as_completed(futuros):
                try:
                    res = fut.result()
                    if res:
                        registros.extend(res)
                except Exception:
                    pass

        if not registros:
            return pd.DataFrame()

        df = pd.DataFrame(registros)
        print(f"📊 Sorteos parseados: {len(df)}")
        return df

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_val: str):
        """Actualiza el acumulado en loterias_jackpots."""
        print(f"💰 Actualizando jackpot de Lotto CR: {jackpot_val} para {proxima_fecha}")
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
                for route_key in ["lotto_cr", "lotto / revancha", "lotto costa rica"]:
                    conn.execute(text("""
                        INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                        VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                        ON CONFLICT (loteria, fecha)
                        DO UPDATE SET jackpot = EXCLUDED.jackpot, updated_at = CURRENT_TIMESTAMP;
                    """), {
                        "loteria": route_key,
                        "fecha": proxima_fecha,
                        "jackpot": jackpot_val
                    })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Lotto CR: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Lotto y Revancha (Costa Rica)...")

        pozo_oficial = self.extraer_pozo_estimado()

        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                res = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'resultados_lotto_cr';")).scalar()
                if res > 0:
                    df_existente = pd.read_sql(text("SELECT * FROM resultados_lotto_cr WHERE balota1 > 0;"), conn)
                    print(f"📦 Registros históricos existentes en BD: {len(df_existente)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        # 2. Descargar histórico concurrente
        if backfill or df_existente.empty or len(df_existente) < 50:
            df_scraped = self.extraer_historico_concurrente(max_draws=350)
        else:
            df_scraped = self.extraer_historico_concurrente(max_draws=30)

        # Combinar existente + histórico (df_scraped primero)
        dfs_to_combine = []
        if not df_scraped.empty:
            dfs_to_combine.append(df_scraped)
        if not df_existente.empty and 'sorteo' in df_existente.columns:
            dfs_to_combine.append(df_existente)

        if not dfs_to_combine:
            print("❌ No se pudieron obtener resultados de Lotto Costa Rica.")
            return

        df_combined = pd.concat(dfs_to_combine, ignore_index=True)
        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo']).sort_values(by=['fecha', 'sorteo'], ascending=[False, True]).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return

        # 3. Determinar fecha del próximo sorteo
        df_real = df_combined[df_combined['balota1'] > 0]
        ultima_fecha_real = df_real.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")

        print(f"📅 Fecha del próximo sorteo establecida para Lotto CR: {proxima_fecha_str}")

        # Filas placeholder en ceros
        filas_proximo = [
            {
                "concurso": None,
                "loteria_id": self.loteria_id,
                "sorteo": "Lotto",
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
        df_final = pd.concat([pd.DataFrame(filas_proximo), df_combined], ignore_index=True)
        df_final = df_final.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values(by=['fecha', 'sorteo'], ascending=[False, True]).reset_index(drop=True)

        # 4. Guardar en PostgreSQL vía UPSERT seguro
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_lotto_cr (
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
                CREATE UNIQUE INDEX IF NOT EXISTS uq_lotto_cr_fecha_sorteo ON resultados_lotto_cr (fecha, sorteo);
            """))

        insert_sql = """
            INSERT INTO resultados_lotto_cr (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_lotto_cr.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                balotaroja = EXCLUDED.balotaroja,
                updated_at = CURRENT_TIMESTAMP;
        """

        records = []
        for _, row in df_final.iterrows():
            c_val = int(row['concurso']) if pd.notnull(row.get('concurso')) and row.get('concurso') is not None else None
            f_val = row['fecha'] if isinstance(row['fecha'], date) else row['fecha'].date()
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
                datetime.now(),
                datetime.now()
            ))

        raw_conn = self.engine.raw_connection()
        try:
            with raw_conn.cursor() as cur:
                execute_values(cur, insert_sql, records, page_size=1000)
            raw_conn.commit()
            print(f"✅ Resultados de Lotto y Revancha CR guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        self.actualizar_jackpot(proxima_fecha_str, pozo_oficial)

if __name__ == "__main__":
    scraper = LottoCostaRicaScraper()
    scraper.run(backfill=False)
