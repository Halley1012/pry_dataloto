import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.melate.scraper import MelateScraper

def validar_melate():
    print("==================================================")
    print("Iniciando Validación Histórica para Melate (México)")
    print("Modalidades: Melate, Revancha, Revanchita | 6 balotas (1..56) + adicional")
    print("==================================================")

    engine = get_engine()
    scraper = MelateScraper()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_melate ORDER BY fecha ASC, sorteo ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_melate está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Desglose por modalidad
    for s_name in ['Melate', 'Revancha', 'Revanchita']:
        df_s = df_real[df_real['sorteo'] == s_name]
        c_vals = df_s['concurso'].dropna().astype(int)
        min_c = c_vals.min() if not c_vals.empty else None
        max_c = c_vals.max() if not c_vals.empty else None
        print(f"\nModalidad '{s_name}':")
        print(f"  - Total reales: {len(df_s)}")
        print(f"  - Rango concursos: #{min_c} al #{max_c}")
        print(f"  - Fechas: {df_s['fecha'].min()} al {df_s['fecha'].max()}")

    # 3. Continuidad de concursos en Melate principal
    df_m = df_real[df_real['sorteo'] == 'Melate'].copy()
    concursos_m = set(df_m['concurso'].dropna().astype(int))
    min_m = min(concursos_m)
    max_m = max(concursos_m)
    esperados_m = set(range(min_m, max_m + 1))
    faltantes_m = sorted(list(esperados_m - concursos_m))

    print(f"\nContinuidad concursos Melate principal:")
    print(f"  - Sorteos reales: {len(concursos_m)}")
    print(f"  - Rango: #{min_m} al #{max_m}")
    if faltantes_m:
        print(f"  ⚠️ Concursos no presentes ({len(faltantes_m)}): {faltantes_m[:10]}...")
    else:
        print(f"  ✅ Continuidad perfecta: {len(concursos_m)}/{len(concursos_m)} (0 faltantes)")

    # 4. Validar cero duplicados en (fecha, sorteo)
    dup = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup)}")
        sys.exit(1)
    else:
        print("\n✅ Cero duplicados en (fecha, sorteo)")

    # 5. Validar rangos de balotas (1..56, 6 números únicos por sorteo)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5', 'balota6']
    errores_rango = 0
    errores_unicos = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 56) for b in balls):
            errores_rango += 1
            if errores_rango <= 3:
                print(f"❌ Error rango balotas en {row['sorteo']} #{row['concurso']} ({row['fecha']}): {balls}")
        if len(set(balls)) != 6:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en {row['sorteo']} #{row['concurso']} ({row['fecha']}): {balls}")

    if errores_rango > 0 or errores_unicos > 0:
        print(f"❌ Errores en balotas: {errores_rango} fuera de rango, {errores_unicos} repetidas.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en el rango válido [1..56] y son 6 números únicos")

    # 6. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - {r['sorteo']} #{r['concurso']} ({r['fecha']}): Balotas={[r[c] for c in balota_cols]}")

    print("\n==================================================")
    print("🎉 AUDITORÍA DE DATOS DE MELATE COMPLETADA")
    print("==================================================")

if __name__ == "__main__":
    validar_melate()
