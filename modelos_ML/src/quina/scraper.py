import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import pandas as pd
import concurrent.futures
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text, Integer, Date, String
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class QuinaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 20
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "pt-BR,pt;q=0.9,es;q=0.8,en;q=0.7",
        }
        self.url_caixa = "https://servicebus2.caixa.gov.br/portaldeloterias/api/quina"

    def _parse_fecha(self, text_raw: str) -> str:
        """Parsea fechas en formato 'DD/MM/YYYY' o 'YYYY-MM-DD' a 'YYYY-MM-DD'."""
        if not text_raw:
            return None
        text_clean = str(text_raw).strip()
        
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
        Los sorteos de Quina se realizan de Lunes a Sábado (se excluye el Domingo: weekday 6).
        """
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() == 6:
            candidate += timedelta(days=1)
        return candidate

    def extraer_ultimo_caixa(self) -> tuple[dict, str, int]:
        """Obtiene el último sorteo, premio y número de concurso desde la API de Caixa."""
        print(f"➡️ Consultando último sorteo oficial de Quina en Caixa API...")
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=10, verify=False)
            if r.status_code == 200:
                data = r.json()
                concurso_actual = data.get("numero")
                fecha_str = self._parse_fecha(data.get("dataApuracao"))
                dezenas = data.get("listaDezenas", [])
                
                # Premio acumulado
                premio_val = data.get("valorEstimadoProximoConcurso") or 0.0
                if premio_val > 0:
                    premio_formateado = f"R$ {premio_val:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
                else:
                    premio_formateado = "R$ 1.500.000,00"

                if fecha_str and len(dezenas) == 5:
                    balls = sorted([int(d) for d in dezenas])
                    item = {
                        "concurso": concurso_actual,
                        "loteria_id": self.loteria_id,
                        "sorteo": "Quina",
                        "fecha": fecha_str,
                        "balota1": balls[0],
                        "balota2": balls[1],
                        "balota3": balls[2],
                        "balota4": balls[3],
                        "balota5": balls[4],
                        "balotaroja": 0
                    }
                    return item, premio_formateado, concurso_actual
        except Exception as e:
            print(f"⚠️ Error al consultar Caixa API: {e}")

        return None, "R$ 1.500.000,00", None

    def _descargar_concurso_caixa(self, num_concurso: int) -> dict:
        """Descarga un concurso específico desde la API de Caixa con reintentos."""
        url = f"{self.url_caixa}/{num_concurso}"
        import time
        for _ in range(3):
            try:
                r = requests.get(url, headers=self.headers, timeout=10, verify=False)
                if r.status_code == 200:
                    d = r.json()
                    fecha_str = self._parse_fecha(d.get("dataApuracao"))
                    dezenas = d.get("listaDezenas", [])
                    if fecha_str and len(dezenas) == 5:
                        balls = sorted([int(x) for x in dezenas])
                        return {
                            "concurso": num_concurso,
                            "loteria_id": self.loteria_id,
                            "sorteo": "Quina",
                            "fecha": fecha_str,
                            "balota1": balls[0],
                            "balota2": balls[1],
                            "balota3": balls[2],
                            "balota4": balls[3],
                            "balota5": balls[4],
                            "balotaroja": 0
                        }
            except Exception:
                time.sleep(0.3)
        return None

    def extraer_historico_concurrente(self, ultimo_num: int, cantidad: int = 800) -> pd.DataFrame:
        """Descarga un lote de sorteos históricos usando hilos en paralelo."""
        if not ultimo_num:
            return pd.DataFrame()

        inicio = max(1, ultimo_num - cantidad)
        numeros = list(range(inicio, ultimo_num + 1))
        print(f"➡️ Descargando {len(numeros)} sorteos históricos de Quina concurrentemente ({inicio} a {ultimo_num})...")

        draws = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
            resultados = list(executor.map(self._descargar_concurso_caixa, numeros))

        for res in resultados:
            if res:
                draws.append(res)

        print(f"📊 Sorteos históricos procesados de Quina: {len(draws)}")
        return pd.DataFrame(draws)

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el premio de Quina en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "R$ 1.500.000,00"
        print(f"💰 Actualizando jackpot para Quina: {jackpot_val} (Fecha: {proxima_fecha})")
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
                    "loteria": "quina",
                    "fecha": proxima_fecha,
                    "jackpot": jackpot_val
                })
                conn.commit()
        except Exception as e:
            print(f"⚠️ Error actualizando jackpot para Quina: {e}")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Quina (Brasil)...")
        
        # 1. Obtener datos existentes en BD
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_quina WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        # 2. Descargar último sorteo oficial
        ultimo_item, jackpot_final, ultimo_concurso = self.extraer_ultimo_caixa()
        df_reciente = pd.DataFrame([ultimo_item]) if ultimo_item else pd.DataFrame()

        # 3. Backfill histórico si es necesario
        if backfill or df_existente.empty or len(df_existente) < 100:
            df_hist = self.extraer_historico_concurrente(ultimo_concurso, cantidad=800)
            df_scraped = pd.concat([df_reciente, df_hist], ignore_index=True)
        else:
            df_scraped = df_reciente

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Quina.")
            return

        # 4. Combinar y limpiar
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

        # 5. Calcular próximo sorteo
        ultima_fecha_real = df_combined.iloc[0]['fecha']
        proxima_fecha = self._calcular_proximo_sorteo(ultima_fecha_real)
        proxima_fecha_str = proxima_fecha.strftime("%Y-%m-%d")
        print(f"📅 Fecha del próximo sorteo agregada para Quina: {proxima_fecha_str}")

        max_concurso = df_combined['concurso'].dropna().max()
        prox_concurso = int(max_concurso) + 1 if pd.notna(max_concurso) else None

        # Fila placeholder en ceros
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": "Quina",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balotaroja": 0
        }
        df_final = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 6. Guardar en PostgreSQL (UPSERT seguro sin destruir la tabla)
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_quina (
                    id SERIAL PRIMARY KEY,
                    concurso INTEGER,
                    loteria_id INTEGER DEFAULT 20 REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INTEGER NOT NULL,
                    balota2 INTEGER NOT NULL,
                    balota3 INTEGER NOT NULL,
                    balota4 INTEGER NOT NULL,
                    balota5 INTEGER NOT NULL,
                    balotaroja INTEGER NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_quina_fecha_sorteo ON resultados_quina (fecha, sorteo);
                CREATE INDEX IF NOT EXISTS idx_quina_concurso ON resultados_quina (concurso);
                CREATE INDEX IF NOT EXISTS idx_quina_loteria_id ON resultados_quina (loteria_id);
            """))

        insert_sql = """
            INSERT INTO resultados_quina (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balotaroja,
                created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo) DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_quina.concurso),
                loteria_id = EXCLUDED.loteria_id,
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
                int(r['concurso']) if pd.notna(r.get('concurso')) and r.get('concurso') else None,
                int(self.loteria_id),
                str(r['sorteo']),
                str(r['fecha']),
                int(r['balota1']),
                int(r['balota2']),
                int(r['balota3']),
                int(r['balota4']),
                int(r['balota5']),
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
                        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ Resultados de Quina guardados exitosamente! Total filas: {len(df_final)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_final)
        return True

if __name__ == "__main__":
    scraper = QuinaScraper()
    scraper.run(backfill=True)
