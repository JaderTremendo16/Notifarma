# app/schemas/health_schema.py

from pydantic import BaseModel, field_serializer, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from zoneinfo import ZoneInfo
from app.models.health_model import AnimoEnum, IntensidadEnum

ZONA_COLOMBIA = ZoneInfo("America/Bogota")


def _fecha_cita_local(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value
    return value.astimezone(ZONA_COLOMBIA).replace(tzinfo=None)


# ─── EstadoAnimo ──────────────────────────────────────────────────────────────

class EstadoAnimoCreate(BaseModel):
    animo: AnimoEnum


class EstadoAnimoResponse(BaseModel):
    id:         UUID
    paciente_id: UUID
    animo:      AnimoEnum
    fecha_hora: datetime
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Historial ────────────────────────────────────────────────────────────────

class HistorialResponse(BaseModel):
    animos:   List[EstadoAnimoResponse]
    sintomas: List[dict] = []


# ─── Recomendacion ────────────────────────────────────────────────────────────

class RecomendacionResponse(BaseModel):
    mensaje: str


# ─── Citas Médicas ────────────────────────────────────────────────────────────

class CitaMedicaCreate(BaseModel):
    especialidad: str
    medico:       Optional[str] = None
    lugar:        Optional[str] = None
    direccion:    Optional[str] = None
    fecha_hora:   datetime
    notas:        Optional[str] = None

    @field_validator("fecha_hora", mode="before")
    @classmethod
    def normalizar_fecha_hora(cls, value):
        if isinstance(value, datetime):
            return _fecha_cita_local(value)
        if isinstance(value, str):
            return _fecha_cita_local(datetime.fromisoformat(value.replace("Z", "+00:00")))
        return value


class CitaMedicaUpdate(BaseModel):
    especialidad: Optional[str] = None
    medico:       Optional[str] = None
    lugar:        Optional[str] = None
    direccion:    Optional[str] = None
    fecha_hora:   Optional[datetime] = None
    notas:        Optional[str] = None

    @field_validator("fecha_hora", mode="before")
    @classmethod
    def normalizar_fecha_hora(cls, value):
        if value is None:
            return value
        if isinstance(value, datetime):
            return _fecha_cita_local(value)
        if isinstance(value, str):
            return _fecha_cita_local(datetime.fromisoformat(value.replace("Z", "+00:00")))
        return value


class CitaMedicaResponse(BaseModel):
    id:           UUID
    paciente_id:  UUID
    especialidad: str
    medico:       Optional[str]
    lugar:        Optional[str]
    direccion:    Optional[str] = None
    fecha_hora:   datetime
    notas:        Optional[str]
    estado:       Optional[str] = "programada"
    activo:       bool
    created_at:   datetime

    @field_serializer("fecha_hora")
    def serializar_fecha_hora(self, value: datetime) -> str:
        fecha_local = value.replace(tzinfo=ZONA_COLOMBIA) if value.tzinfo is None else value.astimezone(ZONA_COLOMBIA)
        return fecha_local.isoformat()

    class Config:
        from_attributes = True


class CitaEstadoUpdate(BaseModel):
    estado: str  # "asistida", "no_asistida", "sin_confirmar", "programada"

    @field_validator("estado")
    @classmethod
    def validar_estado(cls, value: str) -> str:
        estado = value.lower()
        if estado not in {"asistida", "no_asistida", "sin_confirmar", "programada"}:
            raise ValueError("Estado de cita no válido")
        return estado


class CitaActivaItem(BaseModel):
    cita_id:      UUID
    paciente_id:  UUID
    especialidad: str
    medico:       Optional[str]
    lugar:        Optional[str]
    direccion:    Optional[str] = None
    fecha_hora:   datetime
