import sys
import time
import re
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
import requests
from bs4 import BeautifulSoup

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

from config.database import get_engine

class BonolotoScraper:
    def __init__(self):
        self.base_url = "https://www.loteriabonoloto.info/"
        self.archive_url = "https://www.loteriabonoloto.info/historico-bonoloto/"
        self.game_name = "Bonoloto"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-ES,es;q=0.9,en;q=0.8"
        }
        # Sorteos: Diario (Lunes a Domingo)
        self.draw_days = (0, 1, 2, 3, 4, 5, 6)
        self.meses = {
            'enero': '01', 'febrero': '02', 'marzo': '03', 'abril': '04',
            'mayo': '05', 'junio': '06', 'julio': '07', 'agosto': '08',
            'septiembre': '09', 'octubre': '10', 'noviembre': '11', 'diciembre': '12'
        }
        self.meses_abrev = {
            'ene': '01', 'feb': '02', 'mar': '03', 'abr': '04',
            'may': '05', 'jun': '06', 'jul': '07', 'ago': '08',
            'sep': '09', 'oct': '10', 'nov': '11', 'dic': '12'
        }

    def update_jackpot(self, engine, loteria, jackpot, fecha):
        if not jackpot or not fecha:
            return
        
        from sqlalchemy import text
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
                
                # Limpiar registros de jackpots más viejos a 5 días
                conn.execute(text("""
                    DELETE FROM loterias_jackpots
                    WHERE loteria = :loteria AND fecha < CURRENT_DATE - INTERVAL '5 days';
                """), {"loteria": loteria})
                conn.commit()
        except Exception as e:
            print(f"❌ Error actualizando jackpot para {loteria} en BD: {e}")

    def scrape_recent_draws(self):
        """Extrae el sorteo más reciente y el bote desde la página principal de Bonoloto."""
        print(f"➡️ Solicitando resultados recientes desde {self.base_url}...")
        response = None
        for intento in range(3):
            try:
                response = requests.get(self.base_url, headers=self.headers, timeout=15)
                if response.status_code == 200:
                    break
            except requests.exceptions.RequestException as e:
                wait = (intento + 1) * 2
                print(f"🔄 Intento {intento + 1} falló ({e}). Reintentando en {wait}s...")
                time.sleep(wait)

        if not response or response.status_code != 200:
            print("⚠️ No se pudo obtener respuesta de la página principal de Bonoloto.")
            return [], None, None

        soup = BeautifulSoup(response.text, "html.parser")
        
        # 1. Extraer Jackpot y fecha del próximo sorteo de forma robusta
        jackpot_str = None
        next_draw_date = None

        # 1.1 Buscar en bloques txtpub filtrando específicamente Bonoloto y descartando banners comerciales (ej. "DESDE SOLO 1€")
        for txtpub in soup.find_all(class_="txtpub"):
            nloto = txtpub.find(class_="nloto")
            nloto_text = nloto.get_text(strip=True).lower() if nloto else ""
            h3 = txtpub.find("h3")
            raw_h3 = h3.get_text(" ", strip=True).replace("\xa0", " ").strip() if h3 else ""

            # Validar que pertenezca a Bonoloto y no a otra lotería ni a publicidad comercial
            if ("bonoloto" in nloto_text or not nloto_text) and not any(other in nloto_text for other in ["euro", "primitiva", "gordo"]):
                if not any(bad in raw_h3.lower() for bad in ["desde", "solo", "juega", "apuesta", "precio"]):
                    m_num = re.search(r'([0-9\.,]+(?:\s*millon(?:es)?)?)\s*€?', raw_h3, re.IGNORECASE)
                    if m_num:
                        val = m_num.group(1).strip()
                        num_clean = re.sub(r'[^\d]', '', val)
                        if num_clean and int(num_clean) >= 100000:
                            jackpot_str = f"{val} €"

                            p = txtpub.find("p")
                            if p:
                                p_text = p.get_text(strip=True)
                                m_next = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)(?:\s+de\s+(\d{4}))?', p_text)
                                if m_next:
                                    d_day = m_next.group(1)
                                    d_mon = m_next.group(2).lower().strip()
                                    d_yr = m_next.group(3) or str(datetime.now().year)
                                    mon_num = self.meses.get(d_mon)
                                    if mon_num:
                                        next_draw_date = f"{d_yr}-{mon_num}-{d_day.zfill(2)}"
                            break

        # 1.2 Fallback: buscar en la crónica y textos de la página oficial
        if not jackpot_str:
            for p in soup.find_all("p"):
                ptxt = p.get_text(" ", strip=True)
                if "bote" in ptxt.lower():
                    m_bote = re.search(r'bote\s*(?:de|estimado|en\s*juego|para\s*el\s*próximo\s*sorteo)?\s*:?\s*([0-9\.,]+(?:\s*millones)?)\s*€', ptxt, re.IGNORECASE)
                    if m_bote:
                        val = m_bote.group(1).strip()
                        num_clean = re.sub(r'[^\d]', '', val)
                        if num_clean and int(num_clean) >= 100000:
                            jackpot_str = f"{val} €"
                            break

        if not jackpot_str:
            jackpot_str = "600.000 €"

        # 2. Extraer último sorteo
        draws = []
        art = soup.find("article", class_="result")
        if art:
            date_p = art.find("p", class_="date")
            if date_p:
                date_txt = date_p.get_text(strip=True)
                m_date = re.search(r'(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚ]+)\s+de\s+(\d{4})', date_txt)
                if m_date:
                    day, month_str, year = m_date.groups()
                    month_clean = month_str.lower().strip()
                    mon_num = self.meses.get(month_clean)
                    if mon_num:
                        fecha_str = f"{year}-{mon_num}-{day.zfill(2)}"

                        combi_div = art.find("div", class_="combi")
                        if combi_div:
                            nums_divs = combi_div.find_all("div", class_="num")
                            num_vals = [int(nd.get_text(strip=True)) for nd in nums_divs if nd.get_text(strip=True).isdigit()]
                            if len(num_vals) >= 8:
                                # 6 regulares, 1 complementario, 1 reintegro
                                draws.append([
                                    self.game_name,
                                    fecha_str,
                                    num_vals[0], num_vals[1], num_vals[2], num_vals[3], num_vals[4], num_vals[5],
                                    num_vals[6], # Complementario
                                    num_vals[7]  # Reintegro
                                ])

        return draws, jackpot_str, next_draw_date

    def scrape_historical_years(self):
        """Extrae el histórico completo de sorteos de Bonoloto clasificados por año."""
        print(f"📚 Iniciando extracción histórica completa desde {self.archive_url}...")
        try:
            r = requests.get(self.archive_url, headers=self.headers, timeout=15)
            if r.status_code != 200:
                print("⚠️ Error accediendo al archivo histórico de Bonoloto.")
                return []
        except Exception as e:
            print(f"⚠️ Error conectando al archivo histórico de Bonoloto: {e}")
            return []

        soup = BeautifulSoup(r.text, "html.parser")
        year_links = []
        for a in soup.select("table a") or soup.find_all("a", href=True):
            txt = a.get_text(strip=True)
            if re.match(r'^(19\d{2}|20\d{2})$', txt):
                year_links.append((txt, a['href']))

        all_draws = []
        current_year = datetime.now().year

        for year_text, href in year_links:
            if href.startswith("http"):
                year_url = href
            elif href.startswith("/"):
                year_url = f"https://www.loteriabonoloto.info{href}"
            else:
                year_url = f"https://www.loteriabonoloto.info/historico-bonoloto/{href}"

            print(f"   ⏳ Descargando sorteos de Bonoloto año {year_text} ({year_url})...")
            try:
                ry = requests.get(year_url, headers=self.headers, timeout=15)
                if ry.status_code != 200:
                    continue
                sy = BeautifulSoup(ry.text, "html.parser")
                table = sy.find("table")
                if not table:
                    continue

                rows = table.find_all("tr")
                seen_ene = False

                for row in rows:
                    tds = [td.get_text(strip=True) for td in row.find_all("td")]
                    
                    date_idx = None
                    for idx, text_val in enumerate(tds):
                        if re.match(r'^\d{1,2}-[a-z]{3}$', text_val.lower()):
                            date_idx = idx
                            break
                    if date_idx is None:
                        continue

                    date_str = tds[date_idx].lower()
                    day_part, mon_part = date_str.split('-')
                    mon_num = self.meses_abrev.get(mon_part)
                    if not mon_num:
                        continue

                    if mon_part == 'ene':
                        seen_ene = True

                    draw_year = int(year_text)
                    # Si aparece diciembre antes de haber visto enero en la tabla anual, es del año anterior
                    if mon_part == 'dic' and not seen_ene:
                        draw_year -= 1

                    fecha_str = f"{draw_year}-{mon_num}-{day_part.zfill(2)}"

                    num_cols = tds[date_idx + 1: date_idx + 7]
                    comp_col = tds[date_idx + 7: date_idx + 8]
                    rein_col = tds[date_idx + 8: date_idx + 9]

                    try:
                        nums = [int(n) for n in num_cols if n.isdigit()]
                        comp = int(comp_col[0]) if comp_col and comp_col[0].isdigit() else 0
                        rein = int(rein_col[0]) if rein_col and rein_col[0].isdigit() else 0

                        if len(nums) == 6:
                            all_draws.append([
                                self.game_name,
                                fecha_str,
                                nums[0], nums[1], nums[2], nums[3], nums[4], nums[5],
                                comp,
                                rein
                            ])
                    except ValueError:
                        continue
                time.sleep(0.2)
            except Exception as ey:
                print(f"   ⚠️ Error en año {year_text}: {ey}")

        print(f"📊 Total sorteos históricos extraídos para Bonoloto: {len(all_draws)}")
        return all_draws

    def run(self, backfill=False):
        print("🚀 Iniciando Scraping de Bonoloto (España)...")
        
        resultados = []
        recent_draws, jackpot_str, next_draw_date = self.scrape_recent_draws()
        resultados.extend(recent_draws)

        engine = get_engine()
        existing_df = pd.DataFrame()
        
        try:
            with engine.connect() as conn:
                from sqlalchemy import text
                res = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'resultados_bonoloto';")).scalar()
                if res > 0:
                    existing_df = pd.read_sql("SELECT * FROM resultados_bonoloto WHERE balota1 > 0;", conn)
                    print(f"📦 Registros históricos existentes en BD: {len(existing_df)}")
        except Exception as e:
            print(f"ℹ️ No se pudieron cargar registros previos ({e}).")

        needs_backfill = backfill or (len(existing_df) < 100)

        if needs_backfill:
            hist_draws = self.scrape_historical_years()
            resultados.extend(hist_draws)

        columns = ["sorteo", "fecha", "balota1", "balota2", "balota3", "balota4", "balota5", "balota6", "balotaroja", "balotaroja2"]
        df_new = pd.DataFrame(resultados, columns=columns) if resultados else pd.DataFrame(columns=columns)

        if not existing_df.empty:
            df_combined = pd.concat([existing_df, df_new], ignore_index=True)
        else:
            df_combined = df_new

        if df_combined.empty:
            print("❌ No se obtuvieron resultados de Bonoloto.")
            return

        df_combined['fecha'] = pd.to_datetime(df_combined['fecha'], errors='coerce')
        df_combined = df_combined.dropna(subset=['fecha'])
        df_combined = df_combined[df_combined['balota1'] > 0]
        # Filtrar fechas futuras erróneas de sorteos pasados
        hoy_max = pd.to_datetime('now') + timedelta(days=1)
        df_combined = df_combined[df_combined['fecha'] <= hoy_max]
        df_combined = df_combined.drop_duplicates(subset=['fecha']).reset_index(drop=True)
        df_final = df_combined

        # --- Agregar fila del próximo sorteo en cero ---
        try:
            if next_draw_date:
                cur_date = pd.to_datetime(next_draw_date)
            else:
                fecha_max_hist = df_final['fecha'].max()
                cur_date = fecha_max_hist + timedelta(days=1)

            if df_final['fecha'].max() < cur_date:
                df_prox = pd.DataFrame({
                    'sorteo': [self.game_name],
                    'fecha': [cur_date],
                    'balota1': [0], 'balota2': [0], 'balota3': [0], 'balota4': [0], 'balota5': [0], 'balota6': [0],
                    'balotaroja': [0], 'balotaroja2': [0]
                })
                df_final = pd.concat([df_final, df_prox], ignore_index=True)
                print(f"📅 Fecha del próximo sorteo agregada para Bonoloto: {cur_date.strftime('%Y-%m-%d')}")
        except Exception as e:
            print(f"⚠️ Error calculando fecha de próximo sorteo Bonoloto: {e}")

        df_final = df_final.sort_values(by='fecha', ascending=False).reset_index(drop=True)

        # --- Guardar en Base de Datos ---
        try:
            from sqlalchemy.types import Date, Integer, String

            # --- VALIDATION ---
            try:
                from sqlalchemy import text
                with engine.connect() as conn:
                    max_db_fecha = conn.execute(text("SELECT MAX(fecha) FROM resultados_bonoloto")).scalar()
                if max_db_fecha:
                    max_db_fecha = pd.to_datetime(max_db_fecha).date()
                    max_df_fecha = df_final['fecha'].max().date()
                    if max_df_fecha <= max_db_fecha:
                        print("No hay sorteo nuevo por feriado o retraso. Terminando sin actualizar.")
                        return False
            except Exception as e:
                print(f"Error en validación temprana: {e}")
            # --- END VALIDATION ---
            
            df_final.to_sql(
                'resultados_bonoloto', 
                engine, 
                if_exists='replace', 
                index=False, 
                dtype={
                    'sorteo': String(50),
                    'fecha': Date(),
                    'balota1': Integer(),
                    'balota2': Integer(),
                    'balota3': Integer(),
                    'balota4': Integer(),
                    'balota5': Integer(),
                    'balota6': Integer(),
                    'balotaroja': Integer(),
                    'balotaroja2': Integer()
                }
            )
            print(f"✅ Resultados de Bonoloto guardados exitosamente! Total filas: {len(df_final)}")
            
            if jackpot_str:
                target_fecha = next_draw_date if next_draw_date else datetime.now().strftime('%Y-%m-%d')
                self.update_jackpot(engine, "bonoloto", jackpot_str, target_fecha)
        except Exception as e:
            print(f"❌ Error al guardar resultados de Bonoloto en BD: {e}")

if __name__ == "__main__":
    BonolotoScraper().run(backfill=False)
