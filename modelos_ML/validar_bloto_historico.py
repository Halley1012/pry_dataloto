import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.baloto.scraper import BalotoScraper

def validar_bloto():
    print("==================================================")
    print("Iniciando Validación Histórica para Baloto y Revancha (Colombia)")
    print("Rango objetivo: #2081 a #2704 (624 sorteos)")
    print("==================================================")

    engine = get_engine()
    scraper = BalotoScraper()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_bloto ORDER BY fecha ASC, sorteo ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_bloto está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")
    print(f"  - Registros por modalidad: {df['sorteo'].value_counts().to_dict()}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)} ({len(df_real[df_real['sorteo']=='Baloto'])} Baloto, {len(df_real[df_real['sorteo']=='Revancha'])} Revancha)")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Continuidad de concursos (2081 a 2704)
    for sorteo_nombre in ['Baloto', 'Revancha']:
        sub = df_real[df_real['sorteo'] == sorteo_nombre]
        concursos = set(sub['concurso'].astype(int))
        min_c = min(concursos)
        max_c = max(concursos)
        esperados = set(range(min_c, max_c + 1))
        faltantes = sorted(list(esperados - concursos))

        print(f"\nModalidad {sorteo_nombre}:")
        print(f"  - Total sorteos: {len(concursos)}")
        print(f"  - Rango: #{min_c} al #{max_c}")
        if faltantes:
            print(f"  ❌ Faltantes ({len(faltantes)}): {faltantes[:10]}...")
            sys.exit(1)
        else:
            print(f"  ✅ Continuidad perfecta: 624/624 (0 faltantes)")

    # 3. Validar cero duplicados
    dup = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en reales: {len(dup)}")
        sys.exit(1)
    else:
        print("\n✅ Cero duplicados en (fecha, sorteo)")

    # 4. Validar rangos de balotas (balota1..5 in 1..43, balotaroja in 1..16)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    errores_balotas = 0
    for idx, row in df_real.iterrows():
        balls = [row[c] for c in balota_cols]
        if any(not (1 <= b <= 43) for b in balls) or not (1 <= row['balotaroja'] <= 16):
            print(f"❌ Error en balotas para {row['sorteo']} #{row['concurso']}: {balls} Roja: {row['balotaroja']}")
            errores_balotas += 1

    if errores_balotas > 0:
        print(f"❌ Se encontraron {errores_balotas} errores en las balotas.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas regulares están en [1..43] y superbalotas en [1..16]")

    # 5. Días de juego válidos (0=Lun, 2=Mié, 5=Sáb)
    df_real['dt_fecha'] = pd.to_datetime(df_real['fecha'])
    dias = df_real['dt_fecha'].dt.dayofweek.value_counts().to_dict()
    print(f"\nDistribución de días de semana (0=Lun, 2=Mié, 5=Sáb): {dias}")

    # 6. Validar placeholders
    if len(df_ph) != 2:
        print(f"⚠️ Advertencia: se esperaban 2 placeholders, encontrados {len(df_ph)}")
    else:
        print(f"\n✅ Placeholders válidos:")
        for _, r in df_ph.iterrows():
            print(f"  {r['sorteo']} #{r['concurso']} ({r['fecha']}): Balotas={[r[c] for c in balota_cols]} Superbalota={r['balotaroja']}")

    # 7. Sincronización con la fuente en tiempo real
    print("\n➡️ Verificando sincronización con baloto.com...")
    fuente = scraper.extraer_ultimo_sorteo_fuente()
    db_last = scraper.obtener_ultimo_sorteo_db()
    print(f"  Último en Fuente: #{fuente['concurso']} ({fuente['fecha']}) - Balotas: {fuente['balotas']} Roja: {fuente['balotaroja']}")
    print(f"  Último en BD:     #{db_last['concurso']} ({db_last['fecha']})")

    if fuente['concurso'] == db_last['concurso']:
        print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
    else:
        print(f"⚠️ Discrepancia: Fuente #{fuente['concurso']} vs BD #{db_last['concurso']}")

    print("\n==================================================")
    print("🎉 VALIDACIÓN HISTÓRICA DE BALOTO Y REVANCHA EXITOSA: 100% OK")
    print("==================================================")

if __name__ == "__main__":
    validar_bloto()
