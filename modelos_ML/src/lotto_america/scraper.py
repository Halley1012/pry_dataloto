import sys
import time
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
import requests
from bs4 import BeautifulSoup
from urllib.parse import parse_qs, urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class LottoAmericaScraper:
    def __init__(self):
        self.base_url = "https://www.powerball.com/es/sorteos-anteriores"
        self.game_code = "lotto-america"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "X-Requested-With": "XMLHttpRequest"
        }
        self.draw_days = (0, 2, 5) # Lunes, Miércoles, Sábados

    def update_jackpot(self, engine, loteria, jackpot, fecha_str):
        if not jackpot or not fecha_str:
            return
        fecha = None
        try:
            fecha = datetime.strptime(fecha_str.strip(), "%a, %b %d, %Y").date()
        except Exception:
            try:
                fecha = pd.to_datetime(fecha_str).date()
            except Exception as ex:
                print(f"Error parsing date {fecha_str} for {loteria}: {ex}")
        
        if not fecha:
            return
        
        from sqlalchemy import text
        try:
            with engine.connect() as conn:
                print(f"Updating jackpot for {loteria}: {jackpot} (Fecha: {fecha})")
                conn.execute(text("""
                    INSERT INTO loterias_jackpots (loteria, fecha, jackpot, updated_at)
                    VALUES (:loteria, :fecha, :jackpot, CURRENT_TIMESTAMP)
                    ON CONFLICT (loteria, fecha) DO UPDATE
                    SET jackpot = EXCLUDED.jackpot,
                        updated_at = EXCLUDED.updated_at;
                """), {"loteria": loteria, "fecha": fecha, "jackpot": jackpot})
                
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": loteria})
                conn.commit()
        except Exception as e:
            print(f"Error updating jackpot for {loteria} in DB: {e}")

    def run(self, max_pages=None):
        print("🚀 Iniciando Scraping de Lotto America...")
        df_final = pd.DataFrame()
        resultados = []

        pagina = 1
        while True:
            if max_pages is not None and pagina > max_pages:
                print(f"🛑 Se alcanzó el límite máximo de páginas especificado ({max_pages}).")
                break
            print(f"➡️ Scrapeando página {pagina} de Lotto America...")
            params = {"gc": self.game_code, "pg": pagina}
            response = None
            max_intentos = 3

            for intento in range(max_intentos):
                try:
                    response = requests.get(self.base_url, params=params, headers=self.headers, timeout=15)
                    if response.status_code == 200:
                        break
                except requests.exceptions.RequestException as e:
                    if intento < max_intentos - 1:
                        wait = (intento + 1) * 3
                        print(f"🔄 Error de conexión en pág {pagina} ({e}). Reintentando en {wait}s...")
                        time.sleep(wait)

            if not response or response.status_code != 200:
                print(f"⚠️ Saltando página {pagina} por error de respuesta.")
                break

            soup = BeautifulSoup(response.text, "html.parser")
            cards = soup.select("a.card")
            if not cards:
                print(f"📄 No se encontraron más tarjetas en la página {pagina}. Finalizando recorrido.")
                break

            for card in cards:
                href = card.get("href", "")
                parsed_url = urlparse(href)
                query_params = parse_qs(parsed_url.query)
                
                fecha_str = query_params.get("date", [None])[0]
                if not fecha_str:
                    continue

                ball_group = card.select_one(".game-ball-group")
                if not ball_group:
                    continue

                ball_divs = ball_group.select(".form-control div")
                numeros = []
                for b in ball_divs:
                    txt = b.get_text(strip=True)
                    if txt.isdigit():
                        numeros.append(int(txt))

                if len(numeros) == 6:
                    resultados.append(["Lotto America", fecha_str] + numeros)

            pagina += 1
            time.sleep(0.5)

        if resultados:
            df = pd.DataFrame(resultados, columns=["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"])
            df['fecha'] = pd.to_datetime(df['fecha'], errors='coerce')
            df = df.drop_duplicates(subset=['fecha']).reset_index(drop=True)
            df_final = df
        else:
            print("❌ No se lograron recuperar registros históricos de Lotto America.")
            return

        try:
            fecha_max_hist = df_final['fecha'].max()
            cur_date = fecha_max_hist + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)

            df_prox = pd.DataFrame({
                'sorteo': ['Lotto America'],
                'fecha': [cur_date],
                'balota1': [0], 'balota2': [0], 'balota3': [0], 'balota4': [0], 'balota5': [0],
                'balotaroja': [0]
            })
            df_final = pd.concat([df_final, df_prox], ignore_index=True)
            print(f"📅 Fecha del próximo sorteo agregada para Lotto America: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Lotto America: {e}")

        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True)

        try:
            from sqlalchemy.types import Date
            engine = get_engine()

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                import pandas as pd
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_lotto_america")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_lotto_america', engine, if_exists='replace', index=False, dtype={'fecha': Date()})
            print(f"✅ ¡DataFrame de Lotto America guardado exitosamente! Total filas: {len(df_final)}")

            # Scrape and save jackpot for Lotto America from powerball.com/lotto-america
            print("💰 Scrapeando jackpot para Lotto America...")
            r_main = requests.get("https://www.powerball.com/lotto-america", headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}, timeout=15)
            if r_main.status_code == 200:
                soup_main = BeautifulSoup(r_main.text, "html.parser")
                date_el = soup_main.find(class_="title-date")
                fecha_str = date_el.get_text(strip=True) if date_el else None
                jackpot_el = soup_main.find(class_="game-jackpot-number")
                jackpot = jackpot_el.get_text(strip=True) if jackpot_el else None
                
                if jackpot and fecha_str:
                    self.update_jackpot(engine, "lotto_america", jackpot, fecha_str)
                else:
                    print("⚠️ No se encontró jackpot o fecha en powerball.com/lotto-america")
            else:
                print(f"⚠️ Error consultando powerball.com/lotto-america: Status {r_main.status_code}")
        except Exception as e:
            print(f"❌ Error al guardar datos o jackpot de Lotto America en BD: {e}")


if __name__ == "__main__":
    LottoAmericaScraper().run()
