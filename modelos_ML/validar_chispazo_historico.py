import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.chispazo.scraper import ChispazoScraper

def validar_chispazo():
    print("==================================================")
    print("Iniciando Validación Histórica para Chispazo (México)")
    print("Lotería ID: 18 | Balotas: 5 números del 1 al 28")
    print("==================================================")

    engine = get_engine()
    scraper = ChispazoScraper()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_chispazo ORDER BY concurso ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_chispazo está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Continuidad de concursos
    concursos = set(df_real['concurso'].astype(int))
    min_c = min(concursos)
    max_c = max(concursos)
    esperados = set(range(min_c, max_c + 1))
    faltantes = sorted(list(esperados - concursos))

    print(f"\nContinuidad de concursos:")
    print(f"  - Total sorteos reales: {len(concursos)}")
    print(f"  - Rango: #{min_c} al #{max_c}")
    if faltantes:
        print(f"  ❌ Faltantes ({len(faltantes)}): {faltantes[:10]}...")
        sys.exit(1)
    else:
        print(f"  ✅ Continuidad perfecta: {len(concursos)}/{len(concursos)} (0 faltantes)")

    # 3. Validar cero duplicados en concurso
    dup = df_real[df_real.duplicated(subset=['concurso'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en concurso: {len(dup)}")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en concurso")

    # 4. Validar rangos de balotas (balota1..5 in 1..28 sin repetidos en la misma fila)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    errores_rango = 0
    errores_unicos = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 28) for b in balls):
            errores_rango += 1
            if errores_rango <= 5:
                print(f"❌ Error de rango en concurso #{row['concurso']}: {balls}")
        if len(set(balls)) != 5:
            errores_unicos += 1
            if errores_unicos <= 5:
                print(f"❌ Números repetidos en concurso #{row['concurso']}: {balls}")

    if errores_rango > 0 or errores_unicos > 0:
        print(f"❌ Errores en balotas: {errores_rango} fuera de rango, {errores_unicos} no únicos.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en el rango válido [1..28] y son números únicos")

    # 5. Modalidades
    modalidades = df_real['sorteo'].value_counts().to_dict()
    print(f"\nDistribución por modalidad: {modalidades}")

    # 6. Validar placeholder(s)
    print(f"\nPlaceholders encontrados: {len(df_ph)}")
    for _, r in df_ph.iterrows():
        print(f"  - Concurso #{r['concurso']} ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]}")

    # 7. Sincronización con la fuente oficial
    print("\n➡️ Verificando sincronización con la fuente oficial (loterianacional.gob.mx)...")
    fuente = scraper.extraer_ultimo_sorteo_fuente()
    db_last = scraper.obtener_ultimo_sorteo_db()
    if fuente:
        print(f"  Último en Fuente: #{fuente['concurso']} ({fuente['fecha']}) - Balotas: {fuente['balotas']}")
    else:
        print("  ⚠️ No se pudo consultar la fuente en este momento.")
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
    print("🎉 AUDITORÍA DE DATOS DE CHISPAZO COMPLETADA")
    print("==================================================")

if __name__ == "__main__":
    validar_chispazo()
