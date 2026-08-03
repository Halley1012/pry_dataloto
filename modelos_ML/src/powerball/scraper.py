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

class PowerballScraper:
    def __init__(self):
        self.base_url = "https://www.powerball.com/es/sorteos-anteriores"
        self.game_code = "powerball"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "X-Requested-With": "XMLHttpRequest"
        }
        # Sorteos: Lunes (0), Miércoles (2), Sábados (5)
        self.draw_days = (0, 2, 5)

    def run(self, max_pages=30):
        print("🚀 Iniciando Scraping de Powerball...")
        df_final = pd.DataFrame()
        resultados = []

        for pagina in range(1, max_pages + 1):
            print(f"➡️ Scrapeando página {pagina} de Powerball...")
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
                    resultados.append(["Powerball", fecha_str] + numeros)

            time.sleep(0.5)

        if resultados:
            df = pd.DataFrame(resultados, columns=["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"])
            df['fecha'] = pd.to_datetime(df['fecha'], errors='coerce')
            df = df.drop_duplicates(subset=['fecha']).reset_index(drop=True)
            df_final = df
        else:
            print("❌ No se lograron recuperar registros históricos de Powerball.")
            return

        # --- Agregar fila del próximo sorteo en cero ---
        try:
            fecha_max_hist = df_final['fecha'].max()
            cur_date = fecha_max_hist + timedelta(days=1)
            while cur_date.weekday() not in self.draw_days:
                cur_date += timedelta(days=1)

            df_prox = pd.DataFrame({
                'sorteo': ['Powerball'],
                'fecha': [cur_date],
                'balota1': [0], 'balota2': [0], 'balota3': [0], 'balota4': [0], 'balota5': [0],
                'balotaroja': [0]
            })
            df_final = pd.concat([df_final, df_prox], ignore_index=True)
            print(f"📅 Fecha del próximo sorteo agregada para Powerball: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Powerball: {e}")

        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True)

        try:
            from sqlalchemy.types import Date
            engine = get_engine()
            df_final.to_sql('resultados_powerball', engine, if_exists='replace', index=False, dtype={'fecha': Date()})
            print(f"✅ ¡DataFrame de Powerball guardado exitosamente! Total filas: {len(df_final)}")
        except Exception as e:
            print(f"❌ Error al guardar datos de Powerball en BD: {e}")

if __name__ == "__main__":
    PowerballScraper().run()
