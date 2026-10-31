# app/schemas/health_schema.py

from pydantic import BaseModel, model_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date
from app.models.health_model import AnimoEnum, IntensidadEnum


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
    fecha_hora:   datetime
    notas:        Optional[str] = None


class CitaMedicaResponse(BaseModel):
    id:           UUID
    paciente_id:  UUID
    especialidad: str
    medico:       Optional[str]
    lugar:        Optional[str]
    fecha_hora:   datetime
    notas:        Optional[str]
    activo:       bool
    created_at:   datetime

    class Config:
        from_attributes = True


class CitaActivaItem(BaseModel):
    cita_id:      UUID
    paciente_id:  UUID
    especialidad: str
    medico:       Optional[str]
    lugar:        Optional[str]
    fecha_hora:   datetime

