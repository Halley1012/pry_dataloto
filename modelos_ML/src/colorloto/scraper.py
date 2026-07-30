import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
import time
import unicodedata
from datetime import datetime
from config.database import get_engine

class ColorLotoScraper:
    def __init__(self):
        self.base_url = "https://baloto.com/colorloto/resultados/?page={}"
        self.headers = {"User-Agent": "Mozilla/5.0"}
        self.COLOR_MAP = {
            "balota-yellow": "amarillo",
            "balota-blue": "azul",
            "balota-red": "rojo",
            "balota-green": "verde",
            "balota-white": "blanco",
            "balota-black": "negro"
        }
        self.MESES = {
            "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
            "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12
        }

    def parse_fecha_es(self, fecha_str):
        fecha_str = fecha_str.lower()
        # Diccionario para meses en string a numero de formato manual
        meses_str = {
            "enero": "01", "febrero": "02", "marzo": "03", "abril": "04",
            "mayo": "05", "junio": "06", "julio": "07", "agosto": "08",
            "septiembre": "09", "octubre": "10", "noviembre": "11", "diciembre": "12"
        }
        for mes, num in meses_str.items():
            fecha_str = re.sub(rf"\b{mes}\b", num, fecha_str)
        fecha_str = fecha_str.replace(" de ", "-")
        return pd.to_datetime(fecha_str, format="%d-%m-%Y")

    def normalizar_mes(self, mes):
        mes = mes.lower().strip()
        mes = mes.replace("de ", "")
        mes = unicodedata.normalize("NFD", mes)
        mes = mes.encode("ascii", "ignore").decode("utf-8")
        return mes

    def obtener_num_paginas(self, html):
        soup = BeautifulSoup(html, "html.parser")
        ultima_pagina = soup.find("a", string=lambda text: text and "Última" in text)
        if ultima_pagina:
            href = ultima_pagina.get("href", "")
            if "page=" in href:
                try:
                    return int(href.split("page=")[-1])
                except ValueError:
                    pass
        return 1

    def extraer_resultados(self, html):
        soup = BeautifulSoup(html, "html.parser")
        filas = soup.select("table.table-historic-colorloto tbody tr")
        resultados_pagina = []
        for fila in filas:
            columnas = fila.find_all("td")
            if len(columnas) < 2:
                continue
            fecha = columnas[0].get_text(strip=True)
            balotas = columnas[1].select("div.balota-bg")
            if len(balotas) != 6:
                continue
            for posicion, balota in enumerate(balotas, start=1):
                clases = balota.get("class", [])
                color_clase = next(
                    (c for c in clases if c.startswith("balota-") and c != "balota-bg"),
                    None
                )
                color = self.COLOR_MAP.get(color_clase)
                numero_txt = balota.select_one("strong")
                if not color or not numero_txt:
                    continue
                numero = int(numero_txt.get_text(strip=True))
                resultados_pagina.append({
                    "fecha": fecha,
                    "posicion": posicion,
                    "color": color,
                    "numero": numero
                })
        return resultados_pagina

    def run(self):
        print("🚀 Iniciando Scraping de ColorLoto...")
        try:
            r_first = requests.get(self.base_url.format(1), headers=self.headers)
            num_paginas = self.obtener_num_paginas(r_first.text)
        except Exception as e:
            print(f"❌ Error al conectar a ColorLoto: {e}")
            return

        resultados_totales = []
        for pagina in range(1, num_paginas + 1):
            print(f"Scrapeando página {pagina} de {num_paginas}...")
            url = self.base_url.format(pagina)
            try:
                response = requests.get(url, headers=self.headers)
                if response.status_code == 200:
                    resultados_totales.extend(self.extraer_resultados(response.text))
                    time.sleep(0.5)
                else:
                    print(f"⚠️ Error al cargar página {pagina}: código {response.status_code}")
            except Exception as e:
                print(f"❌ Error en página {pagina}: {e}")

        df = pd.DataFrame(resultados_totales, columns=["fecha", "color", "numero"])
        df['fecha'] = df['fecha'].apply(self.parse_fecha_es)

        # Buscar fecha del próximo sorteo de ColorLoto
        try:
            r_home = requests.get(self.base_url.format(1), headers=self.headers)
            soup_home = BeautifulSoup(r_home.text, "html.parser")
            proxsorteo = soup_home.find('div', class_='col-md-3 col-4 dark-blue text-center')
            mobile = proxsorteo.find('div', class_='mobile')
            strong_tags = mobile.find_all('strong')

            dia_raw = strong_tags[1].get_text(strip=True)
            dia = int(dia_raw.split()[-1])
            mes_raw = strong_tags[2].get_text(strip=True)
            mes_es = self.normalizar_mes(mes_raw)
            anio = datetime.now().year
            
            if mes_es in self.MESES:
                mes = self.MESES[mes_es]
                fecha_proximo_sorteo = datetime(anio, mes, dia)
                df2 = pd.DataFrame({
                    'fecha': [fecha_proximo_sorteo],
                    'amarillo': [0], 'azul': [0], 'rojo': [0], 'verde': [0], 'blanco': [0], 'negro': [0]
                })
                df2_long = df2.melt(id_vars=["fecha"], var_name="color", value_name="numero")
                df_final = pd.concat([df, df2_long], ignore_index=True)
            else:
                df_final = df
        except Exception as e:
            print(f"⚠️ Error obteniendo fecha de próximo sorteo ColorLoto: {e}")
            df_final = df

        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True)
        
        # Guardar en base de datos
        try:
            from sqlalchemy.types import Date
            engine = get_engine()
            df_final.to_sql('resultados_colorloto2', engine, if_exists='replace', index=False, dtype={'fecha': Date()})
            print(f"✅ ¡DataFrame de ColorLoto guardado exitosamente! Total filas: {len(df_final)}")
        except Exception as e:
            print(f"❌ Error al escribir en Neon PostgreSQL: {e}")
