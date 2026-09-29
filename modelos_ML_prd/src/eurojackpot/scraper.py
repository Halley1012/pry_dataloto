import sys
import re
import time
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
from concurrent.futures import ThreadPoolExecutor, as_completed
from psycopg2.extras import execute_values

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class EurojackpotScraper:
    def __init__(self):
        self.engine = get_engine()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-ES,es;q=0.9,de;q=0.8,en;q=0.7",
        }
        self.base_url = "https://www.combinacionganadora.com/de/eurojackpot/"
        self.resultados_url = "https://www.combinacionganadora.com/de/eurojackpot/resultados/"
        self.game_name = "Eurojackpot"
        self.route = "eurojackpot"
        self.loteria_id = None
        # Sorteos de Eurojackpot: Martes (1) y Viernes (4)
        self.draw_days = (1, 4)

        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12',
            'januar': '01', 'februar': '02', 'märz': '03', 'maerz': '03',
            'april': '04', 'mai': '05', 'juni': '06', 'juli': '07',
            'august': '08', 'september': '09', 'oktober': '10', 'november': '11', 'dezember': '12'
        }

    def _asegurar_catalogo_loteria(self) -> int:
        """Garantiza que la lotería Eurojackpot exista en la tabla 'loterias'."""
        with self.engine.begin() as conn:
            # 1. Buscar si ya existe
            row = conn.execute(text("""
                SELECT id FROM loterias WHERE LOWER(route) = :route LIMIT 1;
            """), {"route": self.route}).fetchone()
            if row:
                self.loteria_id = int(row[0])
                return self.loteria_id

            # 2. Buscar o crear el país Alemania
            pais_row = conn.execute(text("""
                SELECT id FROM paises WHERE LOWER(nombre) LIKE '%alemania%' OR LOWER(nombre) LIKE '%germany%' LIMIT 1;
            """)).fetchone()
            if pais_row:
                pais_id = int(pais_row[0])
            else:
                p_ins = conn.execute(text("""
                    INSERT INTO paises (nombre) VALUES ('Alemania') RETURNING id;
                """)).fetchone()
                pais_id = int(p_ins[0])

            # 3. Registrar la lotería
            lot_ins = conn.execute(text("""
                INSERT INTO loterias (
                    nombre, tipo, pais_id, activa, route,
                    max_seleccion, max_balotas_blancas, max_balotas_rojas,
                    superbalota_nombre, has_revancha, total_balotas_sorteo,
                    tiene_complementario, tiene_reintegro
                ) VALUES (
                    :nombre, 'balotas', :pais_id, true, :route,
                    5, 50, 12,
                    'Eurozahlen', false, 7,
                    false, false
                ) RETURNING id;
            """), {
                "nombre": self.game_name,
                "pais_id": pais_id,
                "route": self.route
            }).fetchone()
            self.loteria_id = int(lot_ins[0])
            print(f"✅ Lotería {self.game_name} registrada en catálogo con ID {self.loteria_id}")
            return self.loteria_id

    def _obtener_loteria_id(self) -> int:
        if self.loteria_id is None:
            self._asegurar_catalogo_loteria()
        return self.loteria_id

    def _parse_date_spanish(self, text_str: str) -> date | None:
        """Extrae la fecha a partir de cadenas como 'Viernes, 11 septiembre 2026'."""
        if not text_str:
            return None
        m = re.search(r'(\d{1,2})\s+([a-zA-ZáéíóúÁÉÍÓÚäöüÄÖÜß]+)\s+(\d{4})', text_str)
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
        """Calcula el próximo sorteo de Eurojackpot: Martes (1) o Viernes (4)."""
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in self.draw_days:
            candidate += timedelta(days=1)
        return candidate

    def extraer_pozo_y_proximo_sorteo(self) -> tuple[str | None, date | None]:
        """Extrae el jackpot acumulado y la fecha del próximo sorteo desde la portada de Eurojackpot."""
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
            print(f"⚠️ Error consultando información de próximo sorteo Eurojackpot: {e}")

        if not jackpot_str:
            jackpot_str = "10.000.000 €"  # Bote mínimo garantizado de Eurojackpot

        return jackpot_str, next_draw_date

    def _parsear_sorteo_fecha(self, fecha_str: str) -> list[dict]:
        """Descarga y parsea el sorteo de una fecha específica."""
        url = f"{self.resultados_url}{fecha_str}/"
        try:
            r = requests.get(url, headers=self.headers, timeout=10)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                sorteo_div = soup.find("div", id="sorteo")
                if not sorteo_div:
                    sorteo_div = soup

                ul = sorteo_div.find("ul", class_=re.compile(r'numbers', re.I))
                if not ul:
                    return []

                lis = ul.find_all("li")
                main_nums = []
                euro_nums = []
                for li in lis:
                    txt = li.get_text(strip=True)
                    if txt.upper().startswith("E") or li.get("data-extra") is not None:
                        num_euro = re.search(r'\d+', txt)
                        if num_euro:
                            euro_nums.append(int(num_euro.group(0)))
                    elif txt.isdigit():
                        main_nums.append(int(txt))

                if len(main_nums) == 5 and len(euro_nums) == 2:
                    draw_date = datetime.strptime(fecha_str, "%Y-%m-%d").date()
                    m_sorted = sorted(main_nums)
                    e_sorted = sorted(euro_nums)
                    return [{
                        "sorteo": self.game_name,
                        "fecha": draw_date,
                        "balota1": m_sorted[0],
                        "balota2": m_sorted[1],
                        "balota3": m_sorted[2],
                        "balota4": m_sorted[3],
                        "balota5": m_sorted[4],
                        "balotaroja": e_sorted[0],
                        "balotaroja2": e_sorted[1],
                    }]
        except Exception:
            pass
        return []

    def extraer_recientes(self) -> pd.DataFrame:
        """Extrae los sorteos recientes desde la portada y el listado de resultados."""
        print(f"➡️ Solicitando resultados recientes de Eurojackpot desde {self.resultados_url}...")
        draws = []
        try:
            r = requests.get(self.resultados_url, headers=self.headers, timeout=12)
            if r.status_code == 200:
                links = re.findall(r'/de/eurojackpot/resultados/(\d{4}-\d{2}-\d{2})/', r.text)
                fechas_unicas = list(dict.fromkeys(links))[:15]
                print(f"ℹ️ Encontradas {len(fechas_unicas)} fechas recientes en la fuente.")
                for f_str in fechas_unicas:
                    items = self._parsear_sorteo_fecha(f_str)
                    draws.extend(items)
                    time.sleep(0.1)
        except Exception as e:
            print(f"❌ Error extrayendo recientes de Eurojackpot: {e}")

        df = pd.DataFrame(draws)
        if not df.empty:
            df['fecha'] = pd.to_datetime(df['fecha']).dt.date
            df = df.drop_duplicates(subset=['fecha', 'sorteo']).sort_values('fecha', ascending=False).reset_index(drop=True)
        return df

    def extraer_historico_concurrente(self, max_draws: int = 150) -> pd.DataFrame:
        """Genera fechas pasadas de sorteos (Martes y Viernes) y descarga resultados con ThreadPoolExecutor."""
        print(f"➡️ Generando fechas de sorteos pasados para Eurojackpot (máx {max_draws})...")
        fechas = []
        curr = datetime.now().date()
        while len(fechas) < max_draws:
            if curr.weekday() in self.draw_days:
                fechas.append(curr.strftime("%Y-%m-%d"))
            curr -= timedelta(days=1)

        print(f"Descargando {len(fechas)} sorteos históricos de Eurojackpot con ThreadPoolExecutor...")
        draws = []
        with ThreadPoolExecutor(max_workers=8) as executor:
            futuros = {executor.submit(self._parsear_sorteo_fecha, f): f for f in fechas}
            for fut in as_completed(futuros):
                res_list = fut.result()
                if res_list:
                    draws.extend(res_list)

        df = pd.DataFrame(draws)
        if not df.empty:
            df['fecha'] = pd.to_datetime(df['fecha']).dt.date
            df = df.drop_duplicates(subset=['fecha', 'sorteo']).sort_values('fecha', ascending=False).reset_index(drop=True)
        print(f"✅ Descargados {len(df)} registros históricos de Eurojackpot.")
        return df

    def actualizar_jackpot(self, proxima_fecha_str: str, jackpot_str: str):
        """Actualiza la tabla loterias_jackpots con el bote del próximo sorteo."""
        if not jackpot_str or not proxima_fecha_str:
            return

        print(f"💰 Actualizando jackpot para {self.route}: {jackpot_str} (Fecha: {proxima_fecha_str})")
        try:
            with self.engine.begin() as conn:
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
            print(f"✅ Jackpot de {self.game_name} actualizado exitosamente.")
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para {self.route}: {e}")

    def _preparar_para_guardar(self, df: pd.DataFrame) -> pd.DataFrame:
        """Agrega identidad canónica y un concurso estable YYYYMMDD."""
        resultado = df.copy()
        resultado['fecha'] = pd.to_datetime(resultado['fecha'], errors='coerce').dt.date
        resultado = resultado.dropna(subset=['fecha', 'sorteo']).copy()
        codigo_fecha = pd.to_datetime(resultado['fecha']).dt.strftime('%Y%m%d').astype(int)
        resultado['concurso'] = codigo_fecha
        resultado['loteria_id'] = self._obtener_loteria_id()
        return resultado

    def _guardar_resultados(self, df: pd.DataFrame) -> None:
        """Crea la tabla y guarda resultados sin borrar el histórico."""
        df = self._preparar_para_guardar(df)
        if df.empty:
            raise RuntimeError("No hay filas válidas de Eurojackpot para guardar.")

        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_eurojackpot (
                    concurso INTEGER CONSTRAINT pk_resultados_eurojackpot PRIMARY KEY,
                    loteria_id INTEGER NOT NULL REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INTEGER NOT NULL, balota2 INTEGER NOT NULL,
                    balota3 INTEGER NOT NULL, balota4 INTEGER NOT NULL,
                    balota5 INTEGER NOT NULL,
                    balotaroja INTEGER NOT NULL DEFAULT 0,
                    balotaroja2 INTEGER NOT NULL DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_eurojackpot_fecha ON resultados_eurojackpot(fecha DESC);
                CREATE INDEX IF NOT EXISTS idx_eurojackpot_loteria_id ON resultados_eurojackpot(loteria_id);
            """))

        insert_sql = """
            INSERT INTO resultados_eurojackpot (
                concurso, loteria_id, sorteo, fecha, balota1, balota2,
                balota3, balota4, balota5, balotaroja, balotaroja2, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (concurso) DO UPDATE SET
                loteria_id = EXCLUDED.loteria_id, sorteo = EXCLUDED.sorteo,
                fecha = EXCLUDED.fecha, balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2, balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4, balota5 = EXCLUDED.balota5,
                balotaroja = EXCLUDED.balotaroja, balotaroja2 = EXCLUDED.balotaroja2,
                updated_at = CURRENT_TIMESTAMP;
        """
        columnas = ['concurso', 'loteria_id', 'sorteo', 'fecha', 'balota1', 'balota2',
                    'balota3', 'balota4', 'balota5', 'balotaroja', 'balotaroja2']
        valores = [tuple(r[c] for c in columnas) for r in df.to_dict(orient='records')]
        raw_conn = self.engine.raw_connection()
        try:
            with raw_conn.cursor() as cur:
                execute_values(cur, insert_sql, valores,
                    template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
            raw_conn.commit()
        finally:
            raw_conn.close()

    def run(self, backfill: bool = False):
        print("==================================================")
        print("🚀 Iniciando Scraping de Eurojackpot (Alemania)...")
        print("==================================================")

        # 1. Asegurar catálogo
        self._asegurar_catalogo_loteria()

        # 2. Consultar BD existente
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_eurojackpot WHERE balota1 > 0;"), conn)
        except Exception as e:
            print(f"ℹ️ Tabla resultados_eurojackpot aún sin datos o error de lectura: {e}")

        # 3. Descargar sorteos
        if backfill or df_existente.empty or len(df_existente) < 40:
            print("📦 Ejecutando descarga de histórico para Eurojackpot...")
            df_scraped = self.extraer_historico_concurrente(max_draws=150)
        else:
            df_scraped = self.extraer_recientes()

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados para Eurojackpot.")
            return False

        # 4. Combinar
        if not df_existente.empty:
            df_combined = pd.concat([df_existente, df_scraped], ignore_index=True)
        else:
            df_combined = df_scraped

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined = df_combined.drop_duplicates(subset=['fecha', 'sorteo']).sort_values('fecha', ascending=False).reset_index(drop=True)

        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay sorteos válidos para guardar.")
            return False

        # 5. Obtener pozo y calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        jackpot_str, proxima_fecha_web = self.extraer_pozo_y_proximo_sorteo()

        if proxima_fecha_web and proxima_fecha_web > ultima_fecha_real:
            proxima_fecha = proxima_fecha_web
        else:
            proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)

        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo: {proxima_fecha_str}")
        print(f"💰 Jackpot estimado: {jackpot_str}")

        # Placeholder en ceros para el próximo sorteo
        fila_proximo = {
            "sorteo": self.game_name,
            "fecha": proxima_fecha,
            "balota1": 0, "balota2": 0, "balota3": 0, "balota4": 0, "balota5": 0,
            "balotaroja": 0, "balotaroja2": 0
        }

        # Limpiar placeholders anteriores a proxima_fecha
        try:
            with self.engine.begin() as conn:
                conn.execute(text("""
                    DELETE FROM resultados_eurojackpot
                    WHERE balota1 = 0 AND fecha < :proxima_fecha;
                """), {"proxima_fecha": proxima_fecha})
        except Exception:
            pass

        df_final = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 6. Guardar resultados
        self._guardar_resultados(df_final)

        # 7. Actualizar jackpot
        self.actualizar_jackpot(proxima_fecha_str, jackpot_str)

        print("✅ Scraping de Eurojackpot finalizado con éxito.")
        return {
            "hubo_sorteo": True,
            "ultimo_sorteo": str(ultima_fecha_real),
            "proximo_esperado": proxima_fecha_str
        }
