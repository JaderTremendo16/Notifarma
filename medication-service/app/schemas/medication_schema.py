# app/schemas/medication_schema.py

from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date, time
from app.models.medication_model import EstadoToma


# ─── Medicamento ──────────────────────────────────────────────────────────────

class MedicamentoCreate(BaseModel):
    nombre:              str
    dosis:               Optional[str]  = None
    frecuencia_horas:    int
    hora_inicio:         time
    fecha_inicio:        Optional[date] = None
    fecha_fin:           Optional[date] = None
    stock_actual:        Optional[int]  = 0
    stock_minimo_alerta: Optional[int]  = 5


class MedicamentoUpdate(BaseModel):
    nombre:              Optional[str]  = None
    dosis:               Optional[str]  = None
    frecuencia_horas:    Optional[int]  = None
    hora_inicio:         Optional[time] = None
    fecha_inicio:        Optional[date] = None
    fecha_fin:           Optional[date] = None
    stock_actual:        Optional[int]  = None
    stock_minimo_alerta: Optional[int]  = None


class StockUpdate(BaseModel):
    stock_actual:        int
    stock_minimo_alerta: Optional[int] = None


class MedicamentoResponse(BaseModel):
    id:                  UUID
    paciente_id:         UUID
    nombre:              str
    dosis:               Optional[str]
    frecuencia_horas:    int
    hora_inicio:         time
    fecha_inicio:        Optional[date]
    fecha_fin:           Optional[date]
    stock_actual:        int
    stock_minimo_alerta: int
    activo:              bool
    created_at:          datetime
    updated_at:          datetime

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


# ─── Resumen Cuidador ─────────────────────────────────────────────────────────

class ResumenCuidadorResponse(BaseModel):
    paciente_id:              UUID
    total_medicamentos_activos: int
    medicamentos:             List[MedicamentoResponse]
    alertas_stock:            List[MedicamentoResponse]
    tomas_hoy:                List[TomaResponse]
    total_tomas_hoy:          int
    total_tomadas_hoy:        int
    proximo_medicamento:      Optional[dict] = None


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


# ─── Auditoría y Predicción ───────────────────────────────────────────────────

class RegistroAuditoriaResponse(BaseModel):
    id:          UUID
    paciente_id: UUID
    usuario_id:  UUID
    accion:      str
    detalle:     Optional[str] = None
    fecha_hora:  datetime

    class Config:
        from_attributes = True


class PrediccionAgotamientoItem(BaseModel):
    medicamento_id:   UUID
    paciente_id:      UUID
    nombre:           str
    stock_actual:     int
    frecuencia_horas: int
    tomas_por_dia:    float
    dias_restantes:   float
    fecha_estimada:   str  # "YYYY-MM-DD"

