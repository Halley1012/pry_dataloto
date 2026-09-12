import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import pandas as pd
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
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

    def _fetch_with_retries(self, url: str, max_retries: int = 3, base_delay: float = 1.5) -> dict:
        """Realiza una petición HTTP con hasta max_retries reintentos y retroceso exponencial (backoff).
        Nunca silencia errores definitivos.
        """
        import time
        last_error = None
        for attempt in range(1, max_retries + 1):
            try:
                r = requests.get(url, headers=self.headers, timeout=10)
                if r.status_code == 200:
                    return r.json()
                elif r.status_code == 404:
                    return None
                else:
                    last_error = f"HTTP {r.status_code}"
                    print(f"⚠️ [+Milionária] URL {url} - intento {attempt}/{max_retries}: {last_error}")
            except Exception as e:
                last_error = str(e)
                print(f"⚠️ [+Milionária] URL {url} - intento {attempt}/{max_retries}: {last_error}")

            if attempt < max_retries:
                sleep_time = base_delay * (2 ** (attempt - 1))
                time.sleep(sleep_time)

        print(f"❌ [+Milionária] Error definitivo consultando {url} tras {max_retries} intentos: {last_error}")
        return None

    def _parse_fecha(self, text_raw: str) -> str:
        """Parsea fechas en formato 'DD/MM/YYYY' o 'YYYY-MM-DD'."""
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
        """FALLBACK DE CALENDARIO EXCLUSIVO:
        Se invoca ÚNICAMENTE si la fuente oficial (Caixa) no declara explícitamente
        la fecha del próximo sorteo en su respuesta JSON.
        Nunca se utiliza para extraer ni descartar sorteos históricos reales.
        Los sorteos de +Milionária se realizan habitualmente los Miércoles (2) y Sábados (5).
        """
        draw_days = (2, 5)
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in draw_days:
            candidate += timedelta(days=1)
        return candidate

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo real guardado en la base de datos (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, balota1, balota2, balota3, balota4, balota5, balota6, balotaroja, balotaroja2
                    FROM resultados_maismilionaria
                    WHERE balota1 > 0
                    ORDER BY concurso DESC, fecha DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "concurso": row[0],
                        "fecha": row[1],
                        "balotas": [row[2], row[3], row[4], row[5], row[6], row[7]],
                        "trevos": [row[8], row[9]]
                    }
        except Exception as e:
            print(f"⚠️ Error obteniendo último sorteo de BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        """Obtiene la información del último sorteo disponible en la API oficial de Caixa con reintentos."""
        data = self._fetch_with_retries(self.url_caixa, max_retries=3)
        if data:
            try:
                concurso = int(data.get("numero")) if data.get("numero") else None
                fecha_raw = data.get("dataApuracao")
                fecha_str = self._parse_fecha(fecha_raw)
                
                dezenas_ordem = data.get("dezenasSorteadasOrdemSorteio") or []
                lista_dezenas = data.get("listaDezenas") or []
                trevos = data.get("trevosSorteados") or []

                if len(dezenas_ordem) >= 8:
                    balls = [int(x) for x in dezenas_ordem[:6]]
                    tr = [int(x) for x in dezenas_ordem[6:8]]
                else:
                    balls = [int(x) for x in lista_dezenas[:6]] if len(lista_dezenas) >= 6 else []
                    tr = [int(x) for x in trevos[:2]] if len(trevos) >= 2 else [1, 2]

                prox_raw = data.get("dataProximoConcurso")
                prox_fecha = self._parse_fecha(prox_raw) if prox_raw else None
                prox_concurso = int(data.get("numeroConcursoProximo")) if data.get("numeroConcursoProximo") else (concurso + 1 if concurso else None)
                
                jackpot_val = data.get("valorEstimadoProximoConcurso")
                jackpot_str = "R$ 92.000.000,00"
                if jackpot_val:
                    try:
                        jackpot_str = f"R$ {jackpot_val:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
                    except Exception:
                        pass

                return {
                    "concurso": concurso,
                    "fecha": fecha_str,
                    "balotas": balls,
                    "trevos": tr,
                    "proxima_fecha": prox_fecha,
                    "proximo_concurso": prox_concurso,
                    "jackpot": jackpot_str,
                    "raw_data": data
                }
            except Exception as e:
                print(f"⚠️ Error parseando respuesta oficial de Caixa (+Milionária): {e}")
        return None

    def extraer_recientes(self) -> tuple[pd.DataFrame, str, str]:
        """Extrae el sorteo más reciente desde la API oficial de Caixa preservando orden original."""
        print(f"➡️ Solicitando resultados recientes de +Milionária...")
        draws = []
        jackpot_destacado = "R$ 92.000.000,00"
        proxima_fecha_oficial = None

        fuente_info = self.extraer_ultimo_sorteo_fuente()
        if fuente_info and fuente_info.get("balotas") and fuente_info.get("trevos"):
            balls = fuente_info["balotas"]
            tr = fuente_info["trevos"]
            jackpot_destacado = fuente_info.get("jackpot", jackpot_destacado)
            proxima_fecha_oficial = fuente_info.get("proxima_fecha")
            c_num = fuente_info.get("concurso")
            f_str = fuente_info.get("fecha")

            draws.append({
                "concurso": c_num,
                "loteria_id": self.loteria_id,
                "sorteo": "+Milionária",
                "fecha": f_str,
                "balota1": balls[0],
                "balota2": balls[1],
                "balota3": balls[2],
                "balota4": balls[3],
                "balota5": balls[4],
                "balota6": balls[5],
                "balotaroja": tr[0],
                "balotaroja2": tr[1]
            })
            print(f"✅ Último sorteo obtenido: Concurso {c_num} ({f_str}) -> Números: {balls}, Tréboles: {tr}")

        df = pd.DataFrame(draws)
        return df, jackpot_destacado, proxima_fecha_oficial

    def _descargar_concurso_caixa(self, num_concurso: int) -> dict:
        """Descarga un concurso específico desde la API de Caixa preservando orden original."""
        url = f"{self.url_caixa}/{num_concurso}"
        d = self._fetch_with_retries(url, max_retries=3, base_delay=1.0)
        if d:
            try:
                fecha_str = self._parse_fecha(d.get("dataApuracao"))
                dezenas_ordem = d.get("dezenasSorteadasOrdemSorteio") or []
                lista_dezenas = d.get("listaDezenas") or []
                trevos = d.get("trevosSorteados") or []

                if len(dezenas_ordem) >= 8:
                    balls = [int(x) for x in dezenas_ordem[:6]]
                    tr = [int(x) for x in dezenas_ordem[6:8]]
                else:
                    balls = [int(x) for x in lista_dezenas[:6]] if len(lista_dezenas) >= 6 else []
                    tr = [int(x) for x in trevos[:2]] if len(trevos) >= 2 else [1, 2]

                if fecha_str and len(balls) == 6 and len(tr) == 2:
                    return {
                        "concurso": num_concurso,
                        "loteria_id": self.loteria_id,
                        "sorteo": "+Milionária",
                        "fecha": fecha_str,
                        "balota1": balls[0],
                        "balota2": balls[1],
                        "balota3": balls[2],
                        "balota4": balls[3],
                        "balota5": balls[4],
                        "balota6": balls[5],
                        "balotaroja": tr[0],
                        "balotaroja2": tr[1]
                    }
            except Exception as e:
                print(f"⚠️ Error parseando concurso #{num_concurso} de +Milionária: {e}")
        return None

    def extraer_historico_completo(self) -> pd.DataFrame:
        """Descarga todos los sorteos históricos de +Milionária (desde el concurso 1)."""
        print("📚 Iniciando extracción histórica completa de +Milionária...")
        ultimo_sorteo_num = 387
        fuente_info = self.extraer_ultimo_sorteo_fuente()
        if fuente_info and fuente_info.get("concurso"):
            ultimo_sorteo_num = fuente_info["concurso"]

        sorteos_a_consultar = list(range(1, ultimo_sorteo_num + 1))
        print(f"⏳ Descargando {len(sorteos_a_consultar)} sorteos históricos (del 1 al {ultimo_sorteo_num})...")

        results = []
        fallidos = []
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = {executor.submit(self._descargar_concurso_caixa, num): num for num in sorteos_a_consultar}
            for f in as_completed(futures):
                c_num = futures[f]
                res = f.result()
                if res:
                    results.append(res)
                else:
                    fallidos.append(c_num)

        if fallidos:
            print(f"⚠️ Sorteos no extraídos en el backfill ({len(fallidos)}): {sorted(fallidos)[:10]}")

        df = pd.DataFrame(results)
        print(f"📊 Total sorteos históricos extraídos con éxito: {len(df)}")
        return df

    def actualizar_jackpot(self, proxima_fecha: str, jackpot_str: str = None):
        """Actualiza el premio de +Milionária en la tabla loterias_jackpots."""
        jackpot_val = jackpot_str or "R$ 91.000.000,00"
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

    def _asegurar_placeholder(self, fuente_info: dict, db_ultimo: dict):
        """Limpia placeholders obsoletos y asegura el placeholder futuro en ceros."""
        prox_fecha = fuente_info.get("proxima_fecha") if fuente_info else None
        prox_concurso = fuente_info.get("proximo_concurso") if fuente_info else None

        if not prox_fecha and db_ultimo and db_ultimo.get("fecha"):
            prox_date_obj = self._calcular_proximo_sorteo(db_ultimo["fecha"])
            prox_fecha = prox_date_obj.strftime("%Y-%m-%d")
        if not prox_concurso and db_ultimo and db_ultimo.get("concurso"):
            prox_concurso = db_ultimo["concurso"] + 1

        if not prox_fecha:
            return

        with self.engine.begin() as conn:
            # Limpiar placeholders pasados de forma segura
            conn.execute(text("""
                DELETE FROM resultados_maismilionaria
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": prox_fecha})

            # Insertar o actualizar placeholder para el próximo sorteo
            conn.execute(text("""
                INSERT INTO resultados_maismilionaria (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balota6,
                    balotaroja, balotaroja2,
                    created_at, updated_at
                ) VALUES (
                    :concurso, :loteria_id, '+Milionária', :fecha,
                    0, 0, 0, 0, 0, 0, 0, 0,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
                ON CONFLICT (fecha, sorteo) DO UPDATE SET
                    concurso = COALESCE(EXCLUDED.concurso, resultados_maismilionaria.concurso),
                    balota1 = 0, balota2 = 0, balota3 = 0,
                    balota4 = 0, balota5 = 0, balota6 = 0,
                    balotaroja = 0, balotaroja2 = 0,
                    updated_at = CURRENT_TIMESTAMP;
            """), {
                "concurso": prox_concurso,
                "loteria_id": self.loteria_id,
                "fecha": prox_fecha
            })

        print(f"🎯 Placeholder verificado para Concurso #{prox_concurso} ({prox_fecha})")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de +Milionária (Brasil)...")
        
        # 1. Asegurar tabla e índices
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
                    balotaroja INTEGER NOT NULL DEFAULT 0,
                    balotaroja2 INTEGER NOT NULL DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_maismilionaria_fecha_sorteo ON resultados_maismilionaria (fecha, sorteo);
                CREATE INDEX IF NOT EXISTS idx_maismilionaria_concurso ON resultados_maismilionaria (concurso);
                CREATE INDEX IF NOT EXISTS idx_maismilionaria_loteria_id ON resultados_maismilionaria (loteria_id);
            """))

        # 2. Detección temprana
        db_ultimo = self.obtener_ultimo_sorteo_db()
        fuente_info = self.extraer_ultimo_sorteo_fuente()

        if not fuente_info and not backfill:
            raise RuntimeError("❌ No se pudo conectar con la API oficial de Caixa (+Milionária) tras 3 intentos. Fallo real de servicio.")

        if not backfill and fuente_info and db_ultimo:
            concurso_fuente = fuente_info.get("concurso")
            fecha_fuente = fuente_info.get("fecha")
            concurso_db = db_ultimo.get("concurso")
            fecha_db = str(db_ultimo.get("fecha"))

            # Si el último concurso o fecha de la fuente ya existe en la BD
            if (concurso_fuente and concurso_db and concurso_fuente <= concurso_db) or (fecha_fuente and fecha_db and fecha_fuente <= fecha_db):
                print(f"\nℹ️ [DETECCIÓN TEMPRANA] No hay sorteos nuevos para +Milionária.")
                print(f"  Último sorteo en fuente: Concurso #{concurso_fuente} ({fecha_fuente})")
                print(f"  Último sorteo en BD:     Concurso #{concurso_db} ({fecha_db})")
                
                # Actualizar jackpot y placeholder
                prox_fecha = fuente_info.get("proxima_fecha")
                if prox_fecha:
                    self.actualizar_jackpot(prox_fecha, fuente_info.get("jackpot"))
                self._asegurar_placeholder(fuente_info, db_ultimo)

                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"Concurso #{concurso_db} ({fecha_db})",
                    "proximo_esperado": f"Concurso #{fuente_info.get('proximo_concurso')} ({prox_fecha})"
                }

        # 3. Descarga de datos
        df_existente = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                df_existente = pd.read_sql(text("SELECT * FROM resultados_maismilionaria WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        df_recientes, jackpot_reciente, prox_fecha_oficial = self.extraer_recientes()
        if backfill or df_existente.empty or len(df_existente) < 50:
            df_historico = self.extraer_historico_completo()
            df_scraped = pd.concat([df_recientes, df_historico], ignore_index=True)
        else:
            df_scraped = df_recientes

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de +Milionária.")
            return False

        # Combinar y limpiar
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
            return False

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
            "balota1": 0, "balota2": 0, "balota3": 0,
            "balota4": 0, "balota5": 0, "balota6": 0,
            "balotaroja": 0, "balotaroja2": 0
        }

        # Determinar qué guardar: si no es backfill, guardar solo lo nuevo + placeholder
        if not backfill and not df_existente.empty:
            fechas_existentes = set(pd.to_datetime(df_existente['fecha']).dt.date)
            df_nuevos = df_combined[~df_combined['fecha'].isin(fechas_existentes)]
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_nuevos], ignore_index=True)
        else:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 5. Limpieza segura de placeholders obsoletos
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_maismilionaria
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": proxima_fecha})

        # 6. Guardar en PostgreSQL (UPSERT seguro)
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
                int(r.get('balotaroja', 0)),
                int(r.get('balotaroja2', 0))
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
                        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                raw_conn.commit()
        finally:
            raw_conn.close()

        print(f"✅ Resultados de +Milionária guardados exitosamente! Filas procesadas: {len(df_to_save)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_reciente)
        return True

if __name__ == "__main__":
    scraper = MaisMilionariaScraper()
    scraper.run(backfill=False)
