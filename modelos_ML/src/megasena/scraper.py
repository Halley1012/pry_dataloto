import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import pandas as pd
from bs4 import BeautifulSoup
from datetime import datetime, timedelta, date
from pathlib import Path
from sqlalchemy import text
from concurrent.futures import ThreadPoolExecutor, as_completed
from psycopg2.extras import execute_values

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from config.database import get_engine

class MegaSenaScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 21
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

    def obtener_ultimo_sorteo_db(self) -> dict:
        """Obtiene el último sorteo real guardado en la base de datos (balota1 > 0)."""
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT concurso, fecha, balota1, balota2, balota3, balota4, balota5, balota6
                    FROM resultados_megasena
                    WHERE balota1 > 0
                    ORDER BY concurso DESC, fecha DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "concurso": row[0],
                        "fecha": row[1],
                        "balotas": [row[2], row[3], row[4], row[5], row[6], row[7]]
                    }
        except Exception as e:
            print(f"⚠️ Error obteniendo último sorteo de BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        """Obtiene la información del último sorteo disponible en la API oficial de Caixa."""
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=10)
            if r.status_code == 200:
                data = r.json()
                concurso = int(data.get("numero")) if data.get("numero") else None
                fecha_raw = data.get("dataApuracao")
                fecha_str = self._parse_fecha(fecha_raw)
                
                # Priorizar orden natural de extracción de balotas
                dezenas = data.get("dezenasSorteadasOrdemSorteio")
                if not dezenas or len(dezenas) < 6:
                    dezenas = data.get("listaDezenas")
                balls = [int(d) for d in dezenas[:6]] if dezenas and len(dezenas) >= 6 else []

                prox_raw = data.get("dataProximoConcurso")
                prox_fecha = self._parse_fecha(prox_raw) if prox_raw else None
                prox_concurso = int(data.get("numeroConcursoProximo")) if data.get("numeroConcursoProximo") else (concurso + 1 if concurso else None)
                
                jackpot_val = data.get("valorEstimadoProximoConcurso")
                jackpot_str = "R$ 48.000.000"
                if jackpot_val:
                    try:
                        jackpot_str = f"R$ {jackpot_val:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
                    except Exception:
                        pass

                return {
                    "concurso": concurso,
                    "fecha": fecha_str,
                    "balotas": balls,
                    "proxima_fecha": prox_fecha,
                    "proximo_concurso": prox_concurso,
                    "jackpot": jackpot_str,
                    "raw_data": data
                }
        except Exception as e:
            print(f"⚠️ Error consultando API Caixa para último sorteo: {e}")
        return None

    def extraer_recientes(self) -> tuple[pd.DataFrame, str, str]:
        """Extrae el sorteo más reciente desde la API oficial de Caixa y megasena.com preservando orden original."""
        print(f"➡️ Solicitando resultados recientes de Mega-Sena...")
        draws = []
        jackpot_destacado = "R$ 48.000.000"
        proxima_fecha_oficial = None

        # 1. Consultar API oficial de Caixa
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=10)
            if r.status_code == 200:
                data = r.json()
                fecha_raw = data.get("dataApuracao")
                dezenas = data.get("dezenasSorteadasOrdemSorteio")
                if not dezenas or len(dezenas) < 6:
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

                if dezenas and len(dezenas) >= 6 and fecha_str:
                    balls = [int(d) for d in dezenas[:6]] # Preservar orden natural de extracción
                    draws.append({
                        "concurso": int(data.get('numero')) if data.get('numero') else None,
                        "loteria_id": self.loteria_id,
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
                            draw_div = tds[0].find("div", class_="draw-number")
                            c_num = int(re.search(r'(\d+)', draw_div.get_text()).group(1)) if draw_div and re.search(r'(\d+)', draw_div.get_text()) else None
                            date_div = tds[0].find("div", class_="date")
                            date_raw = date_div.get_text(strip=True) if date_div else tds[0].get_text(strip=True)
                            fecha_str = self._parse_fecha(date_raw)
                            balls = [int(b.get_text(strip=True)) for b in tds[1].find_all(['li', 'span', 'div']) if b.get_text(strip=True).isdigit()]
                            if len(balls) == 6 and fecha_str:
                                # Preservar orden original sin sorted()
                                draws.append({
                                    "concurso": c_num,
                                    "loteria_id": self.loteria_id,
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
        Descarga sorteos históricos mediante la API oficial de Caixa preservando el orden de extracción.
        """
        print("📚 Iniciando extracción histórica completa de Mega-Sena...")
        
        ultimo_sorteo_num = 3053
        try:
            r = requests.get(self.url_caixa, headers=self.headers, timeout=8)
            if r.status_code == 200:
                data = r.json()
                ultimo_sorteo_num = int(data.get("numero", 3053))
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
                    dezenas = d.get("dezenasSorteadasOrdemSorteio")
                    if not dezenas or len(dezenas) < 6:
                        dezenas = d.get("listaDezenas")
                    fecha_str = self._parse_fecha(fecha_raw)
                    if dezenas and len(dezenas) >= 6 and fecha_str:
                        balls = [int(x) for x in dezenas[:6]] # Sin sorted()
                        return {
                            "concurso": num,
                            "loteria_id": self.loteria_id,
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
        jackpot_val = jackpot_str or "R$ 48.000.000"
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
            # Limpiar placeholders pasados de forma segura (NUNCA borrar sorteos reales)
            conn.execute(text("""
                DELETE FROM resultados_megasena
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": prox_fecha})

            # Insertar o actualizar placeholder para el próximo sorteo
            conn.execute(text("""
                INSERT INTO resultados_megasena (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balota6,
                    created_at, updated_at
                ) VALUES (
                    :concurso, :loteria_id, 'Mega-Sena', :fecha,
                    0, 0, 0, 0, 0, 0,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
                ON CONFLICT (fecha, sorteo) DO UPDATE SET
                    concurso = COALESCE(EXCLUDED.concurso, resultados_megasena.concurso),
                    balota1 = 0, balota2 = 0, balota3 = 0,
                    balota4 = 0, balota5 = 0, balota6 = 0,
                    updated_at = CURRENT_TIMESTAMP;
            """), {
                "concurso": prox_concurso,
                "loteria_id": self.loteria_id,
                "fecha": prox_fecha
            })

        print(f"🎯 Placeholder verificado para Concurso #{prox_concurso} ({prox_fecha})")

    def run(self, backfill: bool = False):
        print("🚀 Iniciando Scraping de Mega-Sena (Brasil)...")
        
        # 1. Asegurar tabla e índices
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_megasena (
                    id SERIAL PRIMARY KEY,
                    concurso INTEGER,
                    loteria_id INTEGER DEFAULT 21 REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INTEGER NOT NULL,
                    balota2 INTEGER NOT NULL,
                    balota3 INTEGER NOT NULL,
                    balota4 INTEGER NOT NULL,
                    balota5 INTEGER NOT NULL,
                    balota6 INTEGER NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_megasena_fecha_sorteo ON resultados_megasena (fecha, sorteo);
                CREATE INDEX IF NOT EXISTS idx_megasena_concurso ON resultados_megasena (concurso);
                CREATE INDEX IF NOT EXISTS idx_megasena_loteria_id ON resultados_megasena (loteria_id);
            """))

        # 2. Detección temprana
        db_ultimo = self.obtener_ultimo_sorteo_db()
        fuente_info = self.extraer_ultimo_sorteo_fuente()

        if not backfill and fuente_info and db_ultimo:
            concurso_fuente = fuente_info.get("concurso")
            fecha_fuente = fuente_info.get("fecha")
            concurso_db = db_ultimo.get("concurso")
            fecha_db = str(db_ultimo.get("fecha"))

            # Si el último concurso o fecha de la fuente ya existe en la BD
            if (concurso_fuente and concurso_db and concurso_fuente <= concurso_db) or (fecha_fuente and fecha_db and fecha_fuente <= fecha_db):
                print(f"\nℹ️ [DETECCIÓN TEMPRANA] No hay sorteos nuevos para Mega-Sena.")
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
                df_existente = pd.read_sql(text("SELECT * FROM resultados_megasena WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        df_recientes, jackpot_reciente, prox_fecha_oficial = self.extraer_recientes()
        if backfill or df_existente.empty or len(df_existente) < 50:
            df_historico = self.extraer_historico_completo(total_sorteos=800)
            df_scraped = pd.concat([df_recientes, df_historico], ignore_index=True)
        else:
            df_scraped = df_recientes

        if df_scraped.empty and df_existente.empty:
            print("❌ No se pudieron obtener resultados de Mega-Sena.")
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
        print(f"📅 Fecha del próximo sorteo agregada para Mega-Sena: {proxima_fecha_str}")

        max_concurso = df_combined['concurso'].dropna().max()
        prox_concurso = int(max_concurso) + 1 if pd.notna(max_concurso) else None

        # Fila placeholder en ceros
        fila_proximo = {
            "concurso": prox_concurso,
            "loteria_id": self.loteria_id,
            "sorteo": "Mega-Sena",
            "fecha": proxima_fecha,
            "balota1": 0,
            "balota2": 0,
            "balota3": 0,
            "balota4": 0,
            "balota5": 0,
            "balota6": 0
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
                DELETE FROM resultados_megasena
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": proxima_fecha})

        # 6. Guardar en PostgreSQL (UPSERT seguro)
        insert_sql = """
            INSERT INTO resultados_megasena (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5, balota6,
                created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo) DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_megasena.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                balota6 = EXCLUDED.balota6,
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
                int(r['balota6'])
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

        print(f"✅ Resultados de Mega-Sena guardados exitosamente! Filas procesadas: {len(df_to_save)}")
        self.actualizar_jackpot(proxima_fecha_str, jackpot_reciente)
        return True

if __name__ == "__main__":
    scraper = MegaSenaScraper()
    scraper.run(backfill=False)
