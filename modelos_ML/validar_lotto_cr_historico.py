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

def validar_lotto_cr():
    print("==================================================")
    print("Iniciando Validación Histórica para Lotto y Revancha (Costa Rica)")
    print("Lotería ID: 35 | 5 balotas (1..40)")
    print("==================================================")

    engine = get_engine()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_lotto_cr ORDER BY fecha ASC, sorteo ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_lotto_cr está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Fechas de sorteos reales
    print(f"\nRango fechas reales:")
    print(f"  - Desde: {df_real['fecha'].min()} hasta: {df_real['fecha'].max()}")
    print("\nConteo por sorteo:")
    print(df_real['sorteo'].value_counts())

    # 3. Validar cero duplicados en (fecha, sorteo)
    dup_f = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup_f.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup_f)}")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en (fecha, sorteo)")

    # 4. Validar balotas y unicidad
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    errores_unicos = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if len(set(balls)) != 5:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en ({row['fecha']} - {row['sorteo']}): {balls}")

    if errores_unicos > 0:
        print(f"❌ Errores en balotas: {errores_unicos} sorteos con balotas repetidas.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas son 5 números únicos por sorteo")

    # 5. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]}")

    # 6. Sincronización con fuente oficial
    print("\n➡️ Verificando sincronización con la fuente oficial (combinacionganadora.com)...")
    try:
        import re
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        }
        r = requests.get("https://www.combinacionganadora.com/cr/lotto-costa-rica/resultados/", headers=headers, timeout=10)
        if r.status_code == 200:
            soup = BeautifulSoup(r.text, "html.parser")
            link = soup.find("a", href=re.compile(r"/cr/lotto-costa-rica/resultados/\d{4}-\d{2}-\d{2}"))
            if link:
                href = link.get("href", "")
                m = re.search(r'(\d{4}-\d{2}-\d{2})', href)
                fecha_fuente = m.group(1) if m else None
                max_fecha_db = str(df_real['fecha'].max())
                print(f"  Último sorteo en Fuente: {fecha_fuente}")
                print(f"  Último sorteo en BD:     {max_fecha_db}")
                if str(fecha_fuente) == str(max_fecha_db):
                    print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
                elif str(fecha_fuente) > str(max_fecha_db):
                    print(f"⚠️ Hay sorteos más recientes en la fuente oficial ({fecha_fuente})")
        else:
            print(f"⚠️ combinacionganadora respondió con status {r.status_code}")
    except Exception as e:
        print(f"⚠️ No se pudo conectar con combinacionganadora: {e}")

    print("\n==================================================")
    print("✅ Validación de Lotto Costa Rica completada exitosamente!")
    print("==================================================")

if __name__ == "__main__":
    validar_lotto_cr()
