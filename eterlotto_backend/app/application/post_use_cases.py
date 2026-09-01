from typing import List, Dict, Any, Optional
from app.domain.ports import PostRepositoryPort

class PostUseCases:
    def __init__(self, post_repo: PostRepositoryPort):
        self.post_repo = post_repo

    async def crear_post(self, title: str, content: str, user_id: int) -> Dict[str, Any]:
        return await self.post_repo.create_post(title, content, user_id)

    async def listar_posts(self, skip: int = 0, limit: int = 100) -> List[Dict[str, Any]]:
        return await self.post_repo.list_posts(skip, limit)

    async def editar_post(self, post_id: int, title: str, content: str, user_id: int) -> Dict[str, Any]:
        record = await self.post_repo.update_post(post_id, title, content, user_id)
        if not record:
            raise ValueError("Post no encontrado o no autorizado")
        return record

    async def eliminar_post(self, post_id: int, user_id: int) -> Dict[str, Any]:
        success = await self.post_repo.delete_post(post_id, user_id)
        if not success:
            raise ValueError("Post no encontrado o no autorizado")
        return {"message": "Post eliminado correctamente"}

    async def crear_comentario(self, post_id: int, user_id: int, content: str, parent_id: Optional[int] = None) -> Dict[str, Any]:
        return await self.post_repo.create_comment(post_id, user_id, content, parent_id)

    async def editar_comentario(self, comment_id: int, user_id: int, content: str) -> Dict[str, Any]:
        record = await self.post_repo.update_comment(comment_id, user_id, content)
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
