# Estructura de la tabla User 
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Enum
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base
import enum
from sqlalchemy import ForeignKey, UniqueConstraint

# Definicion del Enum para el rol del usuario
class RolUsuario(str, enum.Enum):
    paciente = 'paciente'
    cuidador = 'cuidador'


class User(Base): # Hereda de Base para ser un modelo de SQLAlchemy
    __tablename__ = "users" # Nombre de la tabla

    id = Column(UUID(as_uuid=True), primary_key= True, default=uuid.uuid4)
    nombres = Column(String, nullable=False)
    email = Column( String, nullable=False, unique=True)
    password_hash = Column(String, nullable=False)
    rol = Column(
        Enum(RolUsuario, name="user_role_enum"),
        nullable=False,
        default=RolUsuario.paciente,  
    )
    edad = Column(Integer, nullable=True)
    contacto_emergencia_nombre = Column( String, nullable=True )
    contacto_emergencia_telefono = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    cuidador_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id"),
        nullable=True,
        unique=True  # <- esto es lo que fuerza el uno a uno
    )