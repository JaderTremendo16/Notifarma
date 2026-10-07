# app/schemas/user_schema.py

from pydantic import BaseModel, EmailStr, field_validator
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

    @field_validator("contacto_emergencia_telefono")
    @classmethod
    def validar_telefono(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            clean = v.strip().replace(" ", "").replace("-", "").replace("+", "")
            if clean:
                if not clean.isdigit():
                    raise ValueError("El teléfono de emergencia solo debe contener números")
                if len(clean) < 7 or len(clean) > 15:
                    raise ValueError("El número telefónico debe tener entre 7 y 15 dígitos")
        return v


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
    cuidador_nombre: Optional[str] = None
    cuidador_email: Optional[str] = None
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