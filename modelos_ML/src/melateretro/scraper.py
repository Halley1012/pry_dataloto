import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import io
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class MelateRetroScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 17
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-MX,es;q=0.9,en;q=0.8",
        }
        self.url_csv = "https://www.pronosticos.gob.mx/Documentos/Historicos/Melate-Retro.csv"
        self.url_web = "https://www.loterianacional.gob.mx/MelateRetro/Resultados"

    def _parse_fecha(self, text_raw: str) -> str:
        """Parsea fechas en formato 'DD/MM/YYYY' o 'YYYY-MM-DD' a 'YYYY-MM-DD'."""
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
        Los sorteos de Melate Retro se realizan los Martes (1) y Sábados (5).
        """
        draw_days = (1, 5)
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_csv(self) -> tuple[pd.DataFrame, str]:
        """Descarga el archivo histórico oficial CSV con todos los sorteos de Melate Retro."""
        print(f"➡️ Descargando histórico oficial CSV de Melate Retro desde {self.url_csv}...")
        jackpot_destacado = "$17,500,000 MXN"
        
        try:
            r = requests.get(self.url_csv, headers=self.headers, timeout=15, verify=False)
            if r.status_code == 200 and len(r.text) > 1000:
                df_raw = pd.read_csv(io.StringIO(r.text))
                
                # Columnas esperadas: ['NPRODUCTO', 'CONCURSO', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'BOLSA', 'FECHA']
                # o R1..R7
                f_cols = ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7'] if 'F1' in df_raw.columns else ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7']
                draws = []
                
                if 'BOLSA' in df_raw.columns and not df_raw.empty:
                    ult_bolsa = df_raw.iloc[0]['BOLSA']
                    if pd.notna(ult_bolsa) and ult_bolsa > 0:
                        jackpot_destacado = f"${int(ult_bolsa):,} MXN"

                for _, row in df_raw.iterrows():
                    fecha_str = self._parse_fecha(str(row.get('FECHA', '')))
                    if fecha_str:
                        try:
                            r1 = int(row[f_cols[0]])
                            r2 = int(row[f_cols[1]])
                            r3 = int(row[f_cols[2]])
                            r4 = int(row[f_cols[3]])
                            r5 = int(row[f_cols[4]])
                            r6 = int(row[f_cols[5]])
                            r7 = int(row[f_cols[6]]) # Adicional
                            c_num = int(row['CONCURSO']) if pd.notna(row.get('CONCURSO')) else None
                            balls = sorted([r1, r2, r3, r4, r5, r6])
                            draws.append({
                                "concurso": c_num,
                                "loteria_id": self.loteria_id,
                                "sorteo": "Melate Retro",
                                "fecha": fecha_str,
                                "balota1": balls[0],
                                "balota2": balls[1],
                                "balota3": balls[2],
                                "balota4": balls[3],
                                "balota5": balls[4],
                                "balota6": balls[5],
                                "balotaroja": r7
                            })
                        except Exception:
                            continue

                df = pd.DataFrame(draws)
                print(f"📊 Sorteos procesados desde CSV oficial de Melate Retro: {len(df)}")
                return df, jackpot_destacado
        except Exception as e:
            print(f"⚠️ Error al descargar CSV de Melate Retro: {e}")

        return pd.DataFrame(), jackpot_destacado

    def extraer_recientes_web(self) -> tuple[pd.DataFrame, str]:
        """Extrae sorteos recientes de la página web de Melate Retro."""
        print(f"➡️ Solicitando resultados web recientes de Melate Retro desde {self.url_web}...")
        draws = []
        jackpot_destacado = "$17,500,000 MXN"
        
        try:
            r = requests.get(self.url_web, headers=self.headers, timeout=12, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                tables = soup.find_all("table")
                
                # Tabla 1 contiene el histórico reciente
                if len(tables) > 1:
                    t1 = tables[1]
                    for row in t1.find_all("tr")[1:]:
                        tds = row.find_all("td")
                        if len(tds) >= 3:
                            c_num = int(tds[0].get_text(strip=True)) if tds[0].get_text(strip=True).isdigit() else None
                            fecha_str = self._parse_fecha(tds[1].get_text(strip=True))
                            comb = tds[2].get_text(strip=True)
                            # Formato esperado: "02 07 15 21 26 37-31"
                            parts = comb.split('-')
                            if len(parts) == 2 and fecha_str:
                                nat_str = parts[0].strip().split()
                                add_str = parts[1].strip()
                                if len(nat_str) == 6 and add_str.isdigit():
                                    balls = sorted([int(n) for n in nat_str])
                                    draws.append({
                                        "concurso": c_num,
                                        "loteria_id": self.loteria_id,
                                        "sorteo": "Melate Retro",
                                        "fecha": fecha_str,
                                        "balota1": balls[0],
                                        "balota2": balls[1],
                                        "balota3": balls[2],
                                        "balota4": balls[3],
                                        "balota5": balls[4],
                                        "balota6": balls[5],
                                        "balotaroja": int(add_str)
                                    })
        except Exception as e:
            print(f"⚠️ Error en scraping web de Melate Retro: {e}")

        return pd.DataFrame(draws), jackpot_destacado

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el premio de Melate Retro en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "$17,500,000 MXN"
        print(f"💰 Actualizando jackpot para Melate Retro: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "melateretro",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Melate Retro: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Melate Retro (México)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_melateretro WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar datos
        df_web, jp_web = self.extraer_recientes_web()
        
        if backfill or df_existente.empty or len(df_existente) < 100:
            df_csv, jp_csv = self.extraer_csv()
            df_scraped = pd.concat([df_web, df_csv], ignore_index=True)
            jackpot_final = jp_csv if jp_csv else jp_web
        else:
            df_scraped = df_web
            jackpot_final = jp_web

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Melate Retro.")
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
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo agregada para Melate Retro: {proxima_fecha_str}")

        max_concurso = df_combined['concurso'].dropna().max()
        prox_concurso = int(max_concurso) + 1 if pd.notna(max_concurso) else None

        # Fila placeholder en ceros
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": "Melate Retro",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balota6": 0,
            "balotaroja": 0
        }
        df_final = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 5. Guardar en PostgreSQL (UPSERT seguro sin destruir la tabla)
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_melateretro (
                    id SERIAL PRIMARY KEY,
                    concurso INTEGER,
                    loteria_id INTEGER DEFAULT 17 REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INTEGER NOT NULL,
                    balota2 INTEGER NOT NULL,
                    balota3 INTEGER NOT NULL,
                    balota4 INTEGER NOT NULL,
                    balota5 INTEGER NOT NULL,
                    balota6 INTEGER NOT NULL,
                    balotaroja INTEGER NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_melateretro_fecha_sorteo ON resultados_melateretro (fecha, sorteo);
                CREATE INDEX IF NOT EXISTS idx_melateretro_concurso ON resultados_melateretro (concurso);
                CREATE INDEX IF NOT EXISTS idx_melateretro_loteria_id ON resultados_melateretro (loteria_id);
            """))

        insert_sql = """
            INSERT INTO resultados_melateretro (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balota6, balotaroja,
                created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo) DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_melateretro.concurso),
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
                        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ Resultados de Melate Retro guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_final)
        return True

if __name__ == "__main__":
    scraper = MelateRetroScraper()
    scraper.run(backfill=True)
