from datetime import datetime
from typing import List, Optional

class User:
    def __init__(self, id: int, name: str, email: str, password_hashed: str, pais_id: Optional[int] = None, departamento_id: Optional[int] = None, fcm_token: Optional[str] = None):
        self.id = id
        self.name = name
        self.email = email
        self.password_hashed = password_hashed
        self.pais_id = pais_id
        self.departamento_id = departamento_id
        self.fcm_token = fcm_token

class Jugada:
    def __init__(self, id: int, user_id: int, numeros: List[int], fecha_guardado: datetime, expira: datetime):
        self.id = id
        self.user_id = user_id
        self.numeros = numeros
        self.fecha_guardado = fecha_guardado
        self.expira = expira

class Post:
    def __init__(self, id: int, title: str, content: str, user_id: int, user_name: Optional[str] = None, created_at: Optional[datetime] = None):
        self.id = id
        self.title = title
        self.content = content
        self.user_id = user_id
        self.user_name = user_name
        self.created_at = created_at or datetime.utcnow()

class Comment:
    def __init__(self, id: int, post_id: int, user_id: int, content: str, user_name: Optional[str] = None, created_at: Optional[datetime] = None):
        self.id = id
        self.post_id = post_id
        self.user_id = user_id
        self.content = content
        self.user_name = user_name
        self.created_at = created_at or datetime.utcnow()

class Publicidad:
    def __init__(self, id: int, user_id: int, imagen_url: str, link: str, aprobado: bool = False, categoria_id: Optional[int] = None, ciudad_id: Optional[int] = None, departament_id: Optional[int] = None, clicks: int = 0, views: int = 0, created_at: Optional[datetime] = None):
        self.id = id
        self.user_id = user_id
        self.imagen_url = imagen_url
        self.link = link
        self.aprobado = aprobado
        self.categoria_id = categoria_id
        self.ciudad_id = ciudad_id
        self.departament_id = departament_id
        self.clicks = clicks
        self.views = views
        self.created_at = created_at or datetime.utcnow()

class Transaction:
    def __init__(self, id: int, referencia: str, nombre_cliente: str, email_cliente: str, monto: float, moneda: str, descripcion: str, estado: str, epayco_transaction_id: Optional[str] = None, metodo_pago: Optional[str] = None, respuesta_json: Optional[dict] = None, created_at: Optional[datetime] = None, updated_at: Optional[datetime] = None):
        self.id = id
        self.referencia = referencia
        self.nombre_cliente = nombre_cliente
        self.email_cliente = email_cliente
        self.monto = monto
        self.moneda = moneda
        self.descripcion = descripcion
        self.estado = estado
        self.epayco_transaction_id = epayco_transaction_id
        self.metodo_pago = metodo_pago
        self.respuesta_json = respuesta_json
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at

class Notification:
    def __init__(self, id: int, user_id: Optional[int], loteria_id: Optional[int], fecha_sorteo: Optional[datetime], mensaje: str, tipo: str, leido: bool = False, created_at: Optional[datetime] = None):
        self.id = id
        self.user_id = user_id
        self.loteria_id = loteria_id
        self.fecha_sorteo = fecha_sorteo
        self.mensaje = mensaje
        self.tipo = tipo
        self.leido = leido
        self.created_at = created_at or datetime.utcnow()
