import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from pathlib import Path
from datetime import datetime
import pandas as pd
from sqlalchemy import text
import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from config.database import get_engine

def validar_duplasena():
    print("==================================================")
    print("Iniciando Validación Histórica para Dupla Sena (Brasil)")
    print("Lotería ID: 31 | 2 modalidades (6 balotas c/u en rango 1..50)")
    print("==================================================")

    engine = get_engine()

    # 1. Auditoría de datos en base de datos
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM resultados_duplasena ORDER BY concurso ASC, sorteo ASC;"), conn)

    if df.empty:
        print("❌ Error: resultados_duplasena está vacía.")
        sys.exit(1)

    print(f"\n📊 Total registros en BD: {len(df)}")

    df_real = df[df['balota1'] > 0].copy()
    df_ph = df[df['balota1'] == 0].copy()

    s1 = df_real[df_real['sorteo'] == 'Dupla Sena']
    s2 = df_real[df_real['sorteo'] == 'Dupla Sena 2']

    print(f"  - Sorteos reales: {len(df_real)} (Dupla Sena: {len(s1)}, Dupla Sena 2: {len(s2)})")
    print(f"  - Placeholders: {len(df_ph)}")

    # 2. Concursos y Fechas de sorteos reales
    min_c = int(s1['concurso'].min())
    max_c = int(s1['concurso'].max())
    print(f"\nRango concursos reales:")
    print(f"  - Desde: #{min_c} hasta: #{max_c} (Total esperado: {max_c - min_c + 1} por modalidad)")
    print(f"Rango fechas reales:")
    print(f"  - Desde: {df_real['fecha'].min()} hasta: {df_real['fecha'].max()}")

    # 3. Continuidad de concursos (cero huecos)
    c_set1 = set(s1['concurso'].dropna().astype(int))
    c_set2 = set(s2['concurso'].dropna().astype(int))
    missing1 = [c for c in range(min_c, max_c + 1) if c not in c_set1]
    missing2 = [c for c in range(min_c, max_c + 1) if c not in c_set2]
    if missing1 or missing2:
        print(f"❌ Huecos en concursos: Sorteo 1={missing1}, Sorteo 2={missing2}")
        sys.exit(1)
    else:
        print(f"✅ Secuencia de concursos 100% continua (#2604 -> #{max_c}, {len(c_set1)} sorteos consecutivos)")

    # 4. Validar cero duplicados
    dup_f = df_real[df_real.duplicated(subset=['fecha', 'sorteo'], keep=False)]
    if not dup_f.empty:
        print(f"❌ Duplicados encontrados en (fecha, sorteo): {len(dup_f)}")
        sys.exit(1)
    else:
        print("✅ Cero duplicados en (fecha, sorteo)")

    # 5. Validar rangos de balotas (1..50, 6 números únicos por sorteo)
    balota_cols = ['balota1', 'balota2', 'balota3', 'balota4', 'balota5', 'balota6']
    errores_rango = 0
    errores_unicos = 0
    for idx, row in df_real.iterrows():
        balls = [int(row[c]) for c in balota_cols]
        if any(not (1 <= b <= 50) for b in balls):
            errores_rango += 1
            if errores_rango <= 3:
                print(f"❌ Error rango balotas en concurso #{row['concurso']} ({row['fecha']} - {row['sorteo']}): {balls}")
        if len(set(balls)) != 6:
            errores_unicos += 1
            if errores_unicos <= 3:
                print(f"❌ Números repetidos en concurso #{row['concurso']} ({row['fecha']} - {row['sorteo']}): {balls}")

    if errores_rango > 0 or errores_unicos > 0:
        print(f"❌ Errores en balotas: {errores_rango} fuera de rango, {errores_unicos} repetidas.")
        sys.exit(1)
    else:
        print("✅ Todas las balotas están en rango [1..50] con 6 números únicos por sorteo en ambas modalidades")

    # 6. Placeholders
    print(f"\nPlaceholders encontrados ({len(df_ph)}):")
    for _, r in df_ph.iterrows():
        print(f"  - Concurso #{r['concurso']} ({r['fecha']} - {r['sorteo']}): Balotas={[r[c] for c in balota_cols]}")

    # 7. Sincronización con API de Caixa
    print("\n➡️ Verificando sincronización con la API oficial de Caixa...")
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
        }
        r = requests.get("https://servicebus2.caixa.gov.br/portaldeloterias/api/duplasena", headers=headers, timeout=10)
        if r.status_code == 200:
            data = r.json()
            concurso_caixa = int(data.get("numero"))
            fecha_caixa = data.get("dataApuracao")
            dezenas_ordem = data.get("dezenasSorteadasOrdemSorteio") or []
            print(f"  Último sorteo en Caixa: #{concurso_caixa} ({fecha_caixa}) -> {dezenas_ordem[:6]} / {dezenas_ordem[6:]}")
            print(f"  Último sorteo en BD:    #{max_c} ({s1.iloc[-1]['fecha']})")
            if concurso_caixa == max_c:
                print("✅ La base de datos está perfectamente sincronizada con la fuente oficial Caixa!")
            elif concurso_caixa > max_c:
                print(f"⚠️ Hay {concurso_caixa - max_c} sorteo(s) nuevo(s) en la fuente oficial Caixa")
            else:
                print(f"ℹ️ La base de datos tiene sorteos más avanzados (#{max_c} vs #{concurso_caixa})")
        else:
            print(f"⚠️ Caixa API respondió con status {r.status_code}")
    except Exception as e:
        print(f"⚠️ No se pudo conectar con Caixa API: {e}")

    print("\n==================================================")
    print("✅ Validación de Dupla Sena completada exitosamente!")
    print("==================================================")

if __name__ == "__main__":
    validar_duplasena()
