import sys
import re
import time
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from concurrent.futures import ThreadPoolExecutor, as_completed

# Asegurar import de módulos del proyecto
PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine


class ThunderballScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-GB,en;q=0.9,es;q=0.8",
        }
        self.base_url = "https://www.combinacionganadora.com/uk/thunderball/"
        self.resultados_url = "https://www.combinacionganadora.com/uk/thunderball/resultados/"
        self.game_name = "Thunderball"
        self.route = "thunderball"
        # Sorteos de Thunderball: Martes (1), Miércoles (2), Viernes (4) y Sábados (5)
        self.draw_days = (1, 2, 4, 5)

        self.meses = {
            # Español
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12',
            # Inglés
            'january': '01', 'february': '02', 'march': '03', 'april': '04',
            'may': '05', 'june': '06', 'july': '07', 'august': '08',
            'september': '09', 'october': '10', 'november': '11', 'december': '12'
        }

    def _parse_date(self, text_str: str) -> date | None:
        """Extrae la fecha a partir de cadenas como 'Viernes, 11 septiembre 2026' o '11 September 2026'."""
        if not text_str:
            return None
        m = re.search(r'(\d{1,2})\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+(\d{4})', text_str)
        if not m:
            return None
        day, mon_str, yr = m.groups()
        mon_num = self.meses.get(mon_str.lower().strip())
        if not mon_num:
            return None
        try:
            return datetime.strptime(f"{yr}-{mon_num}-{int(day):02d}", "%Y-%m-%d").date()
        except ValueError:
            return None

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        """Calcula el próximo sorteo de Thunderball: Martes (1), Miércoles (2), Viernes (4) o Sábado (5)."""
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in self.draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_y_proximo_sorteo(self) -> tuple[str | None, date | None]:
        """Extrae el bote / premio mayor y la fecha del próximo sorteo desde la página principal."""
        print(f"➡️ Consultando premio mayor y próximo sorteo desde {self.base_url}...")
        jackpot_str = None
        next_draw_date = None

        try:
            r = requests.get(self.base_url, headers=self.headers, timeout=12)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                playarea = soup.find("div", attrs={"data-playarea": True})
                if playarea:
                    txt = playarea.get_text(" ", strip=True)
                    # Extraer fecha: 'Siguiente sorteo: Sábado, 12 septiembre 2026 ...'
                    m_date = re.search(r'Siguiente sorteo:?\s*([a-zA-ZáéíóúÁÉÍÓÚ]+,?\s*\d{1,2}\s+[a-zA-ZáéíóúÁÉÍÓÚ]+\s+\d{4})', txt, re.IGNORECASE)
                    if m_date:
                        next_draw_date = self._parse_date(m_date.group(1))

                # Extraer bote: buscar bloque Bote (ej. Bote 500.000,00 £)
                for tag in soup.find_all(["dl", "div", "p", "span", "h2"]):
                    t = tag.get_text(" ", strip=True)
                    if "bote" in t.lower() and ("£" in t or "500" in t):
                        m_bote = re.search(r'bote\s*([\d\.,]+)\s*£', t, re.IGNORECASE)
                        if m_bote:
                            val = m_bote.group(1).replace(",00", "")
                            jackpot_str = f"{val} £"
                            break

                if not jackpot_str:
                    for tag in soup.find_all(["div", "p", "span"]):
                        t = tag.get_text(" ", strip=True)
                        m_bote = re.search(r'([\d\.,]+)\s*£', t)
                        if m_bote:
                            val = m_bote.group(1).replace(",00", "")
                            jackpot_str = f"{val} £"
                            break

        except Exception as e:
            print(f"⚠️ Error consultando información de próximo sorteo de Thunderball: {e}")

        if not jackpot_str:
            jackpot_str = "500.000 £"  # Premio mayor fijo oficial de Thunderball

        return jackpot_str, next_draw_date

    def extraer_recientes(self) -> pd.DataFrame:
        """Extrae los últimos resultados disponibles desde combinacionganadora.com/uk/thunderball/resultados/"""
        print(f"➡️ Solicitando resultados recientes de Thunderball desde {self.resultados_url}...")
        try:
            r = requests.get(self.resultados_url, headers=self.headers, timeout=12)
            if r.status_code != 200:
                print(f"⚠️ Error al acceder a recientes: Status {r.status_code}")
                return pd.DataFrame()

            soup = BeautifulSoup(r.text, "html.parser")
            blocks = soup.find_all("div", class_="gameSummaryBlock")
            draws = []

            for b in blocks:
                # Extraer fecha
                date_span = b.find("span", class_=re.compile(r'fdThunderball|fontSize', re.I))
                if not date_span:
                    continue
                fecha = self._parse_date(date_span.get_text(strip=True))
                if not fecha:
                    continue

                # Extraer números
                ul = b.find("ul", class_=re.compile(r'numbers', re.I))
                if not ul:
                    continue

                lis = ul.find_all("li")
                if len(lis) < 6:
                    continue

                nums = []
                thunder = None
                for li in lis:
                    txt = li.get_text(strip=True)
                    if txt.upper().startswith("T") or li.get("data-extra") is not None:
                        num_tb = re.search(r'\d+', txt)
                        if num_tb:
                            thunder = int(num_tb.group(0))
                    elif txt.isdigit():
                        nums.append(int(txt))

                if len(nums) == 5 and thunder is not None:
                    nums_sorted = sorted(nums)
                    draws.append({
                        "sorteo": self.game_name,
                        "fecha": fecha,
                        "balota1": nums_sorted[0],
                        "balota2": nums_sorted[1],
                        "balota3": nums_sorted[2],
                        "balota4": nums_sorted[3],
                        "balota5": nums_sorted[4],
                        "balotaroja": thunder
                    })

            df = pd.DataFrame(draws)
            print(f"ℹ️ Encontrados {len(df)} sorteos recientes de Thunderball.")
            return df
        except Exception as e:
            print(f"❌ Error extrayendo recientes de Thunderball: {e}")
            return pd.DataFrame()

    def _parsear_sorteo_fecha(self, fecha_str: str) -> dict | None:
        """Descarga y parsea el sorteo de una fecha específica."""
        url = f"{self.resultados_url}{fecha_str}/"
        try:
            r = requests.get(url, headers=self.headers, timeout=8)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                sorteo_div = soup.find("div", id="sorteo")
                if not sorteo_div:
                    # Alternativa: primer ul.numbers
                    sorteo_div = soup

                ul = sorteo_div.find("ul", class_=re.compile(r'numbers', re.I))
                if not ul:
                    return None

                lis = ul.find_all("li")
                if len(lis) < 6:
                    return None

                nums = []
                thunder = None
                for li in lis:
                    txt = li.get_text(strip=True)
                    if txt.upper().startswith("T") or li.get("data-extra") is not None:
                        num_tb = re.search(r'\d+', txt)
                        if num_tb:
                            thunder = int(num_tb.group(0))
                    elif txt.isdigit():
                        nums.append(int(txt))

                if len(nums) == 5 and thunder is not None:
                    nums_sorted = sorted(nums)
                    return {
                        "sorteo": self.game_name,
                        "fecha": datetime.strptime(fecha_str, "%Y-%m-%d").date(),
                        "balota1": nums_sorted[0],
                        "balota2": nums_sorted[1],
                        "balota3": nums_sorted[2],
                        "balota4": nums_sorted[3],
                        "balota5": nums_sorted[4],
                        "balotaroja": thunder
                    }
        except Exception:
            pass
        return None

    def extraer_historico_concurrente(self, max_draws: int = 150) -> pd.DataFrame:
        """Genera fechas pasadas de sorteos (Mar, Mié, Vie, Sáb) y las descarga concurrentemente."""
        print(f"➡️ Generando fechas de sorteos pasados para Thunderball (máx {max_draws})...")
        fechas = []
        curr = datetime.now().date()
        while len(fechas) < max_draws:
            if curr.weekday() in self.draw_days:
                fechas.append(curr.strftime("%Y-%m-%d"))
            curr -= timedelta(days=1)

        print(f"Descargando {len(fechas)} sorteos históricos de Thunderball con ThreadPoolExecutor...")
        draws = []
        with ThreadPoolExecutor(max_workers=8) as executor:
            futuros = {executor.submit(self._parsear_sorteo_fecha, f): f for f in fechas}
            for fut in as_completed(futuros):
                res = fut.result()
                if res:
                    draws.append(res)

        df = pd.DataFrame(draws)
        print(f"✅ Descargados {len(df)} sorteos históricos de Thunderball.")
        return df

    def actualizar_jackpot(self, proxima_fecha_str: str, jackpot_str: str):
        """Actualiza la tabla loterias_jackpots con el bote del próximo sorteo."""
        if not jackpot_str or not proxima_fecha_str:
            return

        print(f"💰 Actualizando jackpot para {self.route}: {jackpot_str} (Fecha: {proxima_fecha_str})")
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
                    "loteria": self.route,
                    "fecha": proxima_fecha_str,
                    "jackpot": jackpot_str
                })
                # Limpiar jackpots obsoletos de más de 7 días
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '7 days';
                """), {"loteria": self.route})
                conn.commit()
            print("✅ Jackpot de Thunderball actualizado exitosamente.")
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot de Thunderball: {e}")

    def run(self, backfill: bool = False):
        print("==================================================")
        print(f"🚀 Iniciando Scraping de {self.game_name} (UK)...")
        print("==================================================")

        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_thunderball WHERE balota1 > 0;"), conn)
        except Exception as e:
            print(f"ℹ️ Tabla resultados_thunderball aún sin datos o error de lectura: {e}")

        # Si no hay datos o se solicita backfill completo
        if backfill or df_existente.empty or len(df_existente) < 15:
            print(f"📦 Ejecutando descarga de histórico para {self.game_name}...")
            df_nuevos = self.extraer_historico_concurrente(max_draws=150)
        else:
            print(f"🔄 Consultando sorteos recientes de {self.game_name}...")
            df_nuevos = self.extraer_recientes()

        if df_nuevos.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Thunderball.")
            return

        # Unificar
        if not df_existente.empty and not df_nuevos.empty:
            df_combinado = pd.concat([df_existente, df_nuevos], ignore_index=True)
            df_combinado['fecha'] = pd.to_datetime(df_combinado['fecha']).dt.date
            df_combinado = df_combinado.drop_duplicates(subset=['fecha', 'sorteo'], keep='last')
        elif not df_nuevos.empty:
            df_combinado = df_nuevos
            df_combinado['fecha'] = pd.to_datetime(df_combinado['fecha']).dt.date
        else:
            df_combinado = df_existente
            df_combinado['fecha'] = pd.to_datetime(df_combinado['fecha']).dt.date

        df_combinado = df_combinado.sort_values(by='fecha', ascending=True).reset_index(drop=True)

        # -------------------------------------------------------------
        # Próximo sorteo y Jackpot
        # -------------------------------------------------------------
        jackpot_str, proxima_fecha = self.extraer_pozo_y_proximo_sorteo()
        ultima_fecha_real = df_combinado[df_combinado['balota1'] > 0]['fecha'].max()

        if not proxima_fecha:
            proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)

        print(f"📅 Fecha del próximo sorteo: {proxima_fecha}")
        print(f"💰 Premio mayor / Jackpot estimado: {jackpot_str}")

        # Placeholder en ceros para el sorteo futuro
        proxima_fecha_date = pd.to_datetime(proxima_fecha).date()
        df_real_only = df_combinado[df_combinado['balota1'] > 0].copy()

        fila_futura = pd.DataFrame([{
            "sorteo": self.game_name,
            "fecha": proxima_fecha_date,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balotaroja": 0
        }])

        df_final = pd.concat([df_real_only, fila_futura], ignore_index=True)
        df_final = df_final.sort_values(by='fecha', ascending=True).reset_index(drop=True)

        # -------------------------------------------------------------
        # Guardar en Base de Datos
        # -------------------------------------------------------------
        dtypes = {
            'sorteo': String(100),
            'fecha': Date,
            'balota1': Integer,
            'balota2': Integer,
            'balota3': Integer,
            'balota4': Integer,
            'balota5': Integer,
            'balotaroja': Integer
        }

        with self.engine.begin() as conn:
            df_final.to_sql('resultados_thunderball', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.execute(text("""
                ALTER TABLE resultados_thunderball ADD CONSTRAINT pk_resultados_thunderball PRIMARY KEY (fecha, sorteo);
            """))

        print(f"✅ ¡Resultados guardados exitosamente! Total filas: {len(df_final)}")

        # Actualizar jackpot en tabla loterias_jackpots
        if jackpot_str:
            self.actualizar_jackpot(proxima_fecha.strftime("%Y-%m-%d"), jackpot_str)


if __name__ == "__main__":
    is_backfill = "--backfill" in sys.argv
    scraper = ThunderballScraper()
    scraper.run(backfill=is_backfill)
