import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text
import requests
from bs4 import BeautifulSoup
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine

def validar_double_play():
    print("==================================================")
    print("Iniciando Validación Histórica para Double Play (USA)")
    print("Lotería ID: 13 | 5 balotas (1..69) + 1 Double Play Ball (1..26)")
    print("==================================================")

    engine = get_engine()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_double_play ORDER BY fecha ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_double_play está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Fechas de sorteos reales
    print(f"\nRango fechas reales:")
    print(f"  - Desde: {df_real['fecha'].min()} hasta: {df_real['fecha'].max()}")

    # 3. Validar cero duplicados en (fecha, sorteo)
    dup_f = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup_f.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup_f)}")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en (fecha, sorteo)")

    # 4. Validar rangos de balotas (1..69, 5 números únicos) y Double Play ball (1..26)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    errores_rango = 0
    errores_unicos = 0
    errores_extra = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 69) for b in balls):
            errores_rango += 1
            if errores_rango <= 3:
                print(f"❌ Error rango balotas en ({row['fecha']}): {balls}")
        if len(set(balls)) != 5:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en ({row['fecha']}): {balls}")
        extra = int(row['balotaroja'])
        if not (1 <= extra <= 26):
            errores_extra += 1
            if errores_extra <= 3:
                print(f"❌ Error Double Play ball en ({row['fecha']}): {extra}")

    if errores_rango > 0 or errores_unicos > 0 or errores_extra > 0:
        print(f"❌ Errores: {errores_rango} rango balotas, {errores_unicos} repetidas, {errores_extra} extra.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas en rango [1..69] (5 únicas) y Double Play Ball en rango [1..26]")

    # 5. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]} Extra={r.get('balotaroja')}")

    # 6. Sincronización con fuente oficial
    print("\n➡️ Verificando sincronización con la fuente oficial (powerball.com)...")
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "X-Requested-With": "XMLHttpRequest"
        }
        r = requests.get("https://www.powerball.com/es/sorteos-anteriores?gc=pb-double-play&pg=1", headers=headers, timeout=10)
        if r.status_code == 200:
            soup = BeautifulSoup(r.text, "html.parser")
            card = soup.select_one("a.card")
            if card:
                href = card.get("href", "")
                fecha_fuente = parse_qs(urlparse(href).query).get("date", [None])[0]
                ball_divs = card.select(".game-ball-group .form-control div")
                balls_fuente = [int(b.get_text(strip=True)) for b in ball_divs if b.get_text(strip=True).isdigit()]
                print(f"  Último sorteo en Fuente: {fecha_fuente} -> {balls_fuente}")
                print(f"  Último sorteo en BD:     {df_real.iloc[-1]['fecha']}")
                if str(fecha_fuente) == str(df_real.iloc[-1]['fecha']):
                    print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
                elif str(fecha_fuente) > str(df_real.iloc[-1]['fecha']):
                    print(f"⚠️ Hay sorteos más recientes en la fuente oficial ({fecha_fuente})")
        else:
            print(f"⚠️ Double Play respondió con status {r.status_code}")
    except Exception as e:
        print(f"⚠️ No se pudo conectar con Powerball Double Play: {e}")

    print("\n==================================================")
    print("✅ Validación de Double Play completada exitosamente!")
    print("==================================================")

if __name__ == "__main__":
    validar_double_play()
