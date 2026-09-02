import sys
import re
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class MegaSenaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/html, */*",
        }
        self.url_caixa = "https://servicebus2.caixa.gov.br/portaldeloterias/api/megasena"
        self.url_megasena_com = "https://www.megasena.com/es/resultados"
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12',
            'janeiro': '01', 'fevereiro': '02', 'março': '03', 'marco': '03',
            'abril': '04', 'maio': '05', 'junho': '06', 'julho': '07',
            'agosto': '08', 'setembro': '09', 'outubro': '10', 'novembro': '11', 'dezembro': '12'
        }

    def _parse_fecha(self, text_raw: str) -> str:
        """Parsea fechas en formato '23 de agosto de 2026' o '23/08/2026' a 'YYYY-MM-DD'."""
        if not text_raw:
            return None
        text_clean = text_raw.strip()
        
        # Formato 'DD/MM/YYYY'
        m_slash = re.search(r'(\d{1,2})/(\d{1,2})/(\d{4})', text_clean)
        if m_slash:
            day, mon_num, yr = m_slash.groups()
            return f"{yr}-{mon_num.zfill(2)}-{day.zfill(2)}"
            
        # Formato '23 de agosto de 2026'
        m = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚçÇ]+)\s+de\s+(\d{4})', text_clean, re.I)
        if m:
            day, mon_str, yr = m.groups()
            mon_num = self.meses.get(mon_str.lower().strip())
            if mon_num:
                return f"{yr}-{mon_num}-{day.zfill(2)}"
                
        return None

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """
        Los sorteos de Mega-Sena se realizan habitualmente los Martes (1), Jueves (3) y Sábados (5).
        """
        draw_days = (1, 3, 5)
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_recientes(self) -> tuple[pd.DataFrame, str, str]:
        """Extrae el sorteo más reciente desde la API oficial de Caixa y megasena.com."""
        print(f"➡️ Solicitando resultados recientes de Mega-Sena...")
        draws = []
        jackpot_destacado = "R$ 35.000.000"
        proxima_fecha_oficial = None

        # 1. Consultar API oficial de Caixa
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=10)
            if r.status_code == 200:
                data = r.json()
                fecha_raw = data.get("dataApuracao")
                dezenas = data.get("listaDezenas")
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
                    draws.append({
                        "sorteo": "Mega-Sena",
                        "fecha": fecha_str,
                        "balota1": balls[0],
                        "balota2": balls[1],
                        "balota3": balls[2],
                        "balota4": balls[3],
                        "balota5": balls[4],
                        "balota6": balls[5]
                    })
                    print(f"✅ Último sorteo de Caixa obtenido: Concurso {data.get('numero')} ({fecha_str}) -> {balls}")
        except Exception as e:
            print(f"⚠️ Error consultando API Caixa: {e}")

        # 2. Consultar megasena.com para sorteos recientes adicionales
        try:
            r = requests.get(self.url_megasena_com, headers=self.headers, timeout=10)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                tables = soup.find_all("table", class_="_results")
                if len(tables) > 1:
                    for row in tables[1].find_all("tr"):
                        tds = row.find_all("td")
                        if len(tds) >= 3:
                            date_div = tds[0].find("div", class_="date")
                            date_raw = date_div.get_text(strip=True) if date_div else tds[0].get_text(strip=True)
                            fecha_str = self._parse_fecha(date_raw)
                            balls = [int(b.get_text(strip=True)) for b in tds[1].find_all(['li', 'span', 'div']) if b.get_text(strip=True).isdigit()]
                            if len(balls) == 6 and fecha_str:
                                balls = sorted(balls)
                                draws.append({
                                    "sorteo": "Mega-Sena",
                                    "fecha": fecha_str,
                                    "balota1": balls[0],
                                    "balota2": balls[1],
                                    "balota3": balls[2],
                                    "balota4": balls[3],
                                    "balota5": balls[4],
                                    "balota6": balls[5]
                                })
        except Exception as e:
            print(f"ℹ️ megasena.com scraping info: {e}")

        df = pd.DataFrame(draws)
        if not df.empty:
            df = df.drop_duplicates(subset=['fecha']).reset_index(drop=True)
        print(f"📊 Total sorteos recientes extraídos para Mega-Sena: {len(df)}")
        return df, jackpot_destacado, proxima_fecha_oficial

    def extraer_historico_completo(self, total_sorteos: int = 800) -> pd.DataFrame:
        """
        Descarga cientos de sorteos históricos mediante la API oficial de Caixa con alta concurrencia.
        """
        print("📚 Iniciando extracción histórica completa de Mega-Sena...")
        
        # 1. Obtener el número de sorteo más reciente
        ultimo_sorteo_num = 3048
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=8)
            if r.status_code == 200:
                data = r.json()
                ultimo_sorteo_num = int(data.get("numero", 3048))
        except Exception:
            pass

        primer_sorteo = max(1, ultimo_sorteo_num - total_sorteos)
        sorteos_a_consultar = list(range(primer_sorteo, ultimo_sorteo_num + 1))
        print(f"⏳ Descargando {len(sorteos_a_consultar)} sorteos históricos (del {primer_sorteo} al {ultimo_sorteo_num})...")

        def _fetch_single_sorteo(num: int):
            url = f"https://servicebus2.caixa.gov.br/portaldeloterias/api/megasena/{num}"
            try:
                r = requests.get(url, headers=self.headers, timeout=5)
                if r.status_code == 200:
                    d = r.json()
                    fecha_raw = d.get("dataApuracao")
                    dezenas = d.get("listaDezenas")
                    fecha_str = self._parse_fecha(fecha_raw)
                    if dezenas and len(dezenas) == 6 and fecha_str:
                        balls = sorted([int(x) for x in dezenas])
                        return {
                            "sorteo": "Mega-Sena",
                            "fecha": fecha_str,
                            "balota1": balls[0],
                            "balota2": balls[1],
                            "balota3": balls[2],
                            "balota4": balls[3],
                            "balota5": balls[4],
                            "balota6": balls[5]
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
        """Actualiza el premio de Mega-Sena en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "R$ 35.000.000"
        print(f"💰 Actualizando jackpot para Mega-Sena: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "megasena",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Mega-Sena: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Mega-Sena (Brasil)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_megasena WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar datos
        df_recientes, jackpot_reciente, prox_fecha_oficial = self.extraer_recientes()
        if backfill or df_existente.empty or len(df_existente) < 50:
            df_historico = self.extraer_historico_completo(total_sorteos=800)
            df_scraped = pd.concat([df_recientes, df_historico], ignore_index=True)
        else:
            df_scraped = df_recientes

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Mega-Sena.")
            return

        # 3. Combinar y limpiar
        if not df_existente.empty:
            df_combined = pd.concat([df_existente, df_scraped], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values('fecha', ascending=False).reset_index(drop=True)

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
        print(f"📅 Fecha del próximo sorteo agregada para Mega-Sena: {proxima_fecha_str}")

        # Fila placeholder en ceros
        fila_proximo = {
            "sorteo": "Mega-Sena",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balota6": 0
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
            'balota6': Integer()
        }

        with self.engine.connect() as conn:

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_megasena")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_megasena', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.commit()

        print(f"✅ Resultados de Mega-Sena guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_reciente)

if __name__ == "__main__":
    scraper = MegaSenaScraper()
    scraper.run(backfill=True)
