# app/schemas/medication_schema.py

from pydantic import BaseModel, field_serializer, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date, time, timezone
from app.models.medication_model import EstadoToma


# ─── Medicamento ──────────────────────────────────────────────────────────────

class MedicamentoCreate(BaseModel):
    nombre:              str
    dosis:               Optional[str]  = None
    indicaciones:        Optional[str]  = None
    frecuencia_horas:    int
    hora_inicio:         time
    fecha_inicio:        Optional[date] = None
    fecha_fin:           Optional[date] = None
    stock_actual:        Optional[int]  = 0
    stock_minimo_alerta: Optional[int]  = 5

    @field_validator("frecuencia_horas")
    @classmethod
    def validar_frecuencia(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("La frecuencia debe ser mayor que cero.")
        return value

    @field_validator("stock_actual", "stock_minimo_alerta")
    @classmethod
    def validar_stock_no_negativo(cls, value: Optional[int]) -> Optional[int]:
        if value is not None and value < 0:
            raise ValueError("El stock no puede ser negativo.")
        return value


class MedicamentoUpdate(BaseModel):
    nombre:              Optional[str]  = None
    dosis:               Optional[str]  = None
    indicaciones:        Optional[str]  = None
    frecuencia_horas:    Optional[int]  = None
    hora_inicio:         Optional[time] = None
    fecha_inicio:        Optional[date] = None
    fecha_fin:           Optional[date] = None
    stock_actual:        Optional[int]  = None
    stock_minimo_alerta: Optional[int]  = None

    @field_validator("frecuencia_horas")
    @classmethod
    def validar_frecuencia(cls, value: Optional[int]) -> Optional[int]:
        if value is not None and value <= 0:
            raise ValueError("La frecuencia debe ser mayor que cero.")
        return value

    @field_validator("stock_actual", "stock_minimo_alerta")
    @classmethod
    def validar_stock_no_negativo(cls, value: Optional[int]) -> Optional[int]:
        if value is not None and value < 0:
            raise ValueError("El stock no puede ser negativo.")
        return value


class StockUpdate(BaseModel):
    stock_actual:        int
    stock_minimo_alerta: Optional[int] = None

    @field_validator("stock_actual", "stock_minimo_alerta")
    @classmethod
    def validar_stock_no_negativo(cls, value: Optional[int]) -> Optional[int]:
        if value is not None and value < 0:
            raise ValueError("El stock no puede ser negativo.")
        return value


class MedicamentoResponse(BaseModel):
    id:                  UUID
    paciente_id:         UUID
    nombre:              str
    dosis:               Optional[str]
    indicaciones:        Optional[str] = None
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
    medicamento_nombre:     Optional[str] = None
    medicamento_dosis:      Optional[str] = None
    fecha_hora_programada:  datetime
    estado:                 EstadoToma
    fecha_hora_confirmacion: Optional[datetime]
    created_at:             datetime

    @field_serializer("fecha_hora_programada", "fecha_hora_confirmacion")
    def serializar_fecha_utc(self, value: Optional[datetime]) -> Optional[str]:
        if value is None:
            return None
        fecha_utc = value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
        return fecha_utc.isoformat()

    class Config:
        from_attributes = True


# ─── Resumen Cuidador ─────────────────────────────────────────────────────────

class ResumenCuidadorResponse(BaseModel):
    paciente_id:              UUID
    paciente_nombre:          Optional[str] = None
    paciente_email:           Optional[str] = None
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
    hora_formateada: Optional[str] = None


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
