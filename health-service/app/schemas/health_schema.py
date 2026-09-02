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


# ─── Sintoma (catálogo) ───────────────────────────────────────────────────────

class SintomaResponse(BaseModel):
    id:     UUID
    nombre: str

    class Config:
        from_attributes = True


# ─── RegistroSintoma ──────────────────────────────────────────────────────────

class RegistroSintomaCreate(BaseModel):
    sintoma_id:   Optional[UUID] = None   # id del catálogo
    sintoma_otro: Optional[str]  = None   # texto libre cuando el usuario elige "Otro"
    intensidad:   IntensidadEnum
    observacion:  Optional[str]  = None

    @model_validator(mode="after")
    def validar_al_menos_uno(self) -> "RegistroSintomaCreate":
        if self.sintoma_id is None and (self.sintoma_otro is None or self.sintoma_otro.strip() == ""):
            raise ValueError("Debe proveer sintoma_id o sintoma_otro")
        return self


class RegistroSintomaResponse(BaseModel):
    id:           UUID
    paciente_id:  UUID
    sintoma_id:   Optional[UUID]
    sintoma_otro: Optional[str]
    intensidad:   IntensidadEnum
    observacion:  Optional[str]
    fecha_hora:   datetime
    created_at:   datetime

    class Config:
        from_attributes = True


# ─── Historial ────────────────────────────────────────────────────────────────

class HistorialResponse(BaseModel):
    animos:   List[EstadoAnimoResponse]
    sintomas: List[RegistroSintomaResponse]


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

