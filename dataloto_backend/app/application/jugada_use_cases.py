from datetime import datetime, timedelta, timezone
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

    async def guardar_jugada(self, tipo: str, user_id: int, numeros: List[int]) -> Dict[str, Any]:
        colombia_tz = timezone(timedelta(hours=-5))
        hoy = datetime.now(colombia_tz)
        expira = hoy + timedelta(days=1)

        numeros_clean = [int(n) for n in numeros]
        record = await self.jugada_repo.create_jugada(tipo, user_id, numeros_clean, hoy, expira)
        return record

    async def listar_jugadas(self, tipo: str, user_id: int) -> List[Dict[str, Any]]:
        rows = await self.jugada_repo.list_jugadas(tipo, user_id)
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

    def obtener_prediccion_colorloto(self, tipo: str) -> Dict[str, Any]:
        return null
    
    def obtener_prediccion_bloto(self) -> Dict[str, Any]:
        row = self.jugada_repo.get_prediccion_reciente_bloto()
        if not row:
            return {"error": "No hay predicciones registradas"}
        fecha, numeros, balotaroja = row[0], _normalize_numeros(row[1]), _normalize_numeros(row[2])
        return {"fecha": _format_fecha(fecha), "numeros": numeros, "balotaroja": balotaroja}
    
    def obtener_prediccion_mloto(self) -> Dict[str, Any]:
        row = self.jugada_repo.get_prediccion_reciente_mloto()
        if not row:
            return {"error": "No hay predicciones registradas"}
            
        fecha, numeros = row[0], _normalize_numeros(row[1])
        return {"fecha": _format_fecha(fecha), "numeros": numeros}
       

    def obtener_ultimos5_mloto(self) -> Dict[str, Any]:
        rows = self.jugada_repo.get_ultimos_resultados_mloto()
        if not rows:
            return {"error": "No hay resultados registrados"}
        
        resultados = []
        for row in rows:
            fecha, numeros = row[0], row[1]
            resultados.append({
                "fecha": _format_fecha(fecha),
                "numeros": numeros
            })
        return {"resultados": resultados}
    

    def obtener_ultimos5_bloto(self, sorteo: Optional[str] = None) -> Dict[str, Any]:
        rows = self.jugada_repo.get_ultimos_resultados_bloto(sorteo=sorteo)
        if not rows:
            return {"error": "No hay resultados registrados"}
        
        resultados = []
        for row in rows:
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            balotaroja = _normalize_numeros(row[2]) if len(row) > 2 else []
            sorteo_nombre = row[3] if len(row) > 3 else "Baloto"
            resultados.append({
                "fecha": _format_fecha(fecha),
                "numeros": numeros + balotaroja,
                "sorteo": sorteo_nombre
            })
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
            resultados.append({
                "fecha": _format_fecha(fecha),
                "numeros": numeros + balotaroja,
                "sorteo": sorteo_nombre
            })
        return {"resultados": resultados}

    def obtener_historico_completo_mloto(self) -> Dict[str, Any]:
        rows = self.jugada_repo.get_historico_completo_mloto()
        if not rows:
            return {"error": "No hay resultados registrados"}
        resultados = []
        for row in rows:
            fecha = row[0]
            numeros = _normalize_numeros(row[1])
            resultados.append({
                "fecha": _format_fecha(fecha),
                "numeros": numeros
            })
        return {"resultados": resultados}

    def obtener_historico(self, tipo: str, limit: int) -> Dict[str, Any]:
        rows = self.jugada_repo.get_predicciones_historico(tipo, limit)
        data = [{"fecha": _format_fecha(r[0]), "numeros": _normalize_numeros(r[1])} for r in rows]
        return {"items": data}
