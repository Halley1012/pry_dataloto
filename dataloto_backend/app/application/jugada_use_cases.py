from datetime import datetime, date, timedelta, timezone
from typing import List, Dict, Any, Optional

from sqlalchemy import null
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

    async def guardar_jugada(self, tipo: str, user_id: int, numeros: List[int], fecha_sorteo: Optional[str] = None) -> Dict[str, Any]:
        colombia_tz = timezone(timedelta(hours=-5))
        hoy = datetime.now(colombia_tz)
        fecha_guardado = hoy

        sorteo_date: Optional[date] = None
        if fecha_sorteo and isinstance(fecha_sorteo, str) and fecha_sorteo.strip():
            try:
                clean_str = fecha_sorteo.replace('"', '').replace("'", "").strip().split("T")[0]
                sorteo_date = datetime.strptime(clean_str, "%Y-%m-%d").date()
            except Exception:
                sorteo_date = hoy.date()
        else:
            sorteo_date = hoy.date()

        # La jugada expira 7 días después del sorteo
        expira = datetime(
            sorteo_date.year, sorteo_date.month, sorteo_date.day,
            23, 59, 59, tzinfo=colombia_tz
        ) + timedelta(days=7)

        numeros_clean = [int(n) for n in numeros]
        record = await self.jugada_repo.create_jugada(tipo, user_id, numeros_clean, sorteo_date, fecha_guardado, expira)
        return record

    async def listar_jugadas(self, tipo: str, user_id: int, fecha: Optional[str] = None) -> List[Dict[str, Any]]:
        rows = await self.jugada_repo.list_jugadas(tipo, user_id, fecha)
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

    async def borrar_jugada(self, tipo: str, jugada_id: int, user_id: int) -> bool:
        return await self.jugada_repo.delete_jugada(tipo, jugada_id, user_id)

    async def obtener_loterias_con_jugadas(self, user_id: int) -> List[str]:
        return await self.jugada_repo.list_active_lotteries(user_id)

    async def obtener_loterias_con_conteo(self, user_id: int) -> Dict[str, int]:
        return await self.jugada_repo.list_active_lotteries_counts(user_id)

    async def obtener_loterias_info(self, user_id: int) -> Dict[str, Dict[str, Any]]:
        return await self.jugada_repo.list_active_lotteries_info(user_id)

    def obtener_prediccion_colorloto(self, tipo: str) -> Dict[str, Any]:
        return null
    
    def obtener_prediccion_bloto(self, fecha: Optional[str] = None) -> Dict[str, Any]:
        row = self.jugada_repo.get_prediccion_reciente_bloto(fecha)
        if not row:
            return {"error": "No hay predicciones registradas"}
        fecha_res, numeros, balotaroja = row[0], _normalize_numeros(row[1]), _normalize_numeros(row[2])
        jackpot = self.jugada_repo.get_jackpot_reciente("baloto")
        res = {"fecha": _format_fecha(fecha_res), "numeros": numeros, "balotaroja": balotaroja}
        if jackpot:
            res["jackpot"] = jackpot
        return res
    
    def obtener_prediccion_mloto(self, fecha: Optional[str] = None) -> Dict[str, Any]:
        row = self.jugada_repo.get_prediccion_reciente_mloto(fecha)
        if not row:
            return {"error": "No hay predicciones registradas"}
            
        fecha_res, numeros = row[0], _normalize_numeros(row[1])
        jackpot = self.jugada_repo.get_jackpot_reciente("miloto")
        res = {"fecha": _format_fecha(fecha_res), "numeros": numeros}
        if jackpot:
            res["jackpot"] = jackpot
        return res
       

    def obtener_ultimos5_mloto(self) -> Dict[str, Any]:
        rows = self.jugada_repo.get_ultimos_resultados_mloto()
        if not rows:
            return {"error": "No hay resultados registrados"}
        
        jackpot_reciente = self.jugada_repo.get_jackpot_reciente("miloto")
        resultados = []
        for i, row in enumerate(rows):
            fecha, numeros = row[0], row[1]
            jackpot = row[2] if len(row) > 2 else None
            if not jackpot and i == 0:
                jackpot = jackpot_reciente
            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros
            }
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}
    

    def obtener_ultimos5_bloto(self, sorteo: Optional[str] = None) -> Dict[str, Any]:
        rows = self.jugada_repo.get_ultimos_resultados_bloto(sorteo=sorteo)
        if not rows:
            return {"error": "No hay resultados registrados"}
        
        jackpot_baloto = self.jugada_repo.get_jackpot_reciente("baloto")
        jackpot_revancha = self.jugada_repo.get_jackpot_reciente("revancha")
        resultados = []
        for i, row in enumerate(rows):
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            balotaroja = _normalize_numeros(row[2]) if len(row) > 2 else []
            sorteo_nombre = row[3] if len(row) > 3 else "Baloto"
            jackpot = row[4] if len(row) > 4 else None
            if not jackpot and i < 2:
                if "revancha" in sorteo_nombre.lower():
                    jackpot = jackpot_revancha
                else:
                    jackpot = jackpot_baloto
            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros + balotaroja,
                "sorteo": sorteo_nombre
            }
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}


    def obtener_historico_completo_bloto(self, sorteo: Optional[str] = None) -> Dict[str, Any]:
        rows = self.jugada_repo.get_historico_completo_bloto(sorteo=sorteo)
        if not rows:
            return {"error": "No hay resultados registrados"}
        resultados = []
        for row in rows:
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            balotaroja = _normalize_numeros(row[2]) if len(row) > 2 else []
            sorteo_nombre = row[3] if len(row) > 3 else "Baloto"
            jackpot = row[4] if len(row) > 4 else None
            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros + balotaroja,
                "sorteo": sorteo_nombre
            }
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}

    def obtener_historico_completo_mloto(self) -> Dict[str, Any]:
        rows = self.jugada_repo.get_historico_completo_mloto()
        if not rows:
            return {"error": "No hay resultados registrados"}
        resultados = []
        for row in rows:
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            jackpot = row[2] if len(row) > 2 else None
            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros
            }
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}

    def obtener_historico(self, tipo: str, limit: int) -> Dict[str, Any]:
        rows = self.jugada_repo.get_predicciones_historico(tipo, limit)
        data = [{"fecha": _format_fecha(r[0]), "numeros": _normalize_numeros(r[1])} for r in rows]
        return {"items": data}

    def obtener_prediccion_generico(self, loteria_nombre: str, fecha: Optional[str] = None) -> Dict[str, Any]:
        tabla = f"predicciones_{loteria_nombre}"
        row = self.jugada_repo.get_prediccion_generico(tabla, fecha)
        if not row:
            return {"error": f"No hay predicciones registradas para {loteria_nombre}"}
        fecha_res, numeros, balotaroja = row[0], _normalize_numeros(row[1]), _normalize_numeros(row[2])
        jackpot = self.jugada_repo.get_jackpot_reciente(loteria_nombre)
        res = {"fecha": _format_fecha(fecha_res), "numeros": numeros, "balotaroja": balotaroja}
        if jackpot:
            res["jackpot"] = jackpot
        return res

    def obtener_ultimos5_generico(self, loteria_nombre: str, display_name: str) -> Dict[str, Any]:
        tabla = f"resultados_{loteria_nombre}"
        rows = self.jugada_repo.get_ultimos_resultados_generico(tabla, display_name)
        if not rows:
            return {"error": f"No hay resultados registrados para {loteria_nombre}"}
        
        jackpot_reciente = self.jugada_repo.get_jackpot_reciente(loteria_nombre)
        resultados = []
        for i, row in enumerate(rows):
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            balotaroja = _normalize_numeros(row[2]) if len(row) > 2 else []
            jackpot = row[4] if len(row) > 4 else None
            if not jackpot and i == 0:
                jackpot = jackpot_reciente
            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros + balotaroja,
                "sorteo": display_name
            }
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}

    def obtener_historico_completo_generico(self, loteria_nombre: str, display_name: str) -> Dict[str, Any]:
        tabla = f"resultados_{loteria_nombre}"
        rows = self.jugada_repo.get_historico_completo_generico(tabla, display_name)
        if not rows:
            return {"error": f"No hay resultados registrados para {loteria_nombre}"}
        resultados = []
        for row in rows:
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            balotaroja = _normalize_numeros(row[2]) if len(row) > 2 else []
            jackpot = row[4] if len(row) > 4 else None
            item = {
                "fecha": _format_fecha(fecha),
                "numeros": numeros + balotaroja,
                "sorteo": display_name
            }
            if jackpot:
                item["jackpot"] = jackpot
            resultados.append(item)
        return {"resultados": resultados}

