import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text
import requests
import json

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine

def validar_megamillions():
    print("==================================================")
    print("Iniciando Validación Histórica para Mega Millions (USA)")
    print("Lotería ID: 12 | 5 balotas (1..70) + 1 Mega Ball (1..25)")
    print("==================================================")

    engine = get_engine()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_megamillions ORDER BY fecha ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_megamillions está vacía.")
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

    # 4. Validar unicidad de balotas (5 números únicos por sorteo)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    errores_unicos = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if len(set(balls)) != 5:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en ({row['fecha']}): {balls}")

    if errores_unicos > 0:
        print(f"❌ Errores: {errores_unicos} sorteos con números repetidos.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas son 5 números únicos por sorteo")

    # 5. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]} Mega Ball={r.get('balotaroja')}")

    # 6. Sincronización con API oficial de Mega Millions
    print("\n➡️ Verificando sincronización con la API oficial (megamillions.com)...")
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Content-Type": "application/json; charset=utf-8"
        }
        payload = {"pageNumber": 1, "pageSize": 5, "startDate": "", "endDate": ""}
        r = requests.post("https://www.megamillions.com/cmspages/utilservice.asmx/GetDrawingPagingData", headers=headers, json=payload, timeout=10)
        if r.status_code == 200:
            d = r.json()
            raw = d.get("d")
            data = json.loads(raw) if isinstance(raw, str) else d
            draws = data.get("DrawingData", [])
            if draws:
                first = draws[0]
                fecha_fuente = first.get("PlayDate")
                if fecha_fuente:
                    fecha_str = fecha_fuente[:10]
                    balls_fuente = [first.get(f"N{i}") for i in range(1, 6)]
                    mb_fuente = first.get("MBall")
                    print(f"  Último sorteo en Fuente: {fecha_str} -> {balls_fuente} + MB {mb_fuente}")
                    print(f"  Último sorteo en BD:     {df_real.iloc[-1]['fecha']}")
                    if str(fecha_str) == str(df_real.iloc[-1]['fecha']):
                        print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
                    elif str(fecha_str) > str(df_real.iloc[-1]['fecha']):
                        print(f"⚠️ Hay sorteos más recientes en la fuente oficial ({fecha_str})")
        else:
            print(f"⚠️ Mega Millions API respondió con status {r.status_code}")
    except Exception as e:
        print(f"⚠️ No se pudo conectar con Mega Millions: {e}")

    print("\n==================================================")
    print("✅ Validación de Mega Millions completada exitosamente!")
    print("==================================================")

if __name__ == "__main__":
    validar_megamillions()
