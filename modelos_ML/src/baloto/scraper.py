import sys
import time
import re
from pathlib import Path
from datetime import datetime
import pandas as pd
import requests
from bs4 import BeautifulSoup

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class BalotoScraper:
    def __init__(self):
        self.base_url = "https://baloto.com/resultados?page={}"
        self.headers = {"User-Agent": "Mozilla/5.0"}
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
        }
        self.meses_es_en = {
            'Enero': 'January', 'Febrero': 'February', 'Marzo': 'March', 'Abril': 'April',
            'Mayo': 'May', 'Junio': 'June', 'Julio': 'July', 'Agosto': 'August',
            'Septiembre': 'September', 'Octubre': 'October', 'Noviembre': 'November', 'Diciembre': 'December'
        }

    def convertir_fecha_manual(self, fecha_str):
        try:
            partes = fecha_str.lower().split(' de ')
            if len(partes) == 3:
                dia = partes[0].zfill(2)
                mes = self.meses[partes[1]]
                anio = partes[2]
                return f'{anio}-{mes}-{dia}'
        except Exception:
            return None

    def obtener_num_paginas(self, html):
        soup = BeautifulSoup(html, "html.parser")
        ultima_pagina = soup.find("a", string=lambda t: t and "Última" in t) #
        if ultima_pagina:
            href = ultima_pagina.get("href", "") #
            if "page=" in href: #[cite: 3]
                try:
                    return int(href.split("page=")[-1]) #[cite: 3]
                except ValueError:
                    return 1
        return 1

    def run(self):
        print("🚀 Iniciando Scraping de Baloto...")
        
        # Inicialización de df_final para evitar fallos de referencia ante errores
        df_final = pd.DataFrame()

        try:
            resp = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            if resp.status_code != 200:
                print("⚠️ No se pudo cargar la primera página:", resp.status_code) #[cite: 3]
                return
            num_paginas = self.obtener_num_paginas(resp.text)
        except Exception as e:
            print(f"❌ Error crítico al conectar a Baloto: {e}")
            return

        print(f"📄 Se detectaron {num_paginas} páginas en total.") #[cite: 3]
        resultados = []

        # Recorremos páginas con un bloque de reintentos robusto contra Timeouts
        for pagina in range(1, num_paginas + 1):
            print(f"➡️ Scrapeando página {pagina} de {num_paginas}...")
            response = None
            max_intentos = 3
            
            for intento in range(max_intentos):
                try:
                    response = requests.get(self.base_url.format(pagina), headers=self.headers, timeout=15)
                    if response.status_code == 200:
                        break
                # Cambiamos aquí para atrapar ReadTimeout, SSLError, etc.
                except requests.exceptions.RequestException as e:
                    if intento < max_intentos - 1:
                        wait = (intento + 1) * 5
                        print(f"🔄 Timeout o bloqueo de red detectado en pág {pagina} ({e}). Reintentando en {wait}s...")
                        time.sleep(wait)
                    else:
                        print(f"❌ Se agotaron los {max_intentos} intentos para la página {pagina} debido a caídas de red.")

            # Si tras los reintentos la página no respondió, la saltamos para no tumbar todo el proceso
            if not response or response.status_code != 200:
                print(f"⚠️ Saltando página {pagina} debido a error persistente de conexión.")
                continue

            try:
                soup = BeautifulSoup(response.text, "html.parser")
                filas = soup.select("table.table.table-hover.gotham-book tbody tr") #[cite: 3]

                for fila in filas: #[cite: 3]
                    columnas = fila.find_all("td") #[cite: 3]
                    if len(columnas) >= 3: #[cite: 3]
                        img_tag = columnas[0].find("img") #[cite: 3]
                        if img_tag: #[cite: 3]
                            src = img_tag.get("src", "") #[cite: 3]
                            if "baloto-kind" in src: #[cite: 3]
                                sorteo = "Baloto" #[cite: 3]
                            elif "revancha-kind" in src: #[cite: 3]
                                sorteo = "Revancha" #[cite: 3]
                            else:
                                sorteo = "Desconocido" #[cite: 3]
                        else:
                            sorteo = "Desconocido" #[cite: 3]

                        fecha = columnas[1].get_text(strip=True) #[cite: 3]
                        numeros_texto = columnas[2].get_text(" ", strip=True) #[cite: 3]
                        numeros = [int(n) for n in re.findall(r"\d+", numeros_texto)] #[cite: 3]

                        if len(numeros) == 6: #[cite: 3]
                            resultados.append([sorteo, fecha] + numeros) #[cite: 3]
                
                time.sleep(1.2)  # Delay preventivo para el firewall de Baloto
            except Exception as e:
                print(f"❌ Error procesando datos en la página {pagina}: {e}")

        # Construir DataFrame base si se obtuvieron históricos
        if resultados:
            df = pd.DataFrame(resultados, columns=["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balotaroja"]) #[cite: 3]
            df['fecha'] = df['fecha'].apply(self.convertir_fecha_manual)
            df['fecha'] = pd.to_datetime(df['fecha'], errors='coerce')
            df_final = df
        else:
            print("❌ No se lograron recuperar registros históricos de Baloto.")
            return

        # Buscar bloque del próximo sorteo
        try:
            r_home = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            soup_home = BeautifulSoup(r_home.text, "html.parser")
            proxsorteo = soup_home.find("div", class_="bottom-pill--nextdraw") #[cite: 3]
            
            if proxsorteo:
                fecha_divs = proxsorteo.find_all("div", class_="gotham-black yellow-color") #[cite: 3]
                partes_fecha = [div.get_text(strip=True) for div in fecha_divs] #[cite: 3]
                
                if len(partes_fecha) >= 2:
                    fecha_texto = partes_fecha[1] #[cite: 3]
                    dia, _, mes_es = fecha_texto.partition(" de ") #[cite: 3]
                    mes_en = self.meses_es_en[mes_es] #[cite: 3]
                    
                    # Control dinámico de fin de año
                    año_actual = datetime.now().year #[cite: 3]
                    if datetime.now().month == 12 and mes_es.lower() == 'enero':
                        año_actual += 1

                    fecha_convertible = datetime.strptime(f"{dia} {mes_en} {año_actual}", "%d %B %Y") #[cite: 3]

                    df2 = pd.DataFrame({
                        'sorteo': ['Baloto', 'Revancha'], #[cite: 3]
                        'fecha': [fecha_convertible, fecha_convertible], #[cite: 3]
                        'balota1': [0, 0], 'balota2': [0, 0], 'balota3': [0, 0], 'balota4': [0, 0], 'balota5': [0, 0], #[cite: 3]
                        'balotaroja': [0, 0] #[cite: 3]
                    })
                    df_final = pd.concat([df_final, df2]) #[cite: 3]
        except Exception as e:
            print(f"⚠️ Error obteniendo fecha de próximo sorteo Baloto: {e}. Usando solo históricos.")

        # Ordenar de forma descendente idéntico al notebook
        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True) #[cite: 3]
        
        # Guardado final en Neon PostgreSQL
        try:
            from sqlalchemy.types import Date
            engine = get_engine()
            df_final.to_sql('resultados_bloto', engine, if_exists='replace', index=False, dtype={'fecha': Date()})
            print(f"✅ ¡DataFrame de Baloto guardado exitosamente! Total filas: {len(df_final)}")
        except Exception as e:
            print(f"❌ Error al guardar datos en Neon PostgreSQL: {e}")

if __name__ == "__main__":
    BalotoScraper().run()