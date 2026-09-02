import sys
import time
from pathlib import Path
from datetime import datetime
import pandas as pd
import requests
from bs4 import BeautifulSoup

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine

class MilotoScraper:
    def __init__(self):
        self.base_url = "https://baloto.com/miloto/resultados/?page={}"
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
        ultima_pagina = soup.find("a", string=lambda text: text and "Última" in text)
        if ultima_pagina:
            href = ultima_pagina.get("href", "")
            if "page=" in href:
                try:
                    return int(href.split("page=")[-1])
                except ValueError:
                    pass
        
    def update_jackpot(self, engine, loteria, jackpot, fecha_str):
        if not jackpot or not fecha_str:
            return
        # Parse date
        fecha = None
        try:
            parts = fecha_str.strip().split(" de ")
            if len(parts) == 2:
                dia_part = parts[0].split()[-1]
                mes_es = parts[1].strip()
                mes_en = self.meses_es_en.get(mes_es.capitalize())
                if mes_en:
                    año = datetime.now().year
                    if datetime.now().month == 12 and mes_es.lower() == 'enero':
                        año += 1
                    fecha = datetime.strptime(f"{dia_part} {mes_en} {año}", "%d %B %Y").date()
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
                
                # Cleanup older than 5 days
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": loteria})
                conn.commit()
        except Exception as e:
            print(f"Error updating jackpot for {loteria} in DB: {e}")

    def run(self):
        print("🚀 Iniciando Scraping de Miloto...")
        
        # Inicializamos df_final desde el inicio para evitar NameError ante fallos
        df_final = pd.DataFrame()

        try:
            r = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            total_paginas = self.obtener_num_paginas(r.text)
        except Exception as e:
            print(f"❌ Error crítico al conectar a la web de Miloto: {e}")
            return

        resultados = []

        # Extracción de páginas con control de reintentos robusto
        for page in range(1, total_paginas + 1):
            print(f"Scrapeando página {page} de {total_paginas}...")
            response = None
            max_intentos = 3
            
            for intento in range(max_intentos):
                try:
                    response = requests.get(self.base_url.format(page), headers=self.headers, timeout=15)
                    if response.status_code == 200:
                        break
                # Cambiamos las excepciones específicas por la genérica de Requests para atrapar Timeouts
                except requests.exceptions.RequestException as e:
                    if intento < max_intentos - 1:
                        wait = (intento + 1) * 5  # Espera 5s, luego 10s...
                        print(f"🔄 Timeout o bloqueo de red detectado en pág {page} ({e}). Reintentando en {wait}s...")
                        time.sleep(wait)
                    else:
                        print(f"❌ Se agotaron los {max_intentos} intentos para la página {page} debido a caídas de red.")
            
            # Si a pesar de los reintentos no hay respuesta exitosa, saltamos a la siguiente sin tumbar el script
            if not response or response.status_code != 200:
                print(f"⚠️ Saltando página {page} debido a error persistente de conexión.")
                continue

            try:
                soup = BeautifulSoup(response.text, "html.parser")
                filas = soup.select("table.table-points-miloto tbody tr")
                for fila in filas:
                    columnas = fila.find_all("td")
                    if len(columnas) >= 2:
                        fecha = columnas[0].text.strip()
                        numeros_span = columnas[1].select("span")
                        numeros = [int(span.text.strip()) for span in numeros_span if span.text.strip().isdigit()]
                        if len(numeros) == 5:
                            resultados.append([fecha] + numeros)
                time.sleep(1.2) # Delay prudente para evitar cortes SSL
            except Exception as e:
                print(f"⚠️ Error procesando HTML en página {page}: {e}")

        # Crear dataframe base de históricos si hay registros extraídos
        if resultados:
            df = pd.DataFrame(resultados, columns=["fecha", "balota1", "balota2", "balota3", "balota4", "balota5"])
            df['fecha'] = df['fecha'].apply(self.convertir_fecha_manual)
            df['fecha'] = pd.to_datetime(df['fecha'], errors='coerce')
            df_final = df
        else:
            print("❌ No se lograron recuperar registros históricos.")
            return

        # Intentar adjuntar próximo sorteo
        try:
            r_home = requests.get(self.base_url.format(1), headers=self.headers, timeout=15)
            soup_home = BeautifulSoup(r_home.text, "html.parser")
            proxsorteo = soup_home.find('div', class_='col-md-3 col-4 dark-blue text-center')
            mobile = proxsorteo.find('div', class_='mobile')
            strong_tags = mobile.find_all('strong')
            
            dia = strong_tags[1].get_text(strip=True).split()[-1]
            mes_es = strong_tags[2].get_text(strip=True).replace("de ", "")
            mes_en = self.meses_es_en.get(mes_es)
            
            # Control de fin de año dinámico
            anio = datetime.now().year
            if datetime.now().month == 12 and mes_es.lower() == 'enero':
                anio += 1

            fecha_str = f"{dia} {mes_en} {anio}"
            fecha_convertible = datetime.strptime(fecha_str, "%d %B %Y")

            df2 = pd.DataFrame({
                'fecha': [fecha_convertible],
                'balota1': [0], 'balota2': [0], 'balota3': [0], 'balota4': [0], 'balota5': [0]
            })
            df_final = pd.concat([df_final, df2], ignore_index=True)
        except Exception as e:
            print(f"⚠️ Error obteniendo fecha de próximo sorteo: {e}. Usando solo históricos.")

        # Ordenar y guardar en base de datos
        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True)
        
        try:
            from sqlalchemy.types import Date
            engine = get_engine()

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_mloto")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql('resultados_mloto', engine, if_exists='replace', index=False, dtype={'fecha': Date()})
            print(f"DataFrame guardado exitosamente en Neon PostgreSQL! Total filas: {len(df_final)}")
            
            # Scrape and save jackpot for Miloto
            print("Scraping jackpot for Miloto from homepage...")
            r_main = requests.get("https://baloto.com/", headers=self.headers, timeout=15)
            if r_main.status_code == 200:
                soup_main = BeautifulSoup(r_main.text, "html.parser")
                miloto_home = soup_main.find(class_="accumulated-miloto-home")
                if miloto_home:
                    integer = miloto_home.find(class_="accum-integer")
                    jackpot_miloto = integer.get_text(strip=True) + " millones" if integer else None
                    
                    accum2 = miloto_home.find(class_="accumulated-2")
                    fecha_str = accum2.find(class_="fs-5").get_text(strip=True) if accum2 and accum2.find(class_="fs-5") else None
                    
                    if jackpot_miloto and fecha_str:
                        self.update_jackpot(engine, "miloto", jackpot_miloto, fecha_str)
            else:
                print(f"Warning: homepage returned status {r_main.status_code}")
        except Exception as e:
            print(f"Error saving results or jackpot for Miloto: {e}")


if __name__ == "__main__":
    MilotoScraper().run()