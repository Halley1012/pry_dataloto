import sys
import re
import io
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class ChispazoScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-MX,es;q=0.9,en;q=0.8",
        }
        self.url_csv = "https://www.pronosticos.gob.mx/Documentos/Historicos/Chispazo.csv"
        self.url_web = "https://www.loterianacional.gob.mx/Chispazo/Resultados"

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
        Los sorteos de Chispazo se realizan todos los días (2 veces al día).
        """
        hoy = datetime.now().date()
        if ultima_fecha_real < hoy:
            return hoy
        return ultima_fecha_real + timedelta(days=1)

    def extraer_csv(self) -> tuple[pd.DataFrame, str]:
        """Descarga el archivo histórico oficial CSV con todos los sorteos de Chispazo."""
        print(f"➡️ Descargando histórico oficial CSV de Chispazo desde {self.url_csv}...")
        jackpot_destacado = "$1,500,000 MXN"
        
        try:
            r = requests.get(self.url_csv, headers=self.headers, timeout=15, verify=False)
            if r.status_code == 200 and len(r.text) > 1000:
                df_raw = pd.read_csv(io.StringIO(r.text))
                
                # Columnas esperadas: ['CONCURSO', 'R1', 'R2', 'R3', 'R4', 'R5', 'FECHA']
                draws = []
                for _, row in df_raw.iterrows():
                    fecha_str = self._parse_fecha(str(row.get('FECHA', '')))
                    if fecha_str:
                        try:
                            r1 = int(row['R1'])
                            r2 = int(row['R2'])
                            r3 = int(row['R3'])
                            r4 = int(row['R4'])
                            r5 = int(row['R5'])
                            balls = sorted([r1, r2, r3, r4, r5])
                            draws.append({
                                "sorteo": "Chispazo",
                                "fecha": fecha_str,
                                "balota1": balls[0],
                                "balota2": balls[1],
                                "balota3": balls[2],
                                "balota4": balls[3],
                                "balota5": balls[4],
                                "balotaroja": 0
                            })
                        except Exception:
                            continue

                df = pd.DataFrame(draws)
                print(f"📊 Sorteos procesados desde CSV oficial de Chispazo: {len(df)}")
                return df, jackpot_destacado
        except Exception as e:
            print(f"⚠️ Error al descargar CSV de Chispazo: {e}")

        return pd.DataFrame(), jackpot_destacado

    def extraer_recientes_web(self) -> tuple[pd.DataFrame, str]:
        """Extrae sorteos recientes de la página web de Chispazo."""
        print(f"➡️ Solicitando resultados web recientes de Chispazo desde {self.url_web}...")
        draws = []
        jackpot_destacado = "$1,500,000 MXN"
        
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
                            fecha_str = self._parse_fecha(tds[1].get_text(strip=True))
                            comb = tds[2].get_text(strip=True)
                            # Formato esperado: "09 12 15 17 25"
                            nat_str = comb.strip().split()
                            if len(nat_str) == 5 and fecha_str:
                                balls = sorted([int(n) for n in nat_str if n.isdigit()])
                                if len(balls) == 5:
                                    draws.append({
                                        "sorteo": "Chispazo",
                                        "fecha": fecha_str,
                                        "balota1": balls[0],
                                        "balota2": balls[1],
                                        "balota3": balls[2],
                                        "balota4": balls[3],
                                        "balota5": balls[4],
                                        "balotaroja": 0
                                    })
        except Exception as e:
            print(f"⚠️ Error en scraping web de Chispazo: {e}")

        return pd.DataFrame(draws), jackpot_destacado

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el premio de Chispazo en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "$1,500,000 MXN"
        print(f"💰 Actualizando jackpot para Chispazo: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "chispazo",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Chispazo: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Chispazo (México)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_chispazo WHERE balota1 > 0;"), conn)
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
            print("❌ No se pudieron obtener resultados de Chispazo.")
            return

        # 3. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_existente, df_scraped], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        # Deduplicar preservando todos los sorteos únicos
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'balota1', 'balota2', 'balota3', 'balota4', 'balota5']).sort_values('fecha', ascending=False).reset_index(drop=True)

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
        print(f"📅 Fecha del próximo sorteo agregada para Chispazo: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "sorteo": "Chispazo",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balotaroja": 0
        }
        df_final = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 5. Guardar en PostgreSQL
        dtypes = {
            'sorteo': String(50),
            'fecha': Date(),
            'balota1': Integer(),
            'balota2': Integer(),
            'balota3': Integer(),
            'balota4': Integer(),
            'balota5': Integer(),
            'balotaroja': Integer()
        }

        with self.engine.connect() as conn:

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                import pandas as pd
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_chispazo")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_chispazo', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.commit()

        print(f"✅ Resultados de Chispazo guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_final)

if __name__ == "__main__":
    scraper = ChispazoScraper()
    scraper.run(backfill=True)
