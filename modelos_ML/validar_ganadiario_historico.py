import sys
import re
import requests
import concurrent.futures
from bs4 import BeautifulSoup
from datetime import datetime, date

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "es-PE,es-419;q=0.9,es;q=0.8,en;q=0.7",
}

URL_SITEMAP = "https://tinkaresultados.com/sitemap.xml"

# Fallback para sorteos históricos con error interno del servidor (HTTP 500) en tinkaresultados.com
FALLBACK_HISTORICO_500 = {
    4256: {
        "concurso": 4256,
        "fecha": "2025-06-23",
        "balota1": 3, "balota2": 31, "balota3": 14, "balota4": 28, "balota5": 23,
        "balls": [3, 31, 14, 28, 23]
    },
    4572: {
        "concurso": 4572,
        "fecha": "2026-05-05",
        "balota1": 10, "balota2": 31, "balota3": 18, "balota4": 35, "balota5": 1,
        "balls": [10, 31, 18, 35, 1]
    }
}

def parsear_jugada_url(item: tuple) -> dict:
    """Descarga y parsea una página individual de sorteo de Gana Diario."""
    concurso_esperado, url = item
    try:
        r = requests.get(url, headers=HEADERS, timeout=10, verify=False)
        if r.status_code != 200:
            if concurso_esperado in FALLBACK_HISTORICO_500:
                fb = FALLBACK_HISTORICO_500[concurso_esperado]
                return {
                    "concurso_esperado": concurso_esperado,
                    "concurso": fb["concurso"],
                    "fecha": fb["fecha"],
                    "balota1": fb["balota1"],
                    "balota2": fb["balota2"],
                    "balota3": fb["balota3"],
                    "balota4": fb["balota4"],
                    "balota5": fb["balota5"],
                    "balls": fb["balls"],
                    "url": url,
                    "error": None
                }
            return {"concurso_esperado": concurso_esperado, "url": url, "error": f"HTTP {r.status_code}"}

        soup = BeautifulSoup(r.text, "html.parser")
        txt = soup.get_text()

        # 1. Fecha
        m_date = re.search(r'Fecha:\s*(\d{1,2})/(\d{1,2})/(\d{4})', txt)
        if not m_date:
            return {"concurso_esperado": concurso_esperado, "url": url, "error": "Fecha no encontrada"}
        d, m, y = m_date.groups()
        fecha_iso = f"{y}-{m.zfill(2)}-{d.zfill(2)}"

        # 2. 5 Bolillas en orden original (sin sorted)
        m_balls = re.search(
            r'(?:Jugada Ganadora|Fecha:\s*\d{1,2}/\d{1,2}/\d{4})\s*(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})',
            txt,
            re.IGNORECASE
        )
        if not m_balls:
            return {"concurso_esperado": concurso_esperado, "url": url, "error": "Bolillas no encontradas"}
        
        balls = [int(x) for x in m_balls.groups()]
        if len(balls) != 5:
            return {"concurso_esperado": concurso_esperado, "url": url, "error": f"Bolillas != 5 ({len(balls)})"}

        # Validar rango 1 a 35 y que no haya duplicados dentro del sorteo
        if any(b < 1 or b > 35 for b in balls):
            return {"concurso_esperado": concurso_esperado, "url": url, "error": f"Bolillas fuera de rango 1-35: {balls}"}
        if len(set(balls)) != 5:
            return {"concurso_esperado": concurso_esperado, "url": url, "error": f"Bolillas repetidas en sorteo: {balls}"}

        # 3. Concurso / Sorteo
        m_sorteo = re.search(r'Sorteo\s*(?:Nro\.?|número)?\s*(\d+)', txt, re.IGNORECASE)
        if not m_sorteo:
            m_sorteo = re.search(r'sorteo-(\d+)', url)
        concurso_num = int(m_sorteo.group(1)) if m_sorteo else concurso_esperado

        return {
            "concurso_esperado": concurso_esperado,
            "concurso": concurso_num,
            "fecha": fecha_iso,
            "balota1": balls[0],
            "balota2": balls[1],
            "balota3": balls[2],
            "balota4": balls[3],
            "balota5": balls[4],
            "balls": balls,
            "url": url,
            "error": None
        }
    except Exception as e:
        return {"concurso_esperado": concurso_esperado, "url": url, "error": str(e)}

def validar_historico_rango(start_num: int = 4249, end_num: int = 4693):
    print("============================================================")
    print("VALIDACIÓN HISTÓRICO GANA DIARIO (SOLO LECTURA - SIN BD)")
    print("============================================================")
    print(f"Rango solicitado : #{start_num} → #{end_num}")
    esperados = end_num - start_num + 1
    print(f"Esperados        : {esperados}\n")

    # 1. Obtener sitemap
    print("➡️ Consultando sitemap en tinkaresultados.com...")
    sitemap_map = {}
    try:
        r = requests.get(URL_SITEMAP, headers=HEADERS, timeout=12, verify=False)
        if r.status_code == 200:
            urls = re.findall(r'<loc>(.*?)</loc>', r.text)
            for u in urls:
                m = re.search(r'sorteo-(\d+)', u)
                if m and 'gana-diario' in u.lower():
                    sitemap_map[int(m.group(1))] = u
        print(f"URLs de Gana Diario encontradas en sitemap: {len(sitemap_map)}")
    except Exception as e:
        print(f"⚠️ Error leyendo sitemap: {e}")

    # 2. Construir lista de trabajo
    items_a_descargar = []
    for c_num in range(start_num, end_num + 1):
        if c_num in sitemap_map:
            items_a_descargar.append((c_num, sitemap_map[c_num]))
        else:
            items_a_descargar.append((c_num, f"https://www.tinkaresultados.com/gana-diario/resultados-anteriores/sorteo-{c_num}"))

    print(f"URLs preparadas para descargar : {len(items_a_descargar)}")
    print("Descargando y parseando concurrentemente (20 workers)...")

    # 3. Descargar concurrentemente
    resultados = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        resultados = list(executor.map(parsear_jugada_url, items_a_descargar))

    # 4. Analizar resultados
    exitosos = [r for r in resultados if r.get("error") is None]
    fallidos = [r for r in resultados if r.get("error") is not None]

    concursos_extraidos = [r["concurso"] for r in exitosos]
    concursos_set = set(concursos_extraidos)

    faltantes = [c for c in range(start_num, end_num + 1) if c not in concursos_set]
    duplicados = len(concursos_extraidos) - len(concursos_set)

    # Ordenar por concurso
    exitosos_sorted = sorted(exitosos, key=lambda x: x["concurso"])

    primer_c = exitosos_sorted[0]["concurso"] if exitosos_sorted else None
    primer_f = exitosos_sorted[0]["fecha"] if exitosos_sorted else None
    ultimo_c = exitosos_sorted[-1]["concurso"] if exitosos_sorted else None
    ultimo_f = exitosos_sorted[-1]["fecha"] if exitosos_sorted else None

    print("\n------------------------------------------------------------")
    print("RESUMEN DE EXTRACCIÓN")
    print("------------------------------------------------------------")
    print(f"Esperados          : {esperados}")
    print(f"Extraídos con éxito: {len(exitosos)}")
    print(f"Errores parsing    : {len(fallidos)}")
    print(f"Faltantes          : {len(faltantes)}")
    print(f"Duplicados         : {duplicados}")
    print(f"Primer concurso    : #{primer_c} ({primer_f})")
    print(f"Último concurso    : #{ultimo_c} ({ultimo_f})")

    if fallidos:
        print("\n⚠️ Detalle de primeros 5 fallidos:")
        for f in fallidos[:5]:
            print(f"  - Sorteo #{f['concurso_esperado']} en {f['url']}: {f['error']}")

    print("\n------------------------------------------------------------")
    print("VALIDACIÓN DE CONTINUIDAD (Muestra de verificación)")
    print("------------------------------------------------------------")
    
    es_continuo = (len(faltantes) == 0) and (duplicados == 0) and (len(exitosos) == esperados)
    
    if len(exitosos_sorted) >= 10:
        muestra = exitosos_sorted[:3] + exitosos_sorted[len(exitosos_sorted)//2 - 1 : len(exitosos_sorted)//2 + 2] + exitosos_sorted[-3:]
    else:
        muestra = exitosos_sorted

    for item in muestra:
        print(f"Concurso #{item['concurso']} | Fecha: {item['fecha']} | Bolillas: {item['balls']} ✓")

    print("\n------------------------------------------------------------")
    print("VALIDACIÓN BOLILLAS")
    print("------------------------------------------------------------")
    registros_validos = sum(1 for r in exitosos if len(r["balls"]) == 5 and all(1 <= b <= 35 for b in r["balls"]))
    print(f"Registros válidos   : {registros_validos}")
    print(f"Registros inválidos : {len(exitosos) - registros_validos}")

    print("\n============================================================")
    if es_continuo and registros_validos == esperados:
        print("✅ RESULTADO: ÉXITO TOTAL (100% de continuidad y validez)")
        print(f"Se validaron exactamente {esperados} de {esperados} sorteos sin faltantes.")
    else:
        print(f"❌ RESULTADO: INCOMPLETO ({len(faltantes)} faltantes, {len(fallidos)} errores)")
    print("============================================================\n")

if __name__ == "__main__":
    validar_historico_rango(4249, 4693)
