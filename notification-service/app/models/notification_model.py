# app/models/notification_model.py

import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Enum
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class TipoNotificacion(str, enum.Enum):
    medicamento = "medicamento"
    cita        = "cita"


class EstadoNotificacion(str, enum.Enum):
    pendiente  = "pendiente"
    entregada  = "entregada"
    confirmada = "confirmada"


class Notificacion(Base):
    __tablename__ = "notificaciones"

    id                        = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    paciente_id               = Column(UUID(as_uuid=True), nullable=False, index=True)
    tipo                      = Column(
                                    Enum(TipoNotificacion, name="tipo_notificacion_enum"),
                                    nullable=False
                                )
    referencia_id             = Column(UUID(as_uuid=True), nullable=False)
    mensaje                   = Column(String, nullable=False)
    fecha_hora_programada     = Column(DateTime, nullable=False)
    estado                    = Column(
                                    Enum(EstadoNotificacion, name="estado_notificacion_enum"),
                                    default=EstadoNotificacion.pendiente,
                                    nullable=False,
                                    index=True
                                )
    intentos                  = Column(Integer, default=0, nullable=False)
    fecha_hora_ultimo_intento = Column(DateTime, nullable=True)
    created_at                = Column(DateTime, default=datetime.utcnow)
