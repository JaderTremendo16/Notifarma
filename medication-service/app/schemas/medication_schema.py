# app/schemas/medication_schema.py

from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date, time
from app.models.medication_model import EstadoToma


# ─── Medicamento ──────────────────────────────────────────────────────────────

class MedicamentoCreate(BaseModel):
    nombre:           str
    dosis:            Optional[str]  = None
    frecuencia_horas: int
    hora_inicio:      time
    fecha_inicio:     Optional[date] = None
    fecha_fin:        Optional[date] = None


class MedicamentoUpdate(BaseModel):
    nombre:           Optional[str]  = None
    dosis:            Optional[str]  = None
    frecuencia_horas: Optional[int]  = None
    hora_inicio:      Optional[time] = None
    fecha_inicio:     Optional[date] = None
    fecha_fin:        Optional[date] = None


class MedicamentoResponse(BaseModel):
    id:               UUID
    paciente_id:      UUID
    nombre:           str
    dosis:            Optional[str]
    frecuencia_horas: int
    hora_inicio:      time
    fecha_inicio:     Optional[date]
    fecha_fin:        Optional[date]
    activo:           bool
    created_at:       datetime
    updated_at:       datetime

    class Config:
        from_attributes = True


# ─── Toma ─────────────────────────────────────────────────────────────────────

class TomaCreate(BaseModel):
    estado:                EstadoToma
    fecha_hora_programada: Optional[datetime] = None  # si no se envía, se usa datetime.utcnow()


class TomaResponse(BaseModel):
    id:                     UUID
    medicamento_id:         UUID
    paciente_id:            UUID
    fecha_hora_programada:  datetime
    estado:                 EstadoToma
    fecha_hora_confirmacion: Optional[datetime]
    created_at:             datetime

    class Config:
        from_attributes = True


# ─── Respuestas especiales ────────────────────────────────────────────────────

class ProximoMedicamentoResponse(BaseModel):
    medicamento_id: UUID
    nombre:         str
    dosis:          Optional[str]
    proxima_toma:   datetime


class HorarioActivoItem(BaseModel):
    medicamento_id:  UUID
    paciente_id:     UUID
    nombre:          str
    frecuencia_horas: int
    hora_inicio:     str  # se serializa como string "HH:MM:SS" para compatibilidad JSON
