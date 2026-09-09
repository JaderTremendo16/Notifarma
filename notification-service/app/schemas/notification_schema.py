# app/schemas/notification_schema.py

from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime
from app.models.notification_model import TipoNotificacion, EstadoNotificacion


class NotificacionResponse(BaseModel):
    id:                        UUID
    paciente_id:               UUID
    destinatario_id:           UUID
    es_alerta_cuidador:        bool
    tipo:                      TipoNotificacion
    referencia_id:             UUID
    mensaje:                   str
    fecha_hora_programada:     datetime
    estado:                    EstadoNotificacion
    intentos:                  int
    fecha_hora_ultimo_intento: Optional[datetime]
    created_at:                datetime

    class Config:
        from_attributes = True


class NotificacionConfirmarResponse(BaseModel):
    message:      str
    notificacion: NotificacionResponse


class AlertaStockRequest(BaseModel):
    paciente_id:        UUID
    medicamento_id:     UUID
    medicamento_nombre: str
    stock_actual:       int

