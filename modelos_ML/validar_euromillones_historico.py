import sys
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
from sqlalchemy import text

PROJECT_ROOT = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.database import get_engine
from src.euromillones.scraper import EuromillonesScraper

def validar_euromillones_historico():
    print("=" * 50)
    print("Iniciando Validación Histórica para Euromillones (España / Europa)")
    print("Lotería ID: 25 | 5 balotas (1..50) + 2 Estrellas (1..12)")
    print("=" * 50)

    engine = get_engine()
    with engine.connect() as conn:
        total = conn.execute(text("SELECT COUNT(*) FROM resultados_euromillones")).scalar()
        reales = conn.execute(text("SELECT COUNT(*) FROM resultados_euromillones WHERE balota1 > 0")).scalar()
        placeholders = conn.execute(text("SELECT COUNT(*) FROM resultados_euromillones WHERE balota1 = 0")).scalar()
        
        print(f"\n📊 Total registros en BD: {total}")
        print(f"  - Sorteos reales: {reales}")
        print(f"  - Placeholders: {placeholders}")

        if reales == 0:
            print("❌ No hay sorteos reales en la base de datos.")
            return False

        # Rango de fechas
        min_max = conn.execute(text("""
            SELECT MIN(fecha), MAX(fecha)
            FROM resultados_euromillones
            WHERE balota1 > 0
        """)).fetchone()
        print(f"\nRango fechas reales:\n  - Desde: {min_max[0]} hasta: {min_max[1]}")

        # Duplicados
        dups = conn.execute(text("""
            SELECT fecha, sorteo, COUNT(*)
            FROM resultados_euromillones
            GROUP BY fecha, sorteo
            HAVING COUNT(*) > 1;
        """)).fetchall()
        if dups:
            print(f"❌ Se encontraron {len(dups)} duplicados por (fecha, sorteo):")
            for d in dups[:5]:
                print(f"   {d[0]} - {d[1]} (veces: {d[2]})")
            return False
        else:
            print("✅ Cero duplicados en (fecha, sorteo)")

        # Rangos de balotas
        invalid_balls = conn.execute(text("""
            SELECT fecha, balota1, balota2, balota3, balota4, balota5, balotaroja, balotaroja2
            FROM resultados_euromillones
            WHERE balota1 > 0 AND (
                balota1 NOT BETWEEN 1 AND 50 OR
                balota2 NOT BETWEEN 1 AND 50 OR
                balota3 NOT BETWEEN 1 AND 50 OR
                balota4 NOT BETWEEN 1 AND 50 OR
                balota5 NOT BETWEEN 1 AND 50 OR
                balotaroja NOT BETWEEN 1 AND 12 OR
                balotaroja2 NOT BETWEEN 1 AND 12
            );
        """)).fetchall()
        if invalid_balls:
            print(f"❌ Se encontraron {len(invalid_balls)} sorteos con balotas fuera de rango:")
            for ib in invalid_balls[:5]:
                print(f"   {ib}")
            return False
        else:
            print("✅ Todas las balotas están en rango [1..50] y Estrellas en rango [1..12]")

        # Placeholders
        phs = conn.execute(text("""
            SELECT fecha, sorteo, balota1, balota2, balota3, balota4, balota5, balotaroja, balotaroja2, concurso
            FROM resultados_euromillones
            WHERE balota1 = 0
            ORDER BY fecha ASC;
        """)).fetchall()
        print(f"\nPlaceholders encontrados ({len(phs)}):")
        for ph in phs:
            print(f"  - ({ph[0]} - {ph[1]}): Balotas=[{ph[2]}, {ph[3]}, {ph[4]}, {ph[5]}, {ph[6]}] | E1={ph[7]} | E2={ph[8]} | Concurso={ph[9]}")

    # Verificar con la fuente
    print("\n➡️ Verificando sincronización con la fuente (euromillones.com.es)...")
    scraper = EuromillonesScraper()
    fuente = scraper.extraer_ultimo_sorteo_fuente()
    if fuente:
        print(f"  Último en Fuente: {fuente['fecha']} - Balotas: {fuente['balotas']} Estrellas: {fuente['estrellas']}")
        ultimo_db = scraper.obtener_ultimo_sorteo_db()
        print(f"  Último real en BD: {ultimo_db['fecha']} (#{ultimo_db['concurso']})")
        if str(fuente['fecha']) == str(ultimo_db['fecha']):
            print("✅ La base de datos está perfectamente sincronizada con la fuente oficial!")
        elif str(fuente['fecha']) < str(ultimo_db['fecha']):
            print("ℹ️ BD tiene fechas posteriores a la fuente.")
        else:
            print("⚠️ Hay sorteos nuevos en la fuente pendientes de scraping.")

    print("\n" + "=" * 50)
    print("🎉 AUDITORÍA DE DATOS DE EUROMILLONES COMPLETADA")
    print("=" * 50)
    return True

if __name__ == "__main__":
    validar_euromillones_historico()
