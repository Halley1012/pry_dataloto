import sys
import re
import io
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
from psycopg2.extras import execute_values
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class ChispazoScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 18
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-MX,es;q=0.9,en;q=0.8",
        }
        self.url_csv = "https://www.pronosticos.gob.mx/Documentos/Historicos/Chispazo.csv"
        self.url_web = "https://www.loterianacional.gob.mx/Chispazo/Resultados"

    def _determinar_modalidad(self, concurso: int) -> str:
        """
        Determina si el concurso corresponde a 'Chispazo de las Tres' (15:00) o 'Chispazo Clásico' (21:15).
        En la regla oficial de la Lotería Nacional:
        - Concursos impares -> Chispazo de las Tres
        - Concursos pares -> Chispazo Clásico
        """
        return "Chispazo de las Tres" if concurso % 2 != 0 else "Chispazo Clásico"

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

    def _calcular_proximo_sorteo(self, ultimo_concurso: int, ultima_fecha_real: date) -> tuple[int, str, date]:
        """
        Calcula el número de concurso, modalidad y fecha del próximo sorteo.
        Los sorteos de Chispazo se realizan todos los días (2 veces al día: 15:00 y 21:15).
        """
        proximo_concurso = int(ultimo_concurso) + 1
        modalidad = self._determinar_modalidad(proximo_concurso)

        # Si el último sorteo fue impar (De las Tres), el siguiente (Clásico) es el mismo día.
        # Si el último sorteo fue par (Clásico), el siguiente (De las Tres) es al día siguiente.
        if ultimo_concurso % 2 != 0:
            proxima_fecha = ultima_fecha_real
        else:
            proxima_fecha = ultima_fecha_real + timedelta(days=1)

        hoy = datetime.now().date()
        if proxima_fecha < hoy:
            proxima_fecha = hoy

        return proximo_concurso, modalidad, proxima_fecha

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo REAL registrado en la BD (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, sorteo
                    FROM resultados_chispazo
                    WHERE balota1 > 0
                    ORDER BY concurso DESC
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
        """Extrae el último sorteo REAL publicado en la fuente (tabla de la web oficial)."""
        try:
            r = requests.get(self.url_web, headers=self.headers, timeout=12, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                tables = soup.find_all("table")
                if len(tables) > 1:
                    t1 = tables[1]
                    rows = t1.find_all("tr")[1:]
                    if rows:
                        tds = rows[0].find_all("td")
                        if len(tds) >= 3:
                            concurso_raw = tds[0].get_text(strip=True)
                            fecha_str = self._parse_fecha(tds[1].get_text(strip=True))
                            comb = tds[2].get_text(strip=True)
                            nat_str = comb.strip().split()
                            balls = [int(n) for n in nat_str if n.isdigit()]
                            if concurso_raw.isdigit() and fecha_str and len(balls) == 5:
                                concurso = int(concurso_raw)
                                return {
                                    "concurso": concurso,
                                    "fecha": fecha_str,
                                    "sorteo": self._determinar_modalidad(concurso),
                                    "balotas": balls
                                }
        except Exception as e:
            print(f"⚠️ Error extrayendo último sorteo de la fuente Chispazo: {e}")
        return None

    def extraer_csv(self) -> tuple[pd.DataFrame, str]:
        """Descarga el archivo histórico oficial CSV con todos los sorteos de Chispazo."""
        print(f"➡️ Descargando histórico oficial CSV de Chispazo desde {self.url_csv}...")
        jackpot_destacado = "$1,500,000 MXN"

        try:
            r = requests.get(self.url_csv, headers=self.headers, timeout=20, verify=False)
            if r.status_code == 200 and len(r.text) > 1000:
                df_raw = pd.read_csv(io.StringIO(r.text))

                # Columnas esperadas: ['CONCURSO', 'R1', 'R2', 'R3', 'R4', 'R5', 'FECHA']
                draws = []
                for _, row in df_raw.iterrows():
                    fecha_str = self._parse_fecha(str(row.get('FECHA', '')))
                    concurso_val = row.get('CONCURSO')
                    if fecha_str and pd.notna(concurso_val):
                        try:
                            concurso = int(concurso_val)
                            # Conservar el orden original extraído (sin sorted)
                            r1 = int(row['R1'])
                            r2 = int(row['R2'])
                            r3 = int(row['R3'])
                            r4 = int(row['R4'])
                            r5 = int(row['R5'])
                            draws.append({
                                "concurso": concurso,
                                "loteria_id": self.loteria_id,
                                "sorteo": self._determinar_modalidad(concurso),
                                "fecha": fecha_str,
                                "balota1": r1,
                                "balota2": r2,
                                "balota3": r3,
                                "balota4": r4,
                                "balota5": r5,
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
            r = requests.get(self.url_web, headers=self.headers, timeout=15, verify=False)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "html.parser")
                tables = soup.find_all("table")

                # Tabla 1 contiene el histórico reciente
                if len(tables) > 1:
                    t1 = tables[1]
                    for row in t1.find_all("tr")[1:]:
                        tds = row.find_all("td")
                        if len(tds) >= 3:
                            concurso_raw = tds[0].get_text(strip=True)
                            fecha_str = self._parse_fecha(tds[1].get_text(strip=True))
                            comb = tds[2].get_text(strip=True)
                            nat_str = comb.strip().split()
                            # Conservar el orden original extraído (sin sorted)
                            balls = [int(n) for n in nat_str if n.isdigit()]
                            if len(balls) == 5 and fecha_str and concurso_raw.isdigit():
                                concurso = int(concurso_raw)
                                draws.append({
                                    "concurso": concurso,
                                    "loteria_id": self.loteria_id,
                                    "sorteo": self._determinar_modalidad(concurso),
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

        # 1. Detección temprana: comparar último sorteo real en BD vs fuente
        ultimo_db = self.obtener_ultimo_sorteo_db()
        ultimo_fuente = self.extraer_ultimo_sorteo_fuente()

        if not backfill and ultimo_db and ultimo_fuente:
            concurso_db = ultimo_db.get("concurso")
            concurso_fuente = ultimo_fuente.get("concurso")

            if concurso_fuente and concurso_db and concurso_fuente <= concurso_db:
                print(f"ℹ️ Detección temprana: No hay sorteo nuevo para Chispazo.")
                print(f"   BD: #{concurso_db} ({ultimo_db.get('fecha')}) vs Fuente: #{concurso_fuente} ({ultimo_fuente.get('fecha')})")
                try:
                    f_dt = datetime.strptime(ultimo_db['fecha'], "%Y-%m-%d").date()
                except Exception:
                    f_dt = ultimo_db['fecha']
                prox_concurso, prox_modalidad, proxima_fecha = self._calcular_proximo_sorteo(concurso_db, f_dt)
                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"{ultimo_db.get('fecha')} (#{concurso_db})",
                    "proximo_esperado": f"{proxima_fecha.strftime('%d/%m/%Y')} (#{prox_concurso} - {prox_modalidad})"
                }

        # 2. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_chispazo WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 3. Descargar datos (recientes web por defecto, o CSV si se solicita backfill)
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
            return False

        # 4. Combinar y limpiar
        if not df_existente.empty and not df_scraped.empty:
            df_combined = pd.concat([df_scraped, df_existente], ignore_index=True)
        elif not df_scraped.empty:
            df_combined = df_scraped
        else:
            df_combined = df_existente

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha']).dt.date
        df_combined['concurso'] = df_combined['concurso'].astype(int)

        # Deduplicar preservando todos los concursos únicos ordenados descendentemente (prioridad a recién scrapeados)
        df_combined = df_combined.drop_duplicates(subset=['concurso'], keep='first').sort_values('concurso', ascending=False).reset_index(drop=True)

        # Filtrar fechas futuras accidentales
        hoy_max = datetime.now().date()
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]

        if df_combined.empty:
            print("❌ No hay datos válidos para procesar.")
            return False

        # 5. Calcular próximo sorteo a predecir
        ultimo_concurso = int(df_combined.iloc[0]['concurso'])
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        prox_concurso, prox_modalidad, proxima_fecha = self._calcular_proximo_sorteo(ultimo_concurso, ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Próximo sorteo Chispazo: #{prox_concurso} ({prox_modalidad}) - Fecha: {proxima_fecha_str}")

        # Fila placeholder en ceros para el próximo sorteo a predecir
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": prox_modalidad,
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balotaroja": 0
        }

        # Si es backfill, guardamos todo el histórico combinado; si es rutina, solo lo nuevo y el placeholder
        if backfill:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)
        else:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_scraped], ignore_index=True)
            df_to_save = df_to_save.drop_duplicates(subset=['concurso'], keep='first')

        # 6. Guardar en PostgreSQL asegurando estructura, índices y UPSERT
        try:
            with self.engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS resultados_chispazo (
                        concurso INTEGER PRIMARY KEY,
                        loteria_id INTEGER NOT NULL DEFAULT 18 REFERENCES loterias(id),
                        sorteo VARCHAR(50) NOT NULL,
                        fecha DATE NOT NULL,
                        balota1 INTEGER NOT NULL,
                        balota2 INTEGER NOT NULL,
                        balota3 INTEGER NOT NULL,
                        balota4 INTEGER NOT NULL,
                        balota5 INTEGER NOT NULL,
                        balotaroja INTEGER NOT NULL DEFAULT 0,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                    );
                    CREATE INDEX IF NOT EXISTS idx_chispazo_fecha ON resultados_chispazo(fecha DESC);
                    CREATE INDEX IF NOT EXISTS idx_chispazo_loteria_id ON resultados_chispazo(loteria_id);
                """))

            # Eliminar posibles placeholders obsoletos anteriores al nuevo próximo sorteo
            with self.engine.begin() as conn:
                conn.execute(text("""
                    DELETE FROM resultados_chispazo
                    WHERE balota1 = 0 AND concurso < :prox_concurso;
                """), {"prox_concurso": prox_concurso})

            insert_sql = """
                INSERT INTO resultados_chispazo (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balotaroja,
                    created_at, updated_at
                ) VALUES %s
                ON CONFLICT (concurso) DO UPDATE SET
                    loteria_id = EXCLUDED.loteria_id,
                    sorteo = EXCLUDED.sorteo,
                    fecha = EXCLUDED.fecha,
                    balota1 = EXCLUDED.balota1,
                    balota2 = EXCLUDED.balota2,
                    balota3 = EXCLUDED.balota3,
                    balota4 = EXCLUDED.balota4,
                    balota5 = EXCLUDED.balota5,
                    balotaroja = EXCLUDED.balotaroja,
                    updated_at = CURRENT_TIMESTAMP;
            """

            data_tuples = [
                (
                    int(r['concurso']),
                    int(r['loteria_id']),
                    str(r['sorteo']),
                    str(r['fecha']),
                    int(r['balota1']),
                    int(r['balota2']),
                    int(r['balota3']),
                    int(r['balota4']),
                    int(r['balota5']),
                    int(r['balotaroja'])
                )
                for r in df_to_save.to_dict(orient='records')
            ]

            raw_conn = self.engine.raw_connection()
            try:
                chunk_size = 500
                for i in range(0, len(data_tuples), chunk_size):
                    chunk = data_tuples[i:i + chunk_size]
                    with raw_conn.cursor() as cur:
                        execute_values(
                            cur, insert_sql, chunk,
                            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                        )
                    raw_conn.commit()
            finally:
                raw_conn.close()

            print(f"✅ Resultados de Chispazo guardados exitosamente! Total filas procesadas: {len(df_to_save)}")
            self.actualizar_jackpot(proxima_fecha_str, jackpot_final)

            return {
                "hubo_sorteo": True,
                "ultimo_sorteo": f"#{ultimo_concurso} ({ultima_fecha_real.strftime('%d/%m/%Y')})",
                "proximo_esperado": f"#{prox_concurso} ({proxima_fecha.strftime('%d/%m/%Y')} - {prox_modalidad})"
            }

        except Exception as e:
            print(f"❌ Error guardando resultados de Chispazo en PostgreSQL: {e}")
            raise e

if __name__ == "__main__":
    scraper = ChispazoScraper()
    scraper.run(backfill=False)
