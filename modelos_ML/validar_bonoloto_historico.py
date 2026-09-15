import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.bonoloto.scraper import BonolotoScraper

def validar_bonoloto():
    print("==================================================")
    print("Iniciando Validación Histórica para BonoLoto (España)")
    print("Lotería ID: 26 | 6 balotas (1..49) + Complementario + Reintegro (0..9)")
    print("==================================================")

    engine = get_engine()
    scraper = BonolotoScraper()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_bonoloto ORDER BY fecha ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_bonoloto está vacía.")
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
    dup = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup)}")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en (fecha, sorteo)")

    # 4. Validar rangos de balotas (1..49, 6 números únicos por sorteo)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5', 'balota6']
    errores_rango = 0
    errores_unicos = 0
    errores_comp = 0
    errores_rein = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 49) for b in balls):
            errores_rango += 1
            if errores_rango <= 3:
                print(f"❌ Error rango balotas en ({row['fecha']}): {balls}")
        if len(set(balls)) != 6:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en ({row['fecha']}): {balls}")
        comp = int(row['balotaroja'])
        rein = int(row['balotaroja2'])
        if not (1 <= comp <= 49):
            errores_comp += 1
            if errores_comp <= 3:
                print(f"❌ Error complementario en ({row['fecha']}): {comp}")
        if not (0 <= rein <= 9):
            errores_rein += 1
            if errores_rein <= 3:
                print(f"❌ Error reintegro en ({row['fecha']}): {rein}")

    if errores_rango > 0 or errores_unicos > 0 or errores_comp > 0 or errores_rein > 0:
        print(f"❌ Errores en balotas: {errores_rango} fuera de rango, {errores_unicos} repetidas, {errores_comp} comp, {errores_rein} rein.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en rango [1..49], 6 números únicos, complementario y reintegro válidos")

    # 5. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]} | C={r['balotaroja']} | R={r['balotaroja2']} | Concurso={r['concurso']}")

    # 6. Sincronización con la fuente oficial
    print("\n➡️ Verificando sincronización con la fuente (loteriabonoloto.info)...")
    if hasattr(scraper, 'extraer_ultimo_sorteo_fuente'):
        fuente = scraper.extraer_ultimo_sorteo_fuente()
        db_last = scraper.obtener_ultimo_sorteo_db()
        if fuente:
            print(f"  Último en Fuente: {fuente['fecha']} - Balotas: {fuente['balotas']} C: {fuente.get('complementario')} R: {fuente.get('reintegro')}")
        if db_last:
            print(f"  Último real en BD: {db_last['fecha']} (#{db_last.get('concurso')})")
        if fuente and db_last:
            if str(fuente['fecha']) == str(db_last['fecha']):
                print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
            elif str(fuente['fecha']) > str(db_last['fecha']):
                print(f"ℹ️ Hay sorteo nuevo en fuente pendiente de procesar.")
            else:
                print(f"⚠️ La BD está más avanzada que la web ({db_last['fecha']} > {fuente['fecha']})")

    print("\n==================================================")
    print("🎉 AUDITORÍA DE DATOS DE BONOLOTO COMPLETADA")
    print("==================================================")

if __name__ == "__main__":
    validar_bonoloto()
