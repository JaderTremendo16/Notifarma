# app/models/medication_model.py

import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Integer, Boolean, DateTime, Date, Time, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class EstadoToma(str, enum.Enum):
    pendiente = "pendiente"
    tomado    = "tomado"
    omitido   = "omitido"


class Medicamento(Base):
    __tablename__ = "medicamentos"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    paciente_id      = Column(UUID(as_uuid=True), nullable=False)
    nombre           = Column(String, nullable=False)
    dosis            = Column(String, nullable=True)
    frecuencia_horas = Column(Integer, nullable=False)
    hora_inicio      = Column(Time, nullable=False)
    fecha_inicio     = Column(Date, nullable=True)
    fecha_fin        = Column(Date, nullable=True)
    stock_actual     = Column(Integer, default=0, nullable=False)
    stock_minimo_alerta = Column(Integer, default=5, nullable=False)
    activo           = Column(Boolean, default=True, nullable=False)
    created_at       = Column(DateTime, default=datetime.utcnow)
    updated_at       = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Toma(Base):
    __tablename__ = "tomas"

    id                     = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    medicamento_id         = Column(UUID(as_uuid=True), ForeignKey("medicamentos.id"), nullable=False)
    paciente_id            = Column(UUID(as_uuid=True), nullable=False)
    fecha_hora_programada  = Column(DateTime, nullable=False)
    estado                 = Column(
                                Enum(EstadoToma, name="estado_toma_enum"),
                                default=EstadoToma.pendiente,
                                nullable=False,
                             )
    fecha_hora_confirmacion = Column(DateTime, nullable=True)
    created_at             = Column(DateTime, default=datetime.utcnow)


class RegistroAuditoria(Base):
    __tablename__ = "auditoria_medica"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    paciente_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    usuario_id  = Column(UUID(as_uuid=True), nullable=False)
    accion      = Column(String, nullable=False)  # Ej: REGISTRO_TOMA, RECARGA_STOCK, CREACION_MEDICAMENTO
    detalle     = Column(String, nullable=True)
    fecha_hora  = Column(DateTime, default=datetime.utcnow, nullable=False)

