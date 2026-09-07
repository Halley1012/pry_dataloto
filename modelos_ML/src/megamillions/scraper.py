import sys
import time
import json
import re
from pathlib import Path
from datetime import datetime, timedelta, date
import pandas as pd
import requests

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine
from sqlalchemy import text
from psycopg2.extras import execute_values

class MegaMillionsScraper:
    def __init__(self):
        self.engine = get_engine()
        self.loteria_id = 12
        self.api_url = "https://www.megamillions.com/cmspages/utilservice.asmx/GetDrawingPagingData"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Content-Type": "application/json; charset=utf-8"
        }
        self.draw_days = (1, 4) # Martes (1), Viernes (4)

    def _calcular_proximo_sorteo(self, ultima_fecha_real: date) -> date:
        candidate = ultima_fecha_real + timedelta(days=1)
        while candidate.weekday() not in self.draw_days:
            candidate += timedelta(days=1)
        return candidate

    def obtener_ultimo_sorteo_db(self) -> dict:
        try:
            with self.engine.connect() as conn:
                row = conn.execute(text("""
                    SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja
                    FROM resultados_megamillions
                    WHERE balota1 > 0
                    ORDER BY fecha DESC
                    LIMIT 1;
                """)).fetchone()
                if row:
                    return {
                        "fecha": row[0],
                        "balotas": [row[1], row[2], row[3], row[4], row[5]],
                        "mega_ball": row[6]
                    }
        except Exception as e:
            print(f"⚠️ Error obteniendo último sorteo de BD: {e}")
        return None

    def extraer_ultimo_sorteo_fuente(self) -> dict:
        try:
            payload = {"pageNumber": 1, "pageSize": 5, "startDate": "", "endDate": ""}
            r = requests.post(self.api_url, headers=self.headers, json=payload, timeout=10)
            if r.status_code == 200:
                d = r.json()
                raw = d.get("d")
                data = json.loads(raw) if isinstance(raw, str) else d
                draws = data.get("DrawingData", [])
                if draws:
                    first = draws[0]
                    play_date = first.get("PlayDate")
                    if play_date:
                        fecha_str = play_date[:10]
                        balls = [first.get(f"N{i}") for i in range(1, 6)]
                        mb = first.get("MBall")
                        jackpot_raw = first.get("Jackpot")
                        return {
                            "fecha": fecha_str,
                            "balotas": balls,
                            "mega_ball": mb,
                            "jackpot": jackpot_raw
                        }
        except Exception as e:
            print(f"⚠️ Error consultando megamillions.com API: {e}")
        return None

    def update_jackpot(self, engine, loteria, jackpot, fecha):
        if not jackpot or not fecha:
            return
        try:
            with engine.connect() as conn:
                print(f"💰 Actualizando jackpot para {loteria}: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": loteria, "fecha": fecha, "jackpot": jackpot})
                conn.commit()
        except Exception as e:
            print(f"Error updating jackpot for {loteria} in DB: {e}")

    def _asegurar_placeholder(self, ultima_fecha_real: date):
        prox_date = self._calcular_proximo_sorteo(ultima_fecha_real)
        prox_fecha_str = prox_date.strftime("%Y-%m-%d")

        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_megamillions
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": prox_fecha_str})

            conn.execute(text("""
                INSERT INTO resultados_megamillions (
                    concurso, loteria_id, sorteo, fecha,
                    balota1, balota2, balota3, balota4, balota5, balotaroja,
                    created_at, updated_at
                ) VALUES (
                    NULL, :loteria_id, 'Mega Millions', :fecha,
                    0, 0, 0, 0, 0, 0,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
                ON CONFLICT (fecha, sorteo) DO UPDATE SET
                    balota1 = 0, balota2 = 0, balota3 = 0,
                    balota4 = 0, balota5 = 0, balotaroja = 0,
                    updated_at = CURRENT_TIMESTAMP;
            """), {
                "loteria_id": self.loteria_id,
                "fecha": prox_fecha_str
            })

        print(f"🎯 Placeholder verificado para Mega Millions ({prox_fecha_str})")
        return prox_fecha_str

    def run(self, max_pages=None, page_size=100):
        print("🚀 Iniciando Scraping de Mega Millions...")
        
        # 1. Asegurar tabla e índices
        with self.engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS resultados_megamillions (
                    id SERIAL PRIMARY KEY,
                    concurso INT,
                    loteria_id INT REFERENCES loterias(id),
                    sorteo VARCHAR(50) NOT NULL,
                    fecha DATE NOT NULL,
                    balota1 INT NOT NULL,
                    balota2 INT NOT NULL,
                    balota3 INT NOT NULL,
                    balota4 INT NOT NULL,
                    balota5 INT NOT NULL,
                    balotaroja INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_megamillions_fecha_sorteo ON resultados_megamillions (fecha, sorteo);
            """))

        # 2. Detección temprana
        db_ultimo = self.obtener_ultimo_sorteo_db()
        fuente_info = self.extraer_ultimo_sorteo_fuente()

        if fuente_info and db_ultimo:
            fecha_fuente = str(fuente_info.get("fecha"))
            fecha_db = str(db_ultimo.get("fecha"))

            if fecha_fuente <= fecha_db:
                print(f"\nℹ️ [DETECCIÓN TEMPRANA] No hay sorteos nuevos para Mega Millions.")
                print(f"  Último sorteo en fuente: {fecha_fuente}")
                print(f"  Último sorteo en BD:     {fecha_db}")
                
                prox_f = self._asegurar_placeholder(db_ultimo["fecha"])
                if fuente_info.get("jackpot"):
                    self.update_jackpot(self.engine, "megamillions", str(fuente_info["jackpot"]), prox_f)

                return {
                    "hubo_sorteo": False,
                    "ultimo_sorteo": f"Fecha {fecha_db}",
                    "proximo_esperado": f"Fecha {prox_f}"
                }

        # 3. Scraping paginado
        existing_df = pd.DataFrame()
        try:
            with self.engine.connect() as conn:
                existing_df = pd.read_sql(text("SELECT * FROM resultados_megamillions WHERE balota1 > 0;"), conn)
        except Exception:
            pass

        pages_to_scrape = max_pages or (2 if len(existing_df) > 100 else 100)
        resultados = []
        pagina = 1
        while pagina <= pages_to_scrape:
            print(f"➡️ Solicitando datos de la página {pagina} para Mega Millions...")
            payload = {
                "pageNumber": pagina,
                "pageSize": page_size,
                "startDate": "",
                "endDate": ""
            }

            try:
                response = requests.post(self.api_url, headers=self.headers, json=payload, timeout=15)
                if response.status_code == 200:
                    data = response.json()
                    raw = data.get("d")
                    data_obj = json.loads(raw) if isinstance(raw, str) else data
                    drawing_data = data_obj.get("DrawingData", [])
                    if not drawing_data:
                        break

                    for item in drawing_data:
                        try:
                            play_date = item.get("PlayDate")
                            if not play_date:
                                continue
                            fecha_str = play_date[:10]
                            n1 = item.get("N1")
                            n2 = item.get("N2")
                            n3 = item.get("N3")
                            n4 = item.get("N4")
                            n5 = item.get("N5")
                            mb = item.get("MBall")

                            if all(x is not None for x in [n1, n2, n3, n4, n5, mb]):
                                resultados.append(["Mega Millions", fecha_str, int(n1), int(n2), int(n3), int(n4), int(n5), int(mb)])
                        except Exception:
                            continue
                else:
                    break
            except Exception as e:
                print(f"⚠️ Error en página {pagina}: {e}")
                break

            pagina += 1
            time.sleep(0.3)

        columns = ["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"]
        df_new = pd.DataFrame(resultados, columns=columns) if resultados else pd.DataFrame(columns=columns)

        if not existing_df.empty:
            df_combined = pd.concat([df_new, existing_df], ignore_index=True)
        else:
            df_combined = df_new

        if df_combined.empty:
            print("❌ No se lograron recuperar registros de Mega Millions.")
            return False

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce')
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]
        df_combined = df_combined.drop_duplicates(subset=['fecha']).sort_values(by='fecha', ascending=False).reset_index(drop=True)

        ultima_fecha_real = df_combined.iloc[0]['fecha'].date()
        prox_date = self._calcular_proximo_sorteo(ultima_fecha_real)

        fila_proximo = {
            'concurso': None,
            'loteria_id': self.loteria_id,
            'sorteo': 'Mega Millions',
            'fecha': prox_date,
            'balota1': 0, 'balota2': 0, 'balota3': 0, 'balota4': 0, 'balota5': 0,
            'balotaroja': 0
        }

        if not existing_df.empty:
            fechas_existentes = set(pd.to_datetime(existing_df['fecha']).dt.date)
            df_nuevos = df_combined[~df_combined['fecha'].dt.date.isin(fechas_existentes)]
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_nuevos], ignore_index=True)
        else:
            df_to_save = pd.concat([pd.DataFrame([fila_proximo]), df_combined], ignore_index=True)

        # 4. Limpieza segura de placeholders obsoletos
        with self.engine.begin() as conn:
            conn.execute(text("""
                DELETE FROM resultados_megamillions
                WHERE balota1 = 0 AND fecha < :cur_date;
            """), {"cur_date": prox_date})

        # 5. Guardar en PostgreSQL
        insert_sql = """
            INSERT INTO resultados_megamillions (
                concurso, loteria_id, sorteo, fecha,
                balota1, balota2, balota3, balota4, balota5,
                balotaroja, created_at, updated_at
            ) VALUES %s
            ON CONFLICT (fecha, sorteo)
            DO UPDATE SET
                concurso = COALESCE(EXCLUDED.concurso, resultados_megamillions.concurso),
                loteria_id = EXCLUDED.loteria_id,
                balota1 = EXCLUDED.balota1,
                balota2 = EXCLUDED.balota2,
                balota3 = EXCLUDED.balota3,
                balota4 = EXCLUDED.balota4,
                balota5 = EXCLUDED.balota5,
                balotaroja = EXCLUDED.balotaroja,
                updated_at = CURRENT_TIMESTAMP;
        """

        records = []
        for _, row in df_to_save.iterrows():
            c_val = int(row['concurso']) if pd.notnull(row.get('concurso')) and row.get('concurso') is not None else None
            f_val = row['fecha'].date() if hasattr(row['fecha'], 'date') else row['fecha']
            records.append((
                c_val,
                self.loteria_id,
                str(row['sorteo']),
                f_val,
                int(row['balota1']),
                int(row['balota2']),
                int(row['balota3']),
                int(row['balota4']),
                int(row['balota5']),
                int(row.get('balotaroja', 0))
            ))

        raw_conn = self.engine.raw_connection()
        try:
            with raw_conn.cursor() as cur:
                execute_values(
                    cur, insert_sql, records,
                    template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                )
            raw_conn.commit()
            print(f"✅ Resultados de Mega Millions guardados exitosamente! Total filas: {len(records)}")
        finally:
            raw_conn.close()

        return True

if __name__ == "__main__":
    MegaMillionsScraper().run()
