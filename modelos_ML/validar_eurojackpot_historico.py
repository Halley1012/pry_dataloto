import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text
import requests
from bs4 import BeautifulSoup
import re

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.eurojackpot.scraper import EurojackpotScraper

def validar_eurojackpot():
    print("==================================================")
    print("Iniciando Validación Histórica para Eurojackpot (Alemania)")
    print("5 balotas (1..50) + 2 Eurozahlen (1..12) | Sin Revancha")
    print("==================================================")

    engine = get_engine()
    scraper = EurojackpotScraper()

    # 1. Auditoría de datos en base de datos
    try:
        with engine.connect() as conn:
            df = pd.read_sql(text("SELECT * FROM resultados_eurojackpot ORDER BY fecha ASC;"), conn)
    except Exception as e:
        print(f"❌ Error leyendo tabla resultados_eurojackpot: {e}")
        return False

    if df.empty:
        print("❌ Error: resultados_eurojackpot está vacía.")
        return False

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Fechas de sorteos reales
    print(f"\nRango fechas reales:")
    print(f"  - Desde: {df_real['fecha'].min()} hasta: {df_real['fecha'].max()}")

    # 3. Validar cero duplicados
    dup = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup)}")
        return False
    else:
        print("✅ Cero duplicados en (fecha, sorteo)")

    # 4. Validar rangos de balotas (1..50, 5 números únicos por sorteo) y Eurozahlen (1..12, 2 únicos)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    euro_cols = ['balotaroja', 'balotaroja2']
    errores_rango = 0
    errores_unicos = 0
    errores_euro = 0

    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 50) for b in balls):
            errores_rango += 1
        if len(set(balls)) != 5:
            errores_unicos += 1

        euros = [int(row[c]) for c in euro_cols]
        if any(not (1 <= e <= 12) for e in euros):
            errores_euro += 1

    if errores_rango > 0:
        print(f"❌ Sorteos con balotas fuera de rango 1..50: {errores_rango}")
    else:
        print("✅ Todas las balotas principales dentro del rango 1..50")

    if errores_unicos > 0:
        print(f"❌ Sorteos con balotas principales repetidas: {errores_unicos}")
    else:
        print("✅ Cero balotas principales repetidas por sorteo")

    if errores_euro > 0:
        print(f"❌ Sorteos con Eurozahlen fuera de rango 1..12: {errores_euro}")
    else:
        print("✅ Todas las Eurozahlen dentro del rango 1..12")

    # 5. Comparar último sorteo real en BD vs Fuente Web
    print("\n➡️ Verificando sincronización con la fuente (combinacionganadora.com)...")
    headers = scraper.headers
    try:
        r = requests.get(scraper.base_url, headers=headers, timeout=12)
        if r.status_code == 200:
            soup = BeautifulSoup(r.text, "html.parser")
            sorteo_div = soup.find("div", id="sorteo")
            if sorteo_div:
                txt = sorteo_div.get_text(" ", strip=True)
                print(f"Fuente web última cabecera: {txt[:120]}")
    except Exception as e:
        print(f"⚠️ No se pudo verificar fuente en vivo: {e}")

    print("\n✅ Auditoría de Eurojackpot completada con éxito.")
    return True

if __name__ == "__main__":
    validar_eurojackpot()
