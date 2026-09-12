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


class TotolotoScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "pt-PT,pt;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.base_url = "https://www.combinacionganadora.com/pt/totoloto/"
        self.resultados_url = "https://www.combinacionganadora.com/pt/totoloto/resultados/"
        self.game_name = "Totoloto"
        self.route = "totoloto"
        # Sorteos de Totoloto: Miércoles (2) y Sábados (5)
        self.draw_days = (2, 5)

        self.meses = {
            # Español
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12',
            # Portugués
            'janeiro': '01', 'fevereiro': '02', 'março': '03', 'marco': '03',
            'abril': '04', 'maio': '05', 'junho': '06', 'julho': '07',
            'agosto': '08', 'setembro': '09', 'outubro': '10', 'novembro': '11', 'dezembro': '12'
        }

    def _parse_date(self, text_str: str) -> date | None:
        """Extrae la fecha a partir de cadenas como 'Miércoles, 09 septiembre 2026' o '09 setembro 2026'."""
        if not text_str:
            return None
        m = re.search(r'(\d{1,2})\s+([a-zA-ZáéíóúÁÉÍÓÚçãõÇÃÕ]+)\s+(\d{4})', text_str)
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
        """Calcula el próximo sorteo de Totoloto: Miércoles (2) o Sábado (5)."""
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in self.draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_y_proximo_sorteo(self) -> tuple[str | None, date | None]:
        """Extrae el bote acumulado y la fecha del próximo sorteo desde la página principal."""
        print(f"➡️ Consultando bote y próximo sorteo desde {self.base_url}...")
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
                    m_date = re.search(r'Siguiente sorteo:?\s*([a-zA-ZáéíóúÁÉÍÓÚçãõÇÃÕ]+,?\s*\d{1,2}\s+[a-zA-ZáéíóúÁÉÍÓÚçãõÇÃÕ]+\s+\d{4})', txt, re.IGNORECASE)
                    if m_date:
                        next_draw_date = self._parse_date(m_date.group(1))

                # Extraer bote: buscar bloque Bote (ej. dl.text-center -> Bote 1.800.000,00 €)
                for tag in soup.find_all(["dl", "div", "p", "span"]):
                    t = tag.get_text(" ", strip=True)
                    if "bote" in t.lower() and "€" in t:
                        m_bote = re.search(r'bote\s*([\d\.,]+)\s*€', t, re.IGNORECASE)
                        if m_bote:
                            val = m_bote.group(1).replace(",00", "")
                            jackpot_str = f"{val} €"
                            break

                if not jackpot_str:
                    # Intento alternativo por clase jackpot
                    jackpot_elem = soup.find(class_=re.compile(r'jackpot', re.I))
                    if jackpot_elem:
                        m_jp = re.search(r'([\d\.,]+)\s*€', jackpot_elem.get_text(strip=True))
                        if m_jp:
                            jackpot_str = f"{m_jp.group(1).replace(',00', '')} €"

        except Exception as e:
            print(f"⚠️ Error consultando información de próximo sorteo de Totoloto: {e}")

        if not jackpot_str:
            jackpot_str = "1.000.000 €"  # Bote mínimo garantizado de Totoloto

        return jackpot_str, next_draw_date

    def extraer_recientes(self) -> pd.DataFrame:
        """Extrae los últimos resultados disponibles desde combinacionganadora.com/pt/totoloto/resultados/"""
        print(f"➡️ Solicitando resultados recientes de Totoloto desde {self.resultados_url}...")
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
                date_span = b.find("span", class_=re.compile(r'fdTotoloto|fontSize', re.I))
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

                # 5 números principales y 1 Número da Sorte (C + dígito)
                nums = []
                sorte = None
                for li in lis:
                    txt = li.get_text(strip=True)
                    if txt.upper().startswith("C") or li.get("data-extra") is not None:
                        num_sorte = re.search(r'\d+', txt)
                        if num_sorte:
                            sorte = int(num_sorte.group(0))
                    elif txt.isdigit():
                        nums.append(int(txt))

                if len(nums) == 5 and sorte is not None:
                    nums_sorted = sorted(nums)
                    draws.append({
                        "sorteo": self.game_name,
                        "fecha": fecha,
                        "balota1": nums_sorted[0],
                        "balota2": nums_sorted[1],
                        "balota3": nums_sorted[2],
                        "balota4": nums_sorted[3],
                        "balota5": nums_sorted[4],
                        "balotaroja": sorte
                    })

            df = pd.DataFrame(draws)
            print(f"ℹ️ Encontrados {len(df)} sorteos recientes de Totoloto.")
            return df
        except Exception as e:
            print(f"❌ Error extrayendo recientes de Totoloto: {e}")
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
                    return None

                ul = sorteo_div.find("ul", class_=re.compile(r'numbers', re.I))
                if not ul:
                    return None

                lis = ul.find_all("li")
                if len(lis) < 6:
                    return None

                nums = []
                sorte = None
                for li in lis:
                    txt = li.get_text(strip=True)
                    if txt.upper().startswith("C") or li.get("data-extra") is not None:
                        num_sorte = re.search(r'\d+', txt)
                        if num_sorte:
                            sorte = int(num_sorte.group(0))
                    elif txt.isdigit():
                        nums.append(int(txt))

                if len(nums) == 5 and sorte is not None:
                    nums_sorted = sorted(nums)
                    return {
                        "sorteo": self.game_name,
                        "fecha": datetime.strptime(fecha_str, "%Y-%m-%d").date(),
                        "balota1": nums_sorted[0],
                        "balota2": nums_sorted[1],
                        "balota3": nums_sorted[2],
                        "balota4": nums_sorted[3],
                        "balota5": nums_sorted[4],
                        "balotaroja": sorte
                    }
        except Exception:
            pass
        return None

    def extraer_historico_concurrente(self, max_draws: int = 150) -> pd.DataFrame:
        """Genera fechas pasadas de sorteos (Miércoles y Sábados) y las descarga concurrentemente."""
        print(f"➡️ Generando fechas de sorteos pasados para Totoloto (máx {max_draws})...")
        fechas = []
        curr = datetime.now().date()
        while len(fechas) < max_draws:
            if curr.weekday() in self.draw_days:
                fechas.append(curr.strftime("%Y-%m-%d"))
            curr -= timedelta(days=1)

        print(f"Descargando {len(fechas)} sorteos históricos de Totoloto con ThreadPoolExecutor...")
        draws = []
        with ThreadPoolExecutor(max_workers=8) as executor:
            futuros = {executor.submit(self._parsear_sorteo_fecha, f): f for f in fechas}
            for fut in as_completed(futuros):
                res = fut.result()
                if res:
                    draws.append(res)

        df = pd.DataFrame(draws)
        print(f"✅ Descargados {len(df)} sorteos históricos de Totoloto.")
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
            print(f"✅ Jackpot de {self.game_name} actualizado exitosamente.")
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para {self.route}: {e}")

    def run(self, backfill: bool = False):
        print("==================================================")
        print("🚀 Iniciando Scraping de Totoloto (Portugal)...")
        print("==================================================")

        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_totoloto WHERE balota1 > 0;"), conn)
        except Exception as e:
            print(f"ℹ️ Tabla resultados_totoloto aún sin datos o error de lectura: {e}")

        # 2. Descargar datos
        if backfill or df_existente.empty or len(df_existente) < 20:
            print("📦 Ejecutando descarga de histórico para Totoloto...")
            df_hist = self.extraer_historico_concurrente(max_draws=150)
            df_rec = self.extraer_recientes()
            df_scraped = pd.concat([df_rec, df_hist], ignore_index=True)
        else:
            df_scraped = self.extraer_recientes()

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados para Totoloto.")
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
        print(f"📅 Fecha del próximo sorteo para Totoloto: {proxima_fecha_str}")
        print(f"💰 Jackpot estimado: {jackpot_str}")

        # Fila placeholder para el próximo sorteo (en ceros)
        fila_proximo = {
            "sorteo": self.game_name,
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
            'balotaroja': Integer(),
        }

        with self.engine.connect() as conn:
            df_final.to_sql('resultados_totoloto', conn, if_exists='replace', index=False, dtype=dtypes)
            conn.execute(text("""
                ALTER TABLE resultados_totoloto ADD CONSTRAINT pk_resultados_totoloto PRIMARY KEY (fecha);
            """))
            conn.commit()

        print(f"✅ ¡Resultados de Totoloto guardados exitosamente! Total filas: {len(df_final)} ({len(df_combined)} sorteos reales)")

        # 6. Actualizar jackpot en la base de datos
        self.actualizar_jackpot(proxima_fecha_str, jackpot_str)


if __name__ == "__main__":
    scraper = TotolotoScraper()
    scraper.run(backfill=True)
