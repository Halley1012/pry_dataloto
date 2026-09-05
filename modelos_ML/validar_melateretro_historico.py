import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.melateretro.scraper import MelateRetroScraper

def validar_melateretro():
    print("==================================================")
    print("Iniciando Validación Histórica para Melate Retro (México)")
    print("Lotería ID: 17 | 6 balotas (1..39) + adicional (1..39)")
    print("==================================================")

    engine = get_engine()
    scraper = MelateRetroScraper()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_melateretro ORDER BY fecha ASC, concurso ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_melateretro está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Continuidad de concursos
    concursos = set(df_real['concurso'].dropna().astype(int))
    min_c = min(concursos)
    max_c = max(concursos)
    esperados = set(range(min_c, max_c + 1))
    faltantes = sorted(list(esperados - concursos))

    print(f"\nContinuidad de concursos:")
    print(f"  - Total sorteos reales: {len(concursos)}")
    print(f"  - Rango: #{min_c} al #{max_c}")
    print(f"  - Fechas: {df_real['fecha'].min()} al {df_real['fecha'].max()}")
    if faltantes:
        print(f"  ⚠️ Concursos no presentes ({len(faltantes)}): {faltantes[:10]}...")
    else:
        print(f"  ✅ Continuidad perfecta: {len(concursos)}/{len(concursos)} (0 faltantes)")

    # 3. Validar cero duplicados en (fecha, sorteo)
    dup = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup)}")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en (fecha, sorteo)")

    # 4. Validar rangos de balotas (1..39, 6 números únicos por sorteo)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5', 'balota6']
    errores_rango = 0
    errores_unicos = 0
    errores_adic = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 39) for b in balls):
            errores_rango += 1
            if errores_rango <= 3:
                print(f"❌ Error rango balotas en #{row['concurso']} ({row['fecha']}): {balls}")
        if len(set(balls)) != 6:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en #{row['concurso']} ({row['fecha']}): {balls}")
        adic = int(row['balotaroja'])
        if not (1 <= adic <= 39):
            errores_adic += 1
            if errores_adic <= 3:
                print(f"❌ Error adicional en #{row['concurso']} ({row['fecha']}): {adic}")

    if errores_rango > 0 or errores_unicos > 0 or errores_adic > 0:
        print(f"❌ Errores en balotas: {errores_rango} fuera de rango, {errores_unicos} repetidas, {errores_adic} adicional fuera de rango.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en el rango válido [1..39] y son 6 números únicos (+ adicional válido)")

    # 5. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - #{r['concurso']} ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]} | Adic={r['balotaroja']}")

    # 6. Sincronización con la fuente oficial
    print("\n➡️ Verificando sincronización con la fuente oficial (loterianacional.gob.mx)...")
    fuente = scraper.extraer_ultimo_sorteo_fuente()
    db_last = scraper.obtener_ultimo_sorteo_db()
    if fuente:
        print(f"  Último en Fuente: #{fuente['concurso']} ({fuente['fecha']}) - Balotas: {fuente['balotas']} Adicional: {fuente.get('adicional')}")
    else:
        print("  ⚠️ No se pudo consultar la fuente en este momento (o método aún no implementado).")
    if db_last:
        print(f"  Último real en BD: #{db_last['concurso']} ({db_last['fecha']})")

    if fuente and db_last:
        if fuente['concurso'] == db_last['concurso']:
            print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
        elif fuente['concurso'] > db_last['concurso']:
            print(f"ℹ️ Hay {fuente['concurso'] - db_last['concurso']} sorteo(s) nuevo(s) en fuente pendiente de procesar.")
        else:
            print(f"⚠️ La BD está más avanzada que la web ({db_last['concurso']} > {fuente['concurso']})")

    print("\n==================================================")
    print("🎉 AUDITORÍA DE DATOS DE MELATE RETRO COMPLETADA")
    print("==================================================")

if __name__ == "__main__":
    validar_melateretro()
