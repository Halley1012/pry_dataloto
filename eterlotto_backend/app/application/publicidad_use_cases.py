from typing import List, Dict, Any, Optional, Tuple
from app.domain.ports import PublicidadRepositoryPort

class PublicidadUseCases:
    def __init__(self, publicidad_repo: PublicidadRepositoryPort):
        self.publicidad_repo = publicidad_repo

    async def listar_publicidad(self, filters: Dict[str, Any], limit: int, offset: int) -> Dict[str, Any]:
        # Para compatibilidad, el repositorio devuelve la lista y el conteo
        # Y este caso de uso ensambla la respuesta esperada
        data, total = await self.publicidad_repo.list_publicidad_dinamica(filters, limit, offset)
        return {
            "success": True,
            "data": data,
            "pagination": {
                "total": total,
                "limit": limit,
                "offset": offset,
                "has_more": (offset + limit) < total
            },
            "message": "✅ Publicidades obtenidas correctamente" if data else "⚠️ No se encontraron anuncios"
        }

    async def crear_publicidad(self, user_id: int, request_data: Dict[str, Any]) -> Dict[str, Any]:
        # Aplicamos formateos de URL iguales a la implementación original
        facebook_url = request_data.get("facebook_url")
        instagram_url = request_data.get("instagram_url")
        whatsapp_url = request_data.get("whatsapp_url")
        tiktok_url = request_data.get("tiktok_url")
        pagina_url = request_data.get("pagina_url")

        formatted_data = request_data.copy()
        formatted_data["facebook_url"] = f"https://www.facebook.com/{facebook_url}" if facebook_url else None
        formatted_data["instagram_url"] = f"https://www.instagram.com/{instagram_url}" if instagram_url else None
        formatted_data["whatsapp_url"] = f"https://wa.me/{whatsapp_url}" if whatsapp_url else None
        formatted_data["tiktok_url"] = f"https://www.tiktok.com/{tiktok_url}" if tiktok_url else None
        formatted_data["pagina_url"] = f"https://{pagina_url}" if pagina_url else None

        return await self.publicidad_repo.create_publicidad_full(user_id, formatted_data)

    async def eliminar_publicidad(self, publicidad_id: int, user_id: int) -> Dict[str, Any]:
        success = await self.publicidad_repo.delete_publicidad_by_user(publicidad_id, user_id)
        if not success:
            raise ValueError("Anuncio no encontrado o no autorizado")
        return {"success": True}

    async def aprobar_publicidad(self, publicidad_id: int) -> Dict[str, Any]:
        success = await self.publicidad_repo.aprobar_publicidad(publicidad_id)
        if not success:
            raise ValueError("Anuncio no encontrado")
        return {"success": True, "message": "Anuncio aprobado ✅"}

    async def listar_mis_publicidades(self, user_id: int) -> List[Dict[str, Any]]:
        return await self.publicidad_repo.list_my_publicidades(user_id)

    async def actualizar_publicidad(self, publicidad_id: int, user_id: int, request_data: Dict[str, Any]) -> Dict[str, Any]:
        facebook_url = request_data.get("facebook_url")
        instagram_url = request_data.get("instagram_url")
        whatsapp_url = request_data.get("whatsapp_url")
        tiktok_url = request_data.get("tiktok_url")
        pagina_url = request_data.get("pagina_url")

        formatted_data = request_data.copy()
        formatted_data["facebook_url"] = f"https://www.facebook.com/{facebook_url}" if facebook_url else None
        formatted_data["instagram_url"] = f"https://www.instagram.com/{instagram_url}" if instagram_url else None
        formatted_data["whatsapp_url"] = f"https://wa.me/{whatsapp_url}" if whatsapp_url else None
        formatted_data["tiktok_url"] = f"https://www.tiktok.com/{tiktok_url}" if tiktok_url else None
        formatted_data["pagina_url"] = f"https://{pagina_url}" if pagina_url else None

        success = await self.publicidad_repo.update_publicidad_full(publicidad_id, user_id, formatted_data)
        if not success:
            raise ValueError("Anuncio no encontrado")
        return {"success": True, "message": "Anuncio actualizado"}

    # Metadata de localización y loterías (métodos síncronos)
    def listar_categorias(self) -> Dict[str, Any]:
        data = self.publicidad_repo.list_categorias()
        return {"success": True, "data": data}

    def listar_paises(self) -> Dict[str, Any]:
        data = self.publicidad_repo.list_paises()
        return {"success": True, "data": data}

    def listar_departamentos_por_pais(self, pais_id: int) -> Dict[str, Any]:
        data = self.publicidad_repo.list_departamentos(pais_id)
        return {"success": True, "data": data}

    def listar_departamentos(self) -> Dict[str, Any]:
        data = self.publicidad_repo.list_departamentos_all()
        return {"success": True, "data": data}

    def listar_ciudades(self, departamento_id: Optional[int] = None) -> Dict[str, Any]:
        if departamento_id:
            data = self.publicidad_repo.list_ciudades_by_departamento(departamento_id)
        else:
            data = self.publicidad_repo.list_ciudades()
            # el repo ya se encarga de inyectar "Todas las ciudades" id:0 si no hay filtro.
        return {"success": True, "data": data}

    def listar_loterias(self, pais_id: Optional[int] = None) -> List[Dict[str, Any]]:
        return self.publicidad_repo.list_loterias_by_pais(pais_id)
