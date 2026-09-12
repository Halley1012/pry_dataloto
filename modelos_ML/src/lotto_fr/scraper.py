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


class LottoFrScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-ES,es;q=0.9,fr;q=0.8,en;q=0.7",
        }
        self.base_url = "https://www.combinacionganadora.com/fr/lotto-fr/"
        self.resultados_url = "https://www.combinacionganadora.com/fr/lotto-fr/resultados/"
        self.game_name = "Loto Francia"
        self.revancha_name = "2nd Tirage"
        self.route = "lotto_fr"
        # Sorteos de Loto Francia: Lunes (0), Miércoles (2), Sábado (5)
        self.draw_days = (0, 2, 5)

        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12',
            'janvier': '01', 'février': '02', 'fevrier': '02', 'mars': '03', 'avril': '04',
            'mai': '05', 'juin': '06', 'juillet': '07', 'août': '08', 'aout': '08',
            'septembre': '09', 'octobre': '10', 'novembre': '11', 'décembre': '12', 'decembre': '12'
        }

    def _parse_date_spanish(self, text_str: str) -> date | None:
        """Extrae la fecha a partir de cadenas como 'Miércoles, 09 septiembre 2026'."""
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
        """Calcula el próximo sorteo de Loto Francia: Lunes (0), Miércoles (2) o Sábado (5)."""
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in self.draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_y_proximo_sorteo(self) -> tuple[str | None, date | None]:
        """Extrae el jackpot acumulado y la fecha del próximo sorteo desde la página principal."""
        print(f"➡️ Consultando jackpot y próximo sorteo desde {self.base_url}...")
        jackpot_str = None
        next_draw_date = None

        try:
            r = requests.get(self.base_url, headers=self.headers, timeout=12)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                playarea = soup.find("div", attrs={"data-playarea": True})
                if playarea:
                    txt = playarea.get_text(" ", strip=True)
                    m_date = re.search(r'Siguiente sorteo:?\s*([a-zA-ZáéíóúÁÉÍÓÚ]+,?\s*\d{1,2}\s+[a-zA-ZáéíóúÁÉÍÓÚ]+\s+\d{4})', txt, re.IGNORECASE)
                    if m_date:
                        next_draw_date = self._parse_date_spanish(m_date.group(1))

                    jackpot_elem = playarea.find(class_=re.compile(r'jackpot', re.I))
                    if jackpot_elem:
                        strong = jackpot_elem.find("strong")
                        raw_num = ""
                        if strong:
                            span = strong.find("span")
                            raw_num = span.get_text(strip=True) if span else strong.get_text(strip=True)
                        if raw_num:
                            jackpot_str = f"{raw_num} €"

                    if not jackpot_str:
                        m_jp = re.search(r'([\d\.,]+)\s*€', txt)
                        if m_jp:
                            jackpot_str = f"{m_jp.group(1)} €"

        except Exception as e:
            print(f"⚠️ Error consultando información de próximo sorteo: {e}")

        if not jackpot_str:
            jackpot_str = "2.000.000 €"

        return jackpot_str, next_draw_date

    def _parsear_sorteo_fecha(self, fecha_str: str) -> list[dict]:
        """Descarga y parsea los sorteos de una fecha: Loto Francia y Lotto 2nd Tirage."""
        url = f"{self.resultados_url}{fecha_str}/"
        try:
            r = requests.get(url, headers=self.headers, timeout=8)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                sorteo_div = soup.find("div", id="sorteo")
                if not sorteo_div:
                    sorteo_div = soup

                uls = sorteo_div.find_all("ul", class_=re.compile(r'numbers', re.I))
                draw_date = datetime.strptime(fecha_str, "%Y-%m-%d").date()
                items = []

                if len(uls) >= 1:
                    # 1. Sorteo Principal: Loto Francia (5 balotas + Chance)
                    lis = uls[0].find_all("li")
                    nums = []
                    chance = None
                    for li in lis:
                        txt = li.get_text(strip=True)
                        if txt.upper().startswith("C") or li.get("data-extra") is not None:
                            num_chance = re.search(r'\d+', txt)
                            if num_chance:
                                chance = int(num_chance.group(0))
                        elif txt.isdigit():
                            nums.append(int(txt))

                    if len(nums) == 5 and chance is not None:
                        nums_sorted = sorted(nums)
                        items.append({
                            "sorteo": self.game_name,
                            "fecha": draw_date,
                            "balota1": nums_sorted[0],
                            "balota2": nums_sorted[1],
                            "balota3": nums_sorted[2],
                            "balota4": nums_sorted[3],
                            "balota5": nums_sorted[4],
                            "balotaroja": chance
                        })

                if len(uls) >= 2:
                    # 2. Sorteo Secundario: Lotto 2nd Tirage (5 balotas, sin Chance)
                    lis_2nd = uls[1].find_all("li")
                    nums_2nd = [int(re.search(r'\d+', li.get_text(strip=True)).group(0))
                                for li in lis_2nd if re.search(r'\d+', li.get_text(strip=True))]
                    if len(nums_2nd) == 5:
                        nums_2nd_sorted = sorted(nums_2nd)
                        items.append({
                            "sorteo": self.revancha_name,
                            "fecha": draw_date,
                            "balota1": nums_2nd_sorted[0],
                            "balota2": nums_2nd_sorted[1],
                            "balota3": nums_2nd_sorted[2],
                            "balota4": nums_2nd_sorted[3],
                            "balota5": nums_2nd_sorted[4],
                            "balotaroja": 0
                        })

                return items
        except Exception:
            pass
        return []

    def extraer_recientes(self) -> pd.DataFrame:
        """Extrae los sorteos más recientes (Loto Francia y 2nd Tirage) desde la web."""
        print(f"➡️ Solicitando resultados recientes de Loto Francia y 2nd Tirage desde {self.base_url}...")
        draws = []
        try:
            r = requests.get(self.base_url, headers=self.headers, timeout=12)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                sorteo_div = soup.find("div", id="sorteo")
                if sorteo_div:
                    span_date = sorteo_div.find("span", class_=re.compile(r'fdLotto-fr|fontSize', re.I))
                    if span_date:
                        fecha = self._parse_date_spanish(span_date.get_text(strip=True))
                        if fecha:
                            items = self._parsear_sorteo_fecha(fecha.strftime("%Y-%m-%d"))
                            draws.extend(items)

            if not draws:
                # Fallback: consultar la lista de resultados y parsear la primera fecha
                r_hist = requests.get(self.resultados_url, headers=self.headers, timeout=12)
                if r_hist.status_code == 200:
                    soup_h = BeautifulSoup(r_hist.text, "html.parser")
                    blocks = soup_h.find_all("div", class_="gameSummaryBlock")
                    for b in blocks[:3]:
                        span_d = b.find("span", class_=re.compile(r'fdLotto-fr|fontSize', re.I))
                        if span_d:
                            f = self._parse_date_spanish(span_d.get_text(strip=True))
                            if f:
                                draws.extend(self._parsear_sorteo_fecha(f.strftime("%Y-%m-%d")))

            df = pd.DataFrame(draws)
            print(f"ℹ️ Encontrados {len(df)} sorteos recientes de Loto Francia y 2nd Tirage.")
            return df
        except Exception as e:
            print(f"❌ Error extrayendo recientes de Loto Francia: {e}")
            return pd.DataFrame()

    def extraer_historico_concurrente(self, max_draws: int = 150) -> pd.DataFrame:
        """Genera fechas pasadas de sorteos (Lunes, Miércoles, Sábado) y descarga Loto + 2nd Tirage."""
        print(f"➡️ Generando fechas de sorteos pasados para Loto Francia (máx {max_draws})...")
        fechas = []
        curr = datetime.now().date()
        while len(fechas) < max_draws:
            if curr.weekday() in self.draw_days:
                fechas.append(curr.strftime("%Y-%m-%d"))
            curr -= timedelta(days=1)

        print(f"Descargando {len(fechas)} fechas de Loto Francia y 2nd Tirage con ThreadPoolExecutor...")
        draws = []
        with ThreadPoolExecutor(max_workers=8) as executor:
            futuros = {executor.submit(self._parsear_sorteo_fecha, f): f for f in fechas}
            for fut in as_completed(futuros):
                res_list = fut.result()
                if res_list:
                    draws.extend(res_list)

        df = pd.DataFrame(draws)
        print(f"✅ Descargados {len(df)} registros totales (Loto + 2nd Tirage).")
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
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '7 days';
                """), {"loteria": self.route})
                conn.commit()
            print(f"✅ Jackpot de {self.game_name} actualizado exitosamente.")
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para {self.route}: {e}")

    def run(self, backfill: bool = False):
        print("==================================================")
        print("🚀 Iniciando Scraping de Loto Francia y 2nd Tirage...")
        print("==================================================")

        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_lotto_fr WHERE balota1 > 0;"), conn)
        except Exception as e:
            print(f"ℹ️ Tabla resultados_lotto_fr aún sin datos o error de lectura: {e}")

        # 2. Descargar datos
        has_2nd = not df_existente.empty and (self.revancha_name in df_existente['sorteo'].values)
        if backfill or df_existente.empty or len(df_existente) < 40 or not has_2nd:
            print("📦 Ejecutando descarga de histórico para Loto Francia y 2nd Tirage...")
            df_scraped = self.extraer_historico_concurrente(max_draws=150)
        else:
            df_scraped = self.extraer_recientes()

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados para Loto Francia.")
            return

        # 3. Combinar y limpiar
        if not df_existente.empty and has_2nd:
            df_combined = pd.concat([df_existente, df_scraped], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo']).sort_values(['fecha', 'sorteo'], ascending=[False, True]).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay sorteos válidos para guardar.")
            return

        # 4. Obtener pozo y calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        jackpot_str, proxima_fecha_web = self.extraer_pozo_y_proximo_sorteo()

        if proxima_fecha_web and proxima_fecha_web > ultima_fecha_real:
            proxima_fecha = proxima_fecha_web
        else:
            proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)

        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo: {proxima_fecha_str}")
        print(f"💰 Jackpot estimado: {jackpot_str}")

        # Filas placeholder para el próximo sorteo (en ceros para Loto Francia y 2nd Tirage)
        filas_proximo = [
            {
                "sorteo": self.game_name,
                "fecha": proxima_fecha,
                "balota1": 0,
                "balota2": 0,
                "balota3": 0,
                "balota4": 0,
                "balota5": 0,
                "balotaroja": 0
            },
            {
                "sorteo": self.revancha_name,
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

        # 5. Guardar en PostgreSQL
        dtypes = {
            'sorteo': String(50),
            'fecha': Date(),
            'balota1': Integer(),
            'balota2': Integer(),
            'balota3': Integer(),
            'balota4': Integer(),
            'balota5': Integer(),
            'balotaroja': Integer(),
        }

        with self.engine.connect() as conn:
            df_final.to_sql('resultados_lotto_fr', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.execute(text("""
                ALTER TABLE resultados_lotto_fr ADD CONSTRAINT pk_resultados_lotto_fr PRIMARY KEY (fecha, sorteo);
            """))
            conn.commit()

        total_loto = len(df_combined[df_combined['sorteo'] == self.game_name])
        total_2nd = len(df_combined[df_combined['sorteo'] == self.revancha_name])
        print(f"✅ ¡Resultados guardados exitosamente! Total filas: {len(df_final)} ({total_loto} Loto Francia, {total_2nd} 2nd Tirage)")

        # 6. Actualizar jackpot
        self.actualizar_jackpot(proxima_fecha_str, jackpot_str)


if __name__ == "__main__":
    scraper = LottoFrScraper()
    scraper.run(backfill=True)
