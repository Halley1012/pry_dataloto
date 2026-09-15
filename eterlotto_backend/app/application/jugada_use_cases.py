from datetime import datetime, date, timedelta, timezone
from typing import List, Dict, Any, Optional

from app.domain.ports import JugadaRepositoryPort

def _normalize_numeros(val) -> List[int]:
    if val is None:
        return []
    if isinstance(val, list):
        return [int(x) for x in val]
    if isinstance(val, tuple):
        return [int(x) for x in val]
    if isinstance(val, str):
        s = val.strip('{}() []')
        if not s:
            return []
        return [int(p.strip()) for p in s.split(',') if p.strip()]
    try:
        return [int(val)]
    except Exception:
        return []

def _format_fecha(val) -> str:
    if val is None:
        return ""
    if hasattr(val, 'strftime'):
        return val.strftime('%Y-%m-%d')
    return str(val)[:10]

class JugadaUseCases:
    def __init__(self, jugada_repo: JugadaRepositoryPort):
        self.jugada_repo = jugada_repo

    async def guardar_jugada(self, tipo: str, user_id: int, numeros: List[int], fecha_sorteo: Optional[str] = None, loteria_id: Optional[int] = None) -> Dict[str, Any]:
        # UTC evita imponer una zona horaria de un país a una aplicación global.
        now = datetime.now(timezone.utc)
        fecha_guardado = now

        sorteo_date: Optional[date] = None
        if fecha_sorteo and isinstance(fecha_sorteo, str) and fecha_sorteo.strip():
            try:
                clean_str = fecha_sorteo.replace('"', '').replace("'", "").strip().split("T")[0]
                sorteo_date = datetime.strptime(clean_str, "%Y-%m-%d").date()
            except Exception:
                sorteo_date = now.date()
        else:
            sorteo_date = now.date()

        # La jugada expira 7 días después del sorteo.
        expira = datetime(
            sorteo_date.year, sorteo_date.month, sorteo_date.day,
            23, 59, 59, tzinfo=timezone.utc,
        ) + timedelta(days=7)

        numeros_clean = [int(n) for n in numeros]
        return await self.jugada_repo.create_jugada(
            tipo, user_id, numeros_clean, sorteo_date, fecha_guardado, expira,
            loteria_id=loteria_id,
        )

    async def listar_jugadas(self, tipo: str, user_id: int, fecha: Optional[str] = None, loteria_id: Optional[int] = None) -> List[Dict[str, Any]]:
        rows = await self.jugada_repo.list_jugadas(tipo, user_id, fecha, loteria_id=loteria_id)
        jugadas = []
        for r in rows:
            jugada_dict = dict(r)
            numeros_raw = jugada_dict.get("numeros")
            if isinstance(numeros_raw, list):
                jugada_dict["numeros"] = [int(n) for n in numeros_raw]
            else:
                jugada_dict["numeros"] = [int(numeros_raw)] if numeros_raw else []
            jugadas.append(jugada_dict)
        return jugadas

    async def borrar_jugada(self, tipo: str, jugada_id: int, user_id: int, loteria_id: Optional[int] = None) -> bool:
        return await self.jugada_repo.delete_jugada(tipo, jugada_id, user_id, loteria_id=loteria_id)

    async def actualizar_jugada(self, tipo: str, jugada_id: int, user_id: int, numeros: List[int], loteria_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
        return await self.jugada_repo.update_jugada(tipo, jugada_id, user_id, numeros, loteria_id=loteria_id)

    async def obtener_loterias_con_jugadas(self, user_id: int) -> List[str]:
        return await self.jugada_repo.list_active_lotteries(user_id)

    async def obtener_loterias_con_conteo(self, user_id: int) -> Dict[str, int]:
        return await self.jugada_repo.list_active_lotteries_counts(user_id)

    async def obtener_loterias_info(self, user_id: int) -> Dict[str, Dict[str, Any]]:
        return await self.jugada_repo.list_active_lotteries_info(user_id)

    def obtener_historico(self, route: str, limit: int) -> Dict[str, Any]:
        rows = self.jugada_repo.get_predicciones_historico(route, limit)
        data = [{"fecha": _format_fecha(r[0]), "numeros": _normalize_numeros(r[1])} for r in rows]
        return {"items": data}

    def obtener_predicciones_historico_generico(self, route: str, limit: int = 50) -> Dict[str, Any]:
        rows = self.jugada_repo.get_predicciones_historico_completas(route, limit)
        data = [
            {
                "fecha": _format_fecha(r[0]),
                "numeros": _normalize_numeros(r[1]),
                "balotaroja": _normalize_numeros(r[2]) if len(r) > 2 else [],
            }
            for r in rows
        ]
        return {"predicciones": data}

    def obtener_prediccion_generico(self, route: str, fecha: Optional[str] = None) -> Dict[str, Any]:
        row = self.jugada_repo.get_prediccion_generico(route, fecha)
        if not row:
            return {"error": f"No hay predicciones registradas para {route}"}
        fecha_res = row[0]
        numeros = _normalize_numeros(row[1])
        balotaroja = _normalize_numeros(row[2]) if len(row) > 2 else []
        jackpot = self.jugada_repo.get_jackpot_reciente(route)
        res = {"fecha": _format_fecha(fecha_res), "numeros": numeros, "balotaroja": balotaroja}
        if jackpot:
            res["jackpot"] = jackpot
        return res

    def _format_resultados(self, route: str, rows) -> Dict[str, Any]:
        if not rows:
            return {"error": f"No hay resultados registrados para {route}"}

        jackpot_reciente = self.jugada_repo.get_jackpot_reciente(route)
        resultados = []
        for index, row in enumerate(rows):
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            especiales = _normalize_numeros(row[2]) if len(row) > 2 else []
            sorteo = row[3] if len(row) > 3 else None
            jackpot = row[4] if len(row) > 4 else None
            if not jackpot and index == 0:
                jackpot = jackpot_reciente

            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros + especiales,
                "balotas_blancas": numeros,
                "balotas_rojas": especiales,
                "sorteo": sorteo or route,
            }
            if especiales:
                item["balotaroja"] = especiales[0] if len(especiales) == 1 else especiales
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}

    def obtener_ultimos5_generico(self, route: str, sorteo: Optional[str] = None) -> Dict[str, Any]:
        return self._format_resultados(
            route,
            self.jugada_repo.get_ultimos_resultados_generico(route, sorteo=sorteo),
        )

    def obtener_ultimos50_generico(self, route: str, sorteo: Optional[str] = None) -> Dict[str, Any]:
        return self._format_resultados(
            route,
            self.jugada_repo.get_ultimos50_resultados_generico(route, sorteo=sorteo),
        )

    def obtener_historico_completo_generico(self, route: str, sorteo: Optional[str] = None) -> Dict[str, Any]:
        return self._format_resultados(
            route,
            self.jugada_repo.get_historico_completo_generico(route, sorteo=sorteo),
        )
