from abc import ABC, abstractmethod
from typing import List, Optional, Tuple, Dict, Any
from datetime import datetime, date
from app.domain.models import User, Jugada, Post, Comment, Publicidad, Transaction

class UserRepositoryPort(ABC):
    @abstractmethod
    async def find_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def find_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def create(self, name: str, email: str, password_hashed: Optional[str], pais_id: Optional[int], departamento_id: Optional[int]) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def update(self, user_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def delete(self, user_id: int) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def save_password_reset_token(self, user_id: int, token: str, expires: datetime) -> None:
        pass

    @abstractmethod
    async def find_password_reset_token(self, token: str) -> Optional[Tuple[int, datetime]]:
        pass

    @abstractmethod
    async def update_password(self, user_id: int, new_password_hashed: str) -> None:
        pass


class JugadaRepositoryPort(ABC):
    @abstractmethod
    async def create_jugada(self, tipo: str, user_id: int, numeros: List[int], fecha_sorteo: Optional[date], fecha_guardado: datetime, expira: datetime) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def list_jugadas(self, tipo: str, user_id: int, fecha: Optional[str] = None) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def delete_jugada(self, tipo: str, jugada_id: int, user_id: int) -> bool:
        pass

    @abstractmethod
    async def list_active_lotteries(self, user_id: int) -> List[str]:
        pass

    @abstractmethod
    def get_prediccion_reciente_mloto(self, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int]]]:
        pass

    @abstractmethod
    def get_prediccion_reciente_bloto(self, fecha: Optional[str] = None) -> Optional[Tuple[datetime, List[int], List[int]]]:
        pass

    @abstractmethod
    def get_jackpot_reciente(self, loteria: str) -> Optional[str]:
        pass

    @abstractmethod
    def get_ultimos_resultados_mloto(self) -> List[Tuple[datetime, List[int], Optional[str]]]:
        pass

    @abstractmethod
    def get_ultimos_resultados_bloto(self, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        pass

    @abstractmethod
    def get_historico_completo_bloto(self, sorteo: Optional[str] = None) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        pass

    @abstractmethod
    def get_historico_completo_mloto(self) -> List[Tuple[datetime, List[int], Optional[str]]]:
        pass

    @abstractmethod
    def get_predicciones_historico(self, tipo: str, limit: int) -> List[Tuple[datetime, List[int]]]:
        pass

    @abstractmethod
    def get_prediccion_generico(self, tabla: str) -> Optional[Tuple[datetime, List[int], List[int]]]:
        pass

    @abstractmethod
    def get_ultimos_resultados_generico(self, tabla: str, sorteo_nombre: str) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        pass

    @abstractmethod
    def get_historico_completo_generico(self, tabla: str, sorteo_nombre: str) -> List[Tuple[datetime, List[int], List[int], str, Optional[str]]]:
        pass



class PostRepositoryPort(ABC):
    @abstractmethod
    async def create_post(self, title: str, content: str, user_id: int) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def list_posts(self, skip: int, limit: int) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def update_post(self, post_id: int, title: str, content: str, user_id: int) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def delete_post(self, post_id: int, user_id: int) -> bool:
        pass

    @abstractmethod
    async def create_comment(self, post_id: int, user_id: int, content: str) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def update_comment(self, comment_id: int, user_id: int, content: str) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def delete_comment(self, comment_id: int, user_id: int) -> bool:
        pass

    @abstractmethod
    async def list_comments_by_post(self, post_id: int) -> List[Dict[str, Any]]:
        pass


class PublicidadRepositoryPort(ABC):
    @abstractmethod
    async def create_publicidad(self, user_id: int, imagen_url: str, link: str, categoria_id: int, ciudad_id: int, departamento_id: int) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def list_publicidad_aprobada(self, categoria_id: Optional[int], departamento_id: Optional[int], ciudad_id: Optional[int]) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def list_all_publicidades(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def list_my_publicidades(self, user_id: int) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def update_publicidad(self, publicidad_id: int, user_id: int, imagen_url: Optional[str], link: Optional[str], categoria_id: Optional[int], ciudad_id: Optional[int], departamento_id: Optional[int]) -> Optional[Dict[str, Any]]:
        pass

    @abstractmethod
    async def delete_publicidad(self, publicidad_id: int) -> bool:
        pass

    @abstractmethod
    async def aprobar_publicidad(self, publicidad_id: int) -> bool:
        pass

    @abstractmethod
    def list_categorias(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def list_paises(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def list_departamentos(self, pais_id: int) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def list_departamentos_all(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def list_ciudades(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def list_loterias(self) -> List[Dict[str, Any]]:
        pass


class TransactionRepositoryPort(ABC):
    @abstractmethod
    def create_transaction(self, referencia: str, nombre_cliente: str, email_cliente: str, monto: float, moneda: str, descripcion: str) -> int:
        pass

    @abstractmethod
    async def update_transaction_confirmation(self, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        pass


class EmailSenderPort(ABC):
    @abstractmethod
    async def send_reset_password_email(self, email: str, reset_link: str) -> bool:
        pass


class NotificationRepositoryPort(ABC):
    @abstractmethod
    async def create_notification(self, loteria_id: Optional[int], fecha_sorteo: Optional[datetime], mensaje: str, tipo: str, user_id: Optional[int] = None) -> Dict[str, Any]:
        pass

    @abstractmethod
    async def list_notifications(self, user_id: Optional[int] = None, limit: int = 20) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    async def mark_as_read(self, notification_id: int) -> bool:
        pass

    @abstractmethod
    async def delete_notification(self, notification_id: int, user_id: Optional[int] = None) -> bool:
        pass
