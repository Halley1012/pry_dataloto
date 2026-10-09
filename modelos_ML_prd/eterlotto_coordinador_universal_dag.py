"""Eterlotto | coordinador universal de sorteos (Airflow 3.1.x).

- Lee loteria_horarios respetando la zona horaria de cada lotería.
- Espera tres horas desde el sorteo y recupera ventanas tras apagados.
- Agrupa varios sorteos elegibles en UNA ejecución por motor.
- Consulta estados mediante API pública Airflow 3, con JWT de /auth/token.
- Selecciona máximo UN DAG por ciclo y ninguno si otro DAG de loterías
  está ejecutándose/en cola, o la API no puede verificarse.
- Reconcilia runs existentes (manuales/programados) completados después del sorteo.
- Nunca deduce que un resultado se publicó solo por un estado success;
  la cobertura significa únicamente que el DAG terminó exitosamente.
- No reintenta automáticamente runs fallidos; no modifica scrapers.

Por defecto: SOLO SIMULACIÓN (ETERLOTTO_COORDINATOR_LIVE=false).
Credenciales: ETERLOTTO_COORDINATOR_API_USER / _PASSWORD en env_file
Docker del worker. NO escribir claves dentro de este archivo.
"""
from __future__ import annotations

import json
import os
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.trigger_dagrun import TriggerDagRunOperator
from sqlalchemy import text

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

DAG_SUFFIXES = frozenset({
    '5deoro', 'bloto', 'bonoloto', 'chispazo', 'double_play', 'duplasena',
    'el_gordo', 'eurodreams', 'eurojackpot', 'euromillones',
    'ganadiario', 'kabala', 'latinka', 'lotto_6aus49',
    'lotto_america', 'lotto_cr', 'lotto_fr', 'maismilionaria',
    'megamillions', 'megasena', 'melateretro', 'melate',
    'millionaire_life', 'mloto', 'powerball', 'primitiva',
    'quina', 'thunderball', 'totoloto',
})
ACTIVE_STATES = {'running', 'queued', 'scheduled'}


def _route_to_suffix(route):
    suffix = (route or '').strip().lower().replace('-', '_')
    return suffix if suffix in DAG_SUFFIXES else None


def _api_request(base, path, token=None, body=None):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    if body is not None:
        headers['Content-Type'] = 'application/json'
    request = Request(
        base + path,
        data=json.dumps(body).encode('utf-8') if body is not None else None,
        headers=headers,
        method='POST' if body is not None else 'GET',
    )
    with urlopen(request, timeout=12) as response:
        return json.load(response)


def _api_token(base):
    """Un JWT nuevo en cada ciclo; no depende de token temporal copiado."""
    token = os.getenv('ETERLOTTO_COORDINATOR_API_TOKEN', '').strip()
    if token:
        return token  # Opción avanzada; un token estático puede caducar.
    username = os.getenv('ETERLOTTO_COORDINATOR_API_USER', '').strip()
    password = os.getenv('ETERLOTTO_COORDINATOR_API_PASSWORD', '')
    if not username or not password:
        raise RuntimeError('Faltan ETERLOTTO_COORDINATOR_API_USER/PASSWORD en el worker')
    result = _api_request(base, '/auth/token', body={
        'username': username, 'password': password,
    })
    token = result.get('access_token')
    if not token:
        raise RuntimeError('La API no entregó access_token')
    return token


def _runs_por_dag(base, token, dag_id):
    query = urlencode({'limit': 100, 'order_by': '-logical_date'})
    path = f"/api/v2/dags/{quote(dag_id, safe='')}/dagRuns?{query}"
    payload = _api_request(base, path, token=token)
    runs = payload.get('dag_runs')
    if not isinstance(runs, list):
        raise RuntimeError(f'Formato de respuesta de runs inesperado en {dag_id}')
    return runs


def _fecha_api(value):
    """Normaliza fechas de la API REST Airflow 3 a UTC."""
    if not value:
        return None
    if isinstance(value, datetime):
        dt = value
    else:
        try:
            dt = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        except (ValueError, TypeError):
            return None
    return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)


def _estado(runs, run_id, fecha_elegible):
    """Verifica el run exacto y reconciliación histórica desde un sorteo elegible.

    Se considera cubierta una ventana solo si un DAG existente (programado,
    manual o del coordinador) TERMINÓ exitosamente después del instante en
    que el sorteo alcanzó el margen de espera. Esto NO prueba presencia de
    resultados en Supabase: requiere comprobación funcional adicional.
    """
    for run in runs:
        if run.get('dag_run_id', run.get('run_id')) == run_id:
            state = (run.get('state') or '').lower()
            return {
                'success': 'COMPLETADO', 'failed': 'FALLIDO',
                'running': 'EN_CURSO', 'queued': 'EN_COLA',
                'scheduled': 'EN_COLA',
            }.get(state, 'DESCONOCIDO')

    if any((run.get('state') or '').lower() in ACTIVE_STATES for run in runs):
        return 'OTRO_RUN_ACTIVO'

    # Otros run_id: reconocer trabajos que ya corrieron normalmente.
    # Si hubo run success posterior a la hora elegible, no duplicar.
    for run in runs:
        if (run.get('state') or '').lower() != 'success':
            continue
        ended = _fecha_api(run.get('end_date'))
        if ended is not None and ended >= fecha_elegible:
            return 'CUBIERTO_POR_RUN_EXISTENTE'

    # Si el último trabajo posterior a la hora elegible falló, NO reintentar
    # automáticamente: intervención manual o una política explícita de retry.
    for run in runs:
        if (run.get('state') or '').lower() != 'failed':
            continue
        ended = _fecha_api(run.get('end_date'))
        if ended is not None and ended >= fecha_elegible:
            return 'FALLIDO_ANTERIOR'

    return 'PENDIENTE'


def _hora(draw_time):
    if isinstance(draw_time, str):
        return datetime.strptime(draw_time[:8], '%H:%M:%S').time()
    return draw_time


def seleccionar_pendientes(**context):
    from config.database import get_engine

    now_utc = datetime.now(timezone.utc)
    delay_hours = max(0, int(os.getenv('ETERLOTTO_COORDINATOR_DELAY_HOURS', '3')))
    lookback_days = max(1, int(os.getenv('ETERLOTTO_COORDINATOR_LOOKBACK_DAYS', '3')))
    live = os.getenv('ETERLOTTO_COORDINATOR_LIVE', 'false').lower().strip() == 'true'
    allowed = {
        item.strip().lower().removeprefix('eterlotto_ejecucion_')
        for item in os.getenv('ETERLOTTO_COORDINATOR_ALLOWED_DAGS', '').split(',')
        if item.strip()
    }
    if live and not allowed:
        print('BLOQUEADO: modo live exige ETERLOTTO_COORDINATOR_ALLOWED_DAGS explícito')
        return []
    base = os.getenv('ETERLOTTO_COORDINATOR_API_URL', 'http://airflow-apiserver:8080').rstrip('/')
    if not base.startswith(('http://', 'https://')):
        print('BLOQUEADO: URL de API inválida')
        return []

    sql = text('''
        SELECT l.id AS loteria_id, l.nombre, l.route, l.pais_id,
               h.id AS horario_id, h.dia_semana, h.hora_sorteo,
               COALESCE(NULLIF(l.timezone, ''), p.timezone_default) AS tz
        FROM loteria_horarios h
        JOIN loterias l ON l.id = h.loteria_id
        JOIN paises p ON p.id = l.pais_id
        WHERE COALESCE(h.activo, TRUE) = TRUE
          AND COALESCE(l.activa, TRUE) = TRUE
          AND COALESCE(NULLIF(l.timezone, ''), p.timezone_default) IS NOT NULL
    ''')
    with get_engine().connect() as conn:
        rows = [dict(row) for row in conn.execute(sql).mappings()]

    grouped = {}
    unmapped = set()
    for item in rows:
        suffix = _route_to_suffix(item['route'])
        if suffix is None:
            unmapped.add(str(item['route']))
            continue
        try:
            zone = ZoneInfo(item['tz'])
        except (KeyError, ValueError, ZoneInfoNotFoundError):
            print(f"Zona horaria inválida: {item['nombre']} / {item['tz']}")
            continue
        local_now = now_utc.astimezone(zone)
        for days_ago in range(lookback_days + 1):
            day = local_now.date() - timedelta(days=days_ago)
            if day.isoweekday() != int(item['dia_semana']):
                continue
            draw_local = datetime.combine(day, _hora(item['hora_sorteo']), tzinfo=zone)
            draw_utc = draw_local.astimezone(timezone.utc)
            if now_utc < draw_utc + timedelta(hours=delay_hours):
                continue
            grouped.setdefault(suffix, []).append({
                'draw_utc': draw_utc,
                'loteria_id': int(item['loteria_id']),
                'horario_id': int(item['horario_id']),
            })

    if unmapped:
        print('Rutas sin DAG reconocido:', sorted(unmapped))

    # Autenticación una vez por ciclo. Cualquier fallo cierra la ejecución.
    try:
        token = _api_token(base)
        # Verifica TODAS las loterías, incluso si no hay sorteo hoy, para
        # evitar lanzar más trabajo si alguna ya se está ejecutando.
        states_by_dag = {}
        for suffix in sorted(DAG_SUFFIXES):
            dag_id = f'eterlotto_ejecucion_{suffix}'
            try:
                states_by_dag[dag_id] = _runs_por_dag(base, token, dag_id)
            except HTTPError as exc:
                if exc.code == 404 and suffix not in grouped:
                    continue  # DAG todavía no instalado; no es candidato.
                raise RuntimeError(f'API HTTP {exc.code} para {dag_id}') from exc
    except (RuntimeError, HTTPError, URLError, TimeoutError, OSError, ValueError) as exc:
        print(f'BLOQUEADO: estados de Airflow 3 no verificables: {type(exc).__name__}: {exc}')
        print('Coordinador: SIN DISPAROS; revisa URL, credenciales y permisos del worker')
        return []

    otros_activos = sorted(
        dag_id for dag_id, runs in states_by_dag.items()
        if any((run.get('state') or '').lower() in ACTIVE_STATES for run in runs)
    )
    candidates = []
    counts = Counter()
    for suffix, events in sorted(grouped.items()):
        # El último sorteo es la identidad estable del conjunto recuperable.
        latest = max(e['draw_utc'] for e in events)
        oldest = min(e['draw_utc'] for e in events)
        draw_key = latest.strftime('%Y%m%dT%H%MZ')
        dag_id = f'eterlotto_ejecucion_{suffix}'
        run_id = f'coordinador__{suffix}__{draw_key}'
        runs = states_by_dag.get(dag_id)
        state = _estado(runs, run_id, latest + timedelta(hours=delay_hours)) if runs is not None else 'DAG_NO_EXISTE'
        counts[state] += 1
        candidate = {
            'trigger_dag_id': dag_id,
            'trigger_run_id': run_id,
            'conf': {
                'origen': 'coordinador_universal',
                'sorteo_utc': draw_key,
                'sorteos_utc': sorted({e['draw_utc'].strftime('%Y%m%dT%H%MZ') for e in events}),
                'loteria_ids': sorted({e['loteria_id'] for e in events}),
            },
        }
        if state == 'PENDIENTE' and (not live or suffix in allowed):
            candidates.append((oldest, candidate))
        print(f'REVISAR {dag_id} | {run_id} | sorteos_agrupados={len(events)} | estado={state}')

    # Solo un candidato por ciclo; el resto espera al siguiente turno.
    # En live, la allowlist explícita controla la prueba canaria.
    # FIFO: procesar primero el lote más antiguo. No encadenar 27 DAGs.
    candidates.sort(key=lambda pair: (pair[0], pair[1]['trigger_dag_id']))
    selected = [candidates[0][1]] if candidates and not otros_activos else []
    if otros_activos:
        print('ESPERAR: hay DAGs en curso/cola:', otros_activos)
    if live:
        print('MODO_LIVE_AUTORIZADO_PARA:', sorted(allowed))
    if selected:
        item = selected[0]
        print(f"{'DISPARAR' if live else 'TURNO_SIMULADO'} "
              f"{item['trigger_dag_id']} | {item['trigger_run_id']}")
    print(f'Coordinador: {sum(len(x) for x in grouped.values())} sorteos elegibles, '
          f'{len(grouped)} motores, estados={dict(counts)}, '
          f'seleccionados={len(selected)}, live={live}')
    return selected if live else []


with DAG(
    dag_id='eterlotto_coordinador_universal',
    description='Coordinador Airflow 3 con reconciliación histórica y turnos seguros',
    schedule='*/10 * * * *',
    start_date=datetime(2026, 10, 1, tzinfo=timezone.utc),
    catchup=False,
    max_active_runs=1,
    default_args={'owner': 'eterlotto', 'retries': 1,
                  'retry_delay': timedelta(minutes=5)},
    tags=['eterlotto', 'coordinador'],
) as dag:
    seleccionar = PythonOperator(
        task_id='seleccionar_sorteos_pendientes',
        python_callable=seleccionar_pendientes,
    )
    disparar = TriggerDagRunOperator.partial(
        task_id='disparar_dag_individual',
        wait_for_completion=False,
        reset_dag_run=False,
        skip_when_already_exists=True,
    ).expand_kwargs(seleccionar.output)
