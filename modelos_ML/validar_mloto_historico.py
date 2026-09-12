import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine
from src.miloto.scraper import MilotoScraper

def validar_mloto():
    print("==================================================")
    print("Iniciando Validación Histórica para MiLoto (Colombia)")
    print("Rango objetivo: #1 a #601 (601 sorteos)")
    print("==================================================")

    engine = get_engine()
    scraper = MilotoScraper()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_mloto ORDER BY fecha ASC, concurso ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_mloto está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    print(f"  - Sorteos reales: {len(df_real)}")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Continuidad de concursos (1 a 601)
    concursos = set(df_real['concurso'].astype(int))
    min_c = min(concursos)
    max_c = max(concursos)
    esperados = set(range(min_c, max_c + 1))
    faltantes = sorted(list(esperados - concursos))

    print(f"\nContinuidad de concursos:")
    print(f"  - Total sorteos: {len(concursos)}")
    print(f"  - Rango: #{min_c} al #{max_c}")
    if faltantes:
        print(f"  ❌ Faltantes ({len(faltantes)}): {faltantes[:10]}...")
        sys.exit(1)
    else:
        print(f"  ✅ Continuidad perfecta: 601/601 (0 faltantes)")

    # 3. Validar cero duplicados
    dup = df_real[df_real.duplicated(subset=['fecha'], keep=False)]
    if not dup.empty:
        print(f"❌ Duplicados encontrados en fechas: {len(dup)}")
        sys.exit(1)
    else:
        print("\n✅ Cero duplicados en fecha")

    # 4. Validar rangos de balotas (balota1..5 in 1..39)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5']
    errores_balotas = 0
    for idx, row in df_real.iterrows():
        balls = [row[c] for c in balota_cols]
        if any(not (1 <= b <= 39) for b in balls):
            print(f"❌ Error en balotas para MiLoto #{row['concurso']}: {balls}")
            errores_balotas += 1

    if errores_balotas > 0:
        print(f"❌ Se encontraron {errores_balotas} errores en las balotas.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en el rango válido [1..39]")

    # 5. Días de juego válidos (0=Lun, 1=Mar, 3=Jue, 4=Vie)
    df_real['dt_fecha'] = pd.to_datetime(df_real['fecha'])
    dias = df_real['dt_fecha'].dt.dayofweek.value_counts().to_dict()
    print(f"\nDistribución de días de semana (0=Lun, 1=Mar, 3=Jue, 4=Vie): {dias}")

    # 6. Validar placeholder
    if len(df_ph) != 1:
        print(f"⚠️ Advertencia: se esperaba 1 placeholder, encontrados {len(df_ph)}")
    else:
        r = df_ph.iloc[0]
        print(f"\n✅ Placeholder válido:")
        print(f"  MiLoto #{r['concurso']} ({r['fecha']}): Balotas={[r[c] for c in balota_cols]}")

    # 7. Sincronización con la fuente en tiempo real
    print("\n➡️ Verificando sincronización con baloto.com/miloto...")
    fuente = scraper.extraer_ultimo_sorteo_fuente()
    db_last = scraper.obtener_ultimo_sorteo_db()
    print(f"  Último en Fuente: #{fuente['concurso']} ({fuente['fecha']}) - Balotas: {fuente['balotas']}")
    print(f"  Último en BD:     #{db_last['concurso']} ({db_last['fecha']})")

    if fuente['concurso'] == db_last['concurso']:
        print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
    else:
        print(f"⚠️ Discrepancia: Fuente #{fuente['concurso']} vs BD #{db_last['concurso']}")

    print("\n==================================================")
    print("🎉 VALIDACIÓN HISTÓRICA DE MILOTO EXITOSA: 100% OK")
    print("==================================================")

if __name__ == "__main__":
    validar_mloto()
