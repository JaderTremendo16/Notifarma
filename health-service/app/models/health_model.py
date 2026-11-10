# app/models/health_model.py

import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Enum, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class AnimoEnum(str, enum.Enum):
    muy_bien = "muy_bien"
    bien     = "bien"
    regular  = "regular"
    mal      = "mal"


class IntensidadEnum(str, enum.Enum):
    leve     = "leve"
    moderada = "moderada"
    fuerte   = "fuerte"


class EstadoAnimo(Base):
    """Registro de cómo se siente el paciente en un momento dado."""
    __tablename__ = "estados_animo"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    paciente_id = Column(UUID(as_uuid=True), nullable=False)
    animo       = Column(Enum(AnimoEnum, name="animo_enum"), nullable=False)
    fecha_hora  = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at  = Column(DateTime, default=datetime.utcnow)


class EstadoCitaEnum(str, enum.Enum):
    programada = "programada"
    asistida   = "asistida"
    no_asistida = "no_asistida"
    sin_confirmar = "sin_confirmar"


class CitaMedica(Base):
    """Citas médicas programadas del paciente."""
    __tablename__ = "citas_medicas"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    paciente_id  = Column(UUID(as_uuid=True), nullable=False, index=True)
    especialidad = Column(String, nullable=False)   # ej. Cardiología, Medicina General
    medico       = Column(String, nullable=True)    # ej. Dr. Pérez
    lugar        = Column(String, nullable=True)    # ej. Hospital Central (nombre del sitio)
    direccion    = Column(String, nullable=True)    # ej. Cra 43 # 75-12, Consultorio 304
    fecha_hora   = Column(DateTime, nullable=False) # Fecha y hora de la cita (UTC)
    notas        = Column(String, nullable=True)
    estado       = Column(String, default="programada", nullable=False) # programada, asistida, no_asistida, sin_confirmar
    activo       = Column(Boolean, default=True, nullable=False)
    created_at   = Column(DateTime, default=datetime.utcnow)

