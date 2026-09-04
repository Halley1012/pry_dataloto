import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import pandas as pd
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from concurrent.futures import ThreadPoolExecutor, as_completed
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class MaisMilionariaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 30
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/html, */*",
        }
        self.url_caixa = "https://servicebus2.caixa.gov.br/portaldeloterias/api/maismilionaria"
        self.url_api_backup = "https://loteriascaixa-api.herokuapp.com/api/maismilionaria/latest"

    def _parse_fecha(self, text_raw: str) -> str:
        """Parsea fechas en formato 'DD/MM/YYYY' o 'YYYY-MM-DD'."""
        if not text_raw:
            return None
        text_clean = text_raw.strip()
        
        m_slash = re.search(r'(\d{1,2})/(\d{1,2})/(\d{4})', text_clean)
        if m_slash:
            day, mon_num, yr = m_slash.groups()
            return f"{yr}-{mon_num.zfill(2)}-{day.zfill(2)}"
            
        m_iso = re.search(r'(\d{4})-(\d{1,2})-(\d{1,2})', text_clean)
        if m_iso:
            yr, mon_num, day = m_iso.groups()
            return f"{yr}-{mon_num.zfill(2)}-{day.zfill(2)}"
            
        return None

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """
        Los sorteos de +Milionária se realizan los Miércoles (2) y Sábados (5).
        """
        draw_days = (2, 5)
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_recientes(self) -> tuple[pd.DataFrame, str, str]:
        """Extrae el último sorteo de +Milionária."""
        print(f"➡️ Solicitando resultados recientes de +Milionária...")
        draws = []
        jackpot_destacado = "R$ 80.000.000"
        proxima_fecha_oficial = None

        # 1. Consultar API oficial de Caixa
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=10)
            if r.status_code == 200:
                data = r.json()
                fecha_raw = data.get("dataApuracao")
                dezenas = data.get("listaDezenas")
                trevos = data.get("trevosSorteados")
                prox_raw = data.get("dataProximoConcurso")
                jackpot_val = data.get("valorEstimadoProximoConcurso")
                
                fecha_str = self._parse_fecha(fecha_raw)
                if prox_raw:
                    proxima_fecha_oficial = self._parse_fecha(prox_raw)
                
                if jackpot_val:
                    try:
                        jackpot_destacado = f"R$ {jackpot_val:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
                    except Exception:
                        pass

                if dezenas and len(dezenas) == 6 and fecha_str:
                    balls = sorted([int(d) for d in dezenas])
                    trevos_ints = sorted([int(t) for t in trevos]) if trevos and len(trevos) >= 2 else [1, 2]
                    draws.append({
                        "concurso": int(data.get("numero")) if data.get("numero") else None,
                        "loteria_id": self.loteria_id,
                        "sorteo": "+Milionária",
                        "fecha": fecha_str,
                        "balota1": balls[0],
                        "balota2": balls[1],
                        "balota3": balls[2],
                        "balota4": balls[3],
                        "balota5": balls[4],
                        "balota6": balls[5],
                        "balotaroja": trevos_ints[0],
                        "balotaroja2": trevos_ints[1]
                    })
                    print(f"✅ Último sorteo obtenido: Concurso {data.get('numero')} ({fecha_str}) -> Números: {balls}, Tréboles: {trevos_ints}")
        except Exception as e:
            print(f"⚠️ Error consultando API Caixa: {e}")

        # 2. Fallback a API secundaria si es necesario
        if not draws:
            try:
                r = requests.get(self.url_api_backup, headers=self.headers, timeout=10)
                if r.status_code == 200:
                    d = r.json()
                    fecha_str = self._parse_fecha(d.get("data"))
                    dezenas = d.get("dezenas")
                    trevos = d.get("trevos")
                    if dezenas and len(dezenas) == 6 and fecha_str:
                        balls = sorted([int(x) for x in dezenas])
                        trevos_ints = sorted([int(t) for t in trevos]) if trevos and len(trevos) >= 2 else [1, 2]
                        draws.append({
                            "concurso": int(d.get("numero")) if d.get("numero") else None,
                            "loteria_id": self.loteria_id,
                            "sorteo": "+Milionária",
                            "fecha": fecha_str,
                            "balota1": balls[0],
                            "balota2": balls[1],
                            "balota3": balls[2],
                            "balota4": balls[3],
                            "balota5": balls[4],
                            "balota6": balls[5],
                            "balotaroja": trevos_ints[0],
                            "balotaroja2": trevos_ints[1]
                        })
            except Exception as e:
                print(f"⚠️ Error en API secundaria: {e}")

        df = pd.DataFrame(draws)
        return df, jackpot_destacado, proxima_fecha_oficial

    def extraer_historico_completo(self) -> pd.DataFrame:
        """
        Descarga todos los sorteos históricos de +Milionária (desde el concurso 1).
        """
        print("📚 Iniciando extracción histórica completa de +Milionária...")
        
        ultimo_sorteo_num = 383
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=8)
            if r.status_code == 200:
                data = r.json()
                ultimo_sorteo_num = int(data.get("numero", 383))
        except Exception:
            pass

        sorteos_a_consultar = list(range(1, ultimo_sorteo_num + 1))
        print(f"⏳ Descargando {len(sorteos_a_consultar)} sorteos históricos (del 1 al {ultimo_sorteo_num})...")

        def _fetch_single_sorteo(num: int):
            url = f"https://servicebus2.caixa.gov.br/portaldeloterias/api/maismilionaria/{num}"
            try:
                r = requests.get(url, headers=self.headers, timeout=5)
                if r.status_code == 200:
                    d = r.json()
                    fecha_raw = d.get("dataApuracao")
                    dezenas = d.get("listaDezenas")
                    trevos = d.get("trevosSorteados")
                    fecha_str = self._parse_fecha(fecha_raw)
                    if dezenas and len(dezenas) == 6 and fecha_str:
                        balls = sorted([int(x) for x in dezenas])
                        trevos_ints = sorted([int(t) for t in trevos]) if trevos and len(trevos) >= 2 else [1, 2]
                        return {
                            "concurso": num,
                            "loteria_id": self.loteria_id,
                            "sorteo": "+Milionária",
                            "fecha": fecha_str,
                            "balota1": balls[0],
                            "balota2": balls[1],
                            "balota3": balls[2],
                            "balota4": balls[3],
                            "balota5": balls[4],
                            "balota6": balls[5],
                            "balotaroja": trevos_ints[0],
                            "balotaroja2": trevos_ints[1]
                        }
            except Exception:
                pass
            return None

        results = []
        with ThreadPoolExecutor(max_workers=25) as executor:
            futures = {executor.submit(_fetch_single_sorteo, num): num for num in sorteos_a_consultar}
            for f in as_completed(futures):
                res = f.result()
                if res:
                    results.append(res)

        df = pd.DataFrame(results)
        print(f"📊 Total sorteos históricos extraídos con éxito: {len(df)}")
        return df

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el premio de +Milionária en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "R$ 80.000.000,00"
        print(f"💰 Actualizando jackpot para +Milionária: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "maismilionaria",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para +Milionária: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de +Milionária (Brasil)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_maismilionaria WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar datos
        df_recientes, jackpot_reciente, prox_fecha_oficial = self.extraer_recientes()
        if backfill or df_existente.empty or len(df_existente) < 50:
            df_historico = self.extraer_historico_completo()
            df_scraped = pd.concat([df_recientes, df_historico], ignore_index=True)
        else:
            df_scraped = df_recientes

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de +Milionária.")
            return

        # 3. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_scraped, df_existente], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo'], keep='first').sort_values('fecha', ascending=False).reset_index(drop=True)

        # Filtrar fechas futuras accidentales
        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return

        # 4. Calcular próximo sorteo
        if prox_fecha_oficial and datetime.strptime(prox_fecha_oficial, "%Y-%m-%d").date() > df_combined.iloc[0]['fecha']:
            proxima_fecha = datetime.strptime(prox_fecha_oficial, "%Y-%m-%d").date()
        else:
            ultima_fecha_real = df_combined.iloc[0]['fecha']
            proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
            
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo agregada para +Milionária: {proxima_fecha_str}")

        max_concurso = df_combined['concurso'].dropna().max()
        prox_concurso = int(max_concurso) + 1 if pd.notna(max_concurso) else None

        # Fila placeholder en ceros
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": "+Milionária",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balota6": 0,
            "balotaroja": 0,
            "balotaroja2": 0
        }
        df_final = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 5. Guardar en PostgreSQL (UPSERT seguro sin destruir la tabla)
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_maismilionaria (
                    id SERIAL PRIMARY KEY,
                    concurso INTEGER,
                    loteria_id INTEGER DEFAULT 30 REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INTEGER NOT NULL,
                    balota2 INTEGER NOT NULL,
                    balota3 INTEGER NOT NULL,
                    balota4 INTEGER NOT NULL,
                    balota5 INTEGER NOT NULL,
                    balota6 INTEGER NOT NULL,
                    balotaroja INTEGER NOT NULL,
                    balotaroja2 INTEGER NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_maismilionaria_fecha_sorteo ON resultados_maismilionaria (fecha, sorteo);
                CREATE INDEX IF NOT EXISTS idx_maismilionaria_concurso ON resultados_maismilionaria (concurso);
                CREATE INDEX IF NOT EXISTS idx_maismilionaria_loteria_id ON resultados_maismilionaria (loteria_id);
            """))

        insert_sql = """
            INSERT INTO resultados_maismilionaria (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balota6,
                balotaroja, balotaroja2,
                created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo) DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_maismilionaria.concurso),
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
                        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ Resultados de +Milionária guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_reciente)
        return True

if __name__ == "__main__":
    scraper = MaisMilionariaScraper()
    scraper.run(backfill=True)
