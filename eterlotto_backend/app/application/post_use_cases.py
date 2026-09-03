from typing import List, Dict, Any, Optional
from fastapi import HTTPException
from app.domain.ports import PostRepositoryPort
from app.core.moderation import moderate_content, check_rate_limit

REASON_MESSAGES = {
    "insulto": "Tu comentario contiene lenguaje ofensivo o inapropiado y no puede ser publicado.",
    "spam": "Tu comentario fue detectado como spam o contiene enlaces no permitidos.",
    "amenaza": "Tu comentario contiene lenguaje amenazante o violento.",
    "contenido_inapropiado": "Tu comentario contiene contenido no permitido según las normas de la comunidad.",
}

class PostUseCases:
    def __init__(self, post_repo: PostRepositoryPort):
        self.post_repo = post_repo

    async def crear_post(self, title: str, content: str, user_id: int) -> Dict[str, Any]:
        # 1. Rate limiting (cooldown)
        check_rate_limit(user_id)

        # 2. Moderación de título
        is_clean_title, reason_title = moderate_content(title)
        if not is_clean_title:
            detail_msg = REASON_MESSAGES.get(reason_title, "El título contiene términos no permitidos.")
            raise HTTPException(status_code=400, detail=f"Título no permitido: {detail_msg}")

        # 3. Moderación de contenido
        is_clean_content, reason_content = moderate_content(content)
        if not is_clean_content:
            detail_msg = REASON_MESSAGES.get(reason_content, "El contenido contiene términos no permitidos.")
            raise HTTPException(status_code=400, detail=f"Contenido no permitido: {detail_msg}")

        return await self.post_repo.create_post(title.strip(), content.strip(), user_id)

    async def listar_posts(self, skip: int = 0, limit: int = 100) -> List[Dict[str, Any]]:
        return await self.post_repo.list_posts(skip, limit)

    async def editar_post(self, post_id: int, title: str, content: str, user_id: int) -> Dict[str, Any]:
        # 1. Moderación de título
        is_clean_title, reason_title = moderate_content(title)
        if not is_clean_title:
            detail_msg = REASON_MESSAGES.get(reason_title, "El título contiene términos no permitidos.")
            raise HTTPException(status_code=400, detail=f"Título no permitido: {detail_msg}")

        # 2. Moderación de contenido
        is_clean_content, reason_content = moderate_content(content)
        if not is_clean_content:
            detail_msg = REASON_MESSAGES.get(reason_content, "El contenido contiene términos no permitidos.")
            raise HTTPException(status_code=400, detail=f"Contenido no permitido: {detail_msg}")

        record = await self.post_repo.update_post(post_id, title.strip(), content.strip(), user_id)
        if not record:
            raise ValueError("Post no encontrado o no autorizado")
        return record

    async def eliminar_post(self, post_id: int, user_id: int) -> Dict[str, Any]:
        success = await self.post_repo.delete_post(post_id, user_id)
        if not success:
            raise ValueError("Post no encontrado o no autorizado")
        return {"message": "Post eliminado correctamente"}

    async def crear_comentario(self, post_id: int, user_id: int, content: str, parent_id: Optional[int] = None) -> Dict[str, Any]:
        # 1. Rate limiting (cooldown de 5 segundos)
        check_rate_limit(user_id)

        # 2. Moderación de contenido
        is_clean, reason = moderate_content(content)
        if not is_clean:
            # Guardado para auditoría en base de datos con status='rejected'
            await self.post_repo.create_comment(
                post_id=post_id,
                user_id=user_id,
                content=content,
                parent_id=parent_id,
                status="rejected",
                moderation_reason=reason
            )
            detail_msg = REASON_MESSAGES.get(reason, "Tu comentario no cumple con las normas de la comunidad.")
            raise HTTPException(status_code=400, detail=detail_msg)

        # 3. Guardado activo
        return await self.post_repo.create_comment(
            post_id=post_id,
            user_id=user_id,
            content=content,
            parent_id=parent_id,
            status="active",
            moderation_reason=None
        )

    async def editar_comentario(self, comment_id: int, user_id: int, content: str) -> Dict[str, Any]:
        # 1. Moderación del nuevo contenido
        is_clean, reason = moderate_content(content)
        if not is_clean:
            await self.post_repo.update_comment(
                comment_id=comment_id,
                user_id=user_id,
                content=content,
                status="rejected",
                moderation_reason=reason
            )
            detail_msg = REASON_MESSAGES.get(reason, "La edición fue rechazada por contener términos no permitidos.")
            raise HTTPException(status_code=400, detail=detail_msg)

        record = await self.post_repo.update_comment(
            comment_id=comment_id,
            user_id=user_id,
            content=content,
            status="active",
            moderation_reason=None
        )
        if not record:
            raise ValueError("Comentario no encontrado o no autorizado")
        return record

    async def eliminar_comentario(self, comment_id: int, user_id: int) -> Dict[str, Any]:
        success = await self.post_repo.delete_comment(comment_id, user_id)
        if not success:
            raise ValueError("Comentario no encontrado o no autorizado")
        return {"message": "Comentario eliminado correctamente"}

    async def listar_comentarios(self, post_id: int) -> List[Dict[str, Any]]:
        return await self.post_repo.list_comments_by_post(post_id)
