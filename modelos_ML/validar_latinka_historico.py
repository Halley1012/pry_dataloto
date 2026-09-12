import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
import re
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import pandas as pd
from datetime import datetime, date, timedelta
from pathlib import Path
from collections import Counter

sys.path.insert(0, 'd:/pry_dataloto/modelos_ML')
from src.latinka.scraper import LaTinkaScraper, FALLBACK_HISTORICO_500

def main():
    print("==================================================================")
    print("   VALIDACIÓN HISTÓRICA CONTROLADA: LA TINKA (SOLO LECTURA)      ")
    print("==================================================================")
    print("🎯 Rango objetivo: Sorteo #731 -> Sorteo #1330 (600 sorteos esperados)")
    print("🔒 Base de Datos: NO se realizará ninguna escritura en PostgreSQL.")
    print("------------------------------------------------------------------\n")

    scraper = LaTinkaScraper()

    # 1. Ejecutar extracción concurrente sistemática
    print("Iniciando extracción en memoria...")
    df = scraper.extraer_historico_concurrente(desde_concurso=731, hasta_concurso=1330)

    if df.empty:
        print("❌ Error crítico: No se pudieron extraer datos.")
        sys.exit(1)

    print(f"\n📊 Total filas devueltas: {len(df)}")

    # 2. Convertir y ordenar
    df['concurso'] = pd.to_numeric(df['concurso'], errors='coerce')
    df = df.dropna(subset=['concurso'])
    df['concurso'] = df['concurso'].astype(int)
    df['fecha_obj'] = pd.to_datetime(df['fecha']).dt.date
    df = df.sort_values('concurso').reset_index(drop=True)

    # 3. Auditoría de Concursos
    concursos_obtenidos = set(df['concurso'])
    esperados = set(range(731, 1331))
    faltantes = sorted(list(esperados - concursos_obtenidos))
    duplicados = [c for c, count in Counter(df['concurso']).items() if count > 1]
    fuera_de_rango = [c for c in concursos_obtenidos if c < 731 or c > 1330]

    # 4. Auditoría de Bolillas y Boliyapa (La Tinka amplió su rango histórico de 45/50 hasta 54 bolillas)
    MAX_BALOTA_VALIDA = 54
    errores_balotas = []
    balotas_ordenadas_count = 0
    total_revisados = 0

    for idx, row in df.iterrows():
        c = row['concurso']
        f = row['fecha']
        f_dt = row['fecha_obj']
        balls = [row['balota1'], row['balota2'], row['balota3'], row['balota4'], row['balota5'], row['balota6']]
        by = row['balotaroja']
        total_revisados += 1

        # Comprobar rango de balotas (1 a MAX_BALOTA_VALIDA)
        if any(not (1 <= b <= MAX_BALOTA_VALIDA) for b in balls):
            errores_balotas.append(f"#{c} ({f}): Balotas fuera de rango 1..{MAX_BALOTA_VALIDA} -> {balls}")

        # Comprobar si hay balotas repetidas dentro de la jugada
        if len(set(balls)) != 6:
            errores_balotas.append(f"#{c} ({f}): Balotas duplicadas en sorteo -> {balls}")

        # Comprobar boliyapa (1 a MAX_BALOTA_VALIDA)
        if not (1 <= by <= MAX_BALOTA_VALIDA):
            errores_balotas.append(f"#{c} ({f}): Boliyapa fuera de rango 1..{MAX_BALOTA_VALIDA} -> {by}")

        # Comprobar orden original: si balls == sorted(balls), contabilizar
        if balls == sorted(balls):
            balotas_ordenadas_count += 1

    # 5. Auditoría de Fechas y Calendario
    dias_semana_count = Counter([f.weekday() for f in df['fecha_obj']])
    dias_nombres = {0: 'Lunes', 1: 'Martes', 2: 'Miércoles', 3: 'Jueves', 4: 'Viernes', 5: 'Sábado', 6: 'Domingo'}
    excepciones_calendario = []
    for idx, row in df.iterrows():
        f = row['fecha_obj']
        if f.weekday() not in (2, 6): # No es Miércoles ni Domingo
            excepciones_calendario.append(f"#{row['concurso']}: {f} ({dias_nombres[f.weekday()]})")

    # 6. Verificación de Puntos Clave de Unión
    puntos_clave = [
        (760, 761),
        (1017, 1018),
        (1019, 1020),
        (1020, 1021),
        (1329, 1330)
    ]
    detalles_union = []
    for c1, c2 in puntos_clave:
        r1 = df[df['concurso'] == c1]
        r2 = df[df['concurso'] == c2]
        if not r1.empty and not r2.empty:
            f1 = r1.iloc[0]['fecha']
            f2 = r2.iloc[0]['fecha']
            b1 = [r1.iloc[0][f'balota{i}'] for i in range(1, 7)]
            b2 = [r2.iloc[0][f'balota{i}'] for i in range(1, 7)]
            detalles_union.append(
                f"  ✅ #{c1} ({f1}) {b1}  -->  #{c2} ({f2}) {b2}"
            )
        else:
            detalles_union.append(
                f"  ❌ #{c1} ({'OK' if not r1.empty else 'MISSING'}) --> #{c2} ({'OK' if not r2.empty else 'MISSING'})"
            )

    # 7. Imprimir Reporte Formal
    print("\n==================================================================")
    print("                 REPORTE DE AUDITORÍA HISTÓRICA                   ")
    print("==================================================================")
    print(f"Esperados          : {len(esperados)}")
    print(f"Extraídos con éxito: {len(concursos_obtenidos)}")
    print(f"Faltantes          : {len(faltantes)}")
    print(f"Duplicados         : {len(duplicados)}")
    print(f"Fuera de rango     : {len(fuera_de_rango)}")
    print(f"Errores de balotas : {len(errores_balotas)}")
    print("------------------------------------------------------------------")
    print(f"Distribución días  : { {dias_nombres[k]: v for k, v in dias_semana_count.items()} }")
    if excepciones_calendario:
        print(f"ℹ️ Sorteos en días extraordinarios ({len(excepciones_calendario)}):")
        for exc in excepciones_calendario[:10]:
            print(f"   {exc}")
        if len(excepciones_calendario) > 10:
            print(f"   ... y {len(excepciones_calendario) - 10} más.")
    else:
        print("📅 Todas las fechas corresponden estrictamente a Miércoles o Domingo.")

    print("------------------------------------------------------------------")
    print(f"Orden de bolillas  : {balotas_ordenadas_count}/{len(df)} están ordenadas de menor a mayor (natural por azar ~{100*balotas_ordenadas_count/len(df):.1f}%, NO forzado por sorted)")
    print("------------------------------------------------------------------")
    print("Puntos de unión críticos:")
    for d in detalles_union:
        print(d)

    print("------------------------------------------------------------------")
    if len(faltantes) == 0 and len(duplicados) == 0 and len(errores_balotas) == 0 and len(concursos_obtenidos) == 600:
        print("🟢 VALIDACIÓN 100% EXITOSA: El dataset histórico está COMPLETO y CONTINUO.")
        print("   Se autoriza pasar a Fase 3.2 (Backfill con UPSERT en PostgreSQL).")
        return True
    else:
        print("🔴 VALIDACIÓN CON OBSERVACIONES: Revisar faltantes antes de escribir en BD.")
        if faltantes:
            print(f"Faltantes ({len(faltantes)}): {faltantes[:30]}")
        return False

if __name__ == "__main__":
    main()
