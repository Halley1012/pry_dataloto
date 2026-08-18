from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime
from fastapi import Query

class User(BaseModel):
    email: str
    password: str

class RegisterUser(BaseModel):
    name: str
    email: EmailStr
    password: str
    pais_id: int
    departamento_id: int

class UpdateUser(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    pais_id: Optional[int] = None
    departamento_id: Optional[int] = None
    fcm_token: Optional[str] = None

class JugadaCreate(BaseModel):
    numeros: List[int]
    user_id: str
    loteria_route: Optional[str] = None
    fecha_sorteo: Optional[str] = None
    fecha: Optional[str] = None

class JugadaOut(BaseModel):
    id: int
    user_id: int
    loteria_id: Optional[int] = None
    loteria_route: Optional[str] = None
    numeros: List[int]
    fecha_sorteo: Optional[str] = None
    fecha_guardado: Optional[datetime] = None
    expira: Optional[datetime] = None

class TransactionRequest(BaseModel):
    amount: float
    currency: str
    email: str
    name: str
    reference: str
    description: str = "Pago desde app"

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class CommentCreate(BaseModel):
    content: str
    parent_id: Optional[int] = None

class CommentResponse(BaseModel):
    id: int
    post_id: int
    user_id: int
    user_name: str
    content: str
    created_at: datetime
    parent_id: Optional[int] = None

class PostCreate(BaseModel):
    title: str
    content: str

class PostResponse(BaseModel):
    id: int
    title: str
    content: str
    user_id: int
    user_name: str
    created_at: datetime
    comments_count: int = 0

class LoteriaOut(BaseModel):
    id: int
    nombre: str
    tipo: Optional[str] = None
    pais_id: int
    proximo_sorteo: Optional[str] = None
    route: Optional[str] = None
    max_seleccion: Optional[int] = 5
    max_balotas_blancas: Optional[int] = 45
    max_balotas_rojas: Optional[int] = 0
    superbalota_nombre: Optional[str] = None
    has_revancha: Optional[bool] = False

class PublicidadQuery:
    def __init__(
        self,
        pais_id: Optional[int] = Query(None, description="Filtrar por país ID"),
        departamento_id: Optional[int] = Query(None, description="Filtrar por departamento ID"),
        ciudad_id: Optional[int] = Query(None, description="Filtrar por ciudad ID"),
        categoria_id: Optional[int] = Query(None, description="Filtrar por categoría ID"),
        titulo: Optional[str] = Query(None, description="Filtrar por título (coincidencia parcial, case-insensitive)"),
        limit: int = Query(20, ge=1, le=100, description="Número máximo de resultados por página"),
        offset: int = Query(0, ge=0, description="Offset para paginación")
    ):
        self.pais_id = pais_id
        self.departamento_id = departamento_id
        self.ciudad_id = ciudad_id
        self.categoria_id = categoria_id
        self.titulo = titulo
        self.limit = limit
        self.offset = offset

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class FCMTokenUpdate(BaseModel):
    user_id: int
    fcm_token: str

class SocialLoginRequest(BaseModel):
    provider: str
    token: str
