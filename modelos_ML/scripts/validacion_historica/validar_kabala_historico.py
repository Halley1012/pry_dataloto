import sys
from pathlib import Path
from datetime import datetime
import pandas as pd

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from src.kabala.scraper import KabalaScraper

def validar_historico():
    print("==================================================")
    print("Iniciando Validación Histórica en Memoria para Kábala y Chau Chamba")
    print("Rango objetivo: #1642 a #2012 (371 sorteos)")
    print("==================================================")

    scraper = KabalaScraper()
    df = scraper.extraer_historico_concurrente(desde_concurso=1642, hasta_concurso=2012)

    if df.empty:
        print("❌ Error: DataFrame extraído está vacío.")
        sys.exit(1)

    print(f"\n📊 Total registros extraídos en memoria: {len(df)}")
    
    # 1. Separar Kábala y Chau Chamba
    df_kabala = df[df['sorteo'] == 'Kábala'].copy()
    df_chamba = df[df['sorteo'] == 'Chau Chamba'].copy()

    print(f"  - Registros 'Kábala': {len(df_kabala)}")
    print(f"  - Registros 'Chau Chamba': {len(df_chamba)}")

    if len(df_kabala) != 371 or len(df_chamba) != 371:
        print(f"❌ Error en cantidad: esperados 371 de cada uno, obtenidos {len(df_kabala)} Kábala y {len(df_chamba)} Chau Chamba.")
        sys.exit(1)

    # 2. Validar continuidad de concursos (1642 a 2012)
    concursos_k = set(df_kabala['concurso'].astype(int))
    concursos_c = set(df_chamba['concurso'].astype(int))
    esperados = set(range(1642, 2013))

    faltantes_k = sorted(list(esperados - concursos_k))
    faltantes_c = sorted(list(esperados - concursos_c))

    if faltantes_k or faltantes_c:
        print(f"❌ Concursos faltantes en Kábala: {faltantes_k}")
        print(f"❌ Concursos faltantes en Chau Chamba: {faltantes_c}")
        sys.exit(1)
    else:
        print("✅ Continuidad de concursos: 371/371 perfectos (0 faltantes)")

    # 3. Validar duplicados
    dup_k = df_kabala[df_kabala.duplicated(subset=['concurso'], keep=False)]
    dup_c = df_chamba[df_chamba.duplicated(subset=['concurso'], keep=False)]

    if not dup_k.empty or not dup_c.empty:
        print(f"❌ Concursos duplicados detectados: {len(dup_k)} en Kábala, {len(dup_c)} en Chau Chamba")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en concursos")

    # 4. Validar integridad de balotas (1..40 y sin ceros en real)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5', 'balota6']
    errores_balotas = 0
    for idx, row in df.iterrows():
        balls = [row[c] for c in balota_cols]
        if any(not (1 <= b <= 40) for b in balls):
            print(f"❌ Error balota fuera de rango en sorteo {row['sorteo']} #{row['concurso']}: {balls}")
            errores_balotas += 1

    if errores_balotas > 0:
        print(f"❌ Se encontraron {errores_balotas} errores en las balotas.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en el rango válido [1..40]")

    # 5. Validar fechas válidas
    try:
        df['dt_fecha'] = pd.to_datetime(df['fecha'])
        dias_semana = df['dt_fecha'].dt.dayofweek.value_counts().to_dict()
        print(f"Distribución de días de semana (1=Mar, 3=Jue, 5=Sáb): {dias_semana}")
    except Exception as e:
        print(f"❌ Error parseando fechas: {e}")
        sys.exit(1)

    # 6. Muestra de validación del fallback 1690
    fb_k = df[(df['concurso'] == 1690) & (df['sorteo'] == 'Kábala')].iloc[0]
    fb_c = df[(df['concurso'] == 1690) & (df['sorteo'] == 'Chau Chamba')].iloc[0]
    print(f"\nSorteo #1690 verificado:")
    print(f"  Kábala: {fb_k['fecha']} -> {[fb_k[c] for c in balota_cols]}")
    print(f"  Chau Chamba: {fb_c['fecha']} -> {[fb_c[c] for c in balota_cols]}")

    # 7. Muestra del sorteo más reciente #2012
    rec_k = df[(df['concurso'] == 2012) & (df['sorteo'] == 'Kábala')].iloc[0]
    rec_c = df[(df['concurso'] == 2012) & (df['sorteo'] == 'Chau Chamba')].iloc[0]
    print(f"\nSorteo #2012 verificado:")
    print(f"  Kábala: {rec_k['fecha']} -> {[rec_k[c] for c in balota_cols]}")
    print(f"  Chau Chamba: {rec_c['fecha']} -> {[rec_c[c] for c in balota_cols]}")

    print("\n==================================================")
    print("🎉 VALIDACIÓN HISTÓRICA EN MEMORIA EXITOSA: 100% OK")
    print("==================================================")

if __name__ == "__main__":
    validar_historico()
