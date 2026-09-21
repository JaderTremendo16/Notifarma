# app/schemas/user_schema.py

from pydantic import BaseModel, EmailStr
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.models.user_model import RolUsuario

# 1. Registro (Lo que entra al crear usuario)
class UserCreate(BaseModel):
    nombres: str
    email: EmailStr
    password: str

    rol: RolUsuario = RolUsuario.paciente
    #opcionales
    edad: Optional[int] = None
    contacto_emergencia_nombre: Optional[str] = None
    contacto_emergencia_telefono: Optional[str] = None
    zona_horaria: Optional[str] = "America/Bogota"


# 2. Login (Lo que entra al iniciar sesión)
class UserLogin(BaseModel):
    email: EmailStr
    password: str


# 3. Respuesta (Lo que devuelve el backend al cliente)
class UserResponse(BaseModel):
    id: UUID
    nombres: str
    email: EmailStr
    rol: RolUsuario
    cuidador_id: Optional[UUID] = None
    zona_horaria: str = "America/Bogota"
    #opcionales
    edad: Optional[int] = None
    contacto_emergencia_nombre: Optional[str] = None
    contacto_emergencia_telefono: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


# 4. Códigos de vinculación
class GenerarCodigoResponse(BaseModel):
    codigo: str
    rol_generador: RolUsuario
    expira_en_minutos: int
    fecha_expiracion: datetime


class VincularCodigoRequest(BaseModel):
    codigo: str