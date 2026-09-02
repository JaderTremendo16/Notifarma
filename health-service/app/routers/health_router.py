# app/routers/health_router.py

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from datetime import datetime, date, timedelta

from app.database import get_db
from app.models.health_model import EstadoAnimo, Sintoma, RegistroSintoma, CitaMedica
from app.schemas.health_schema import (
    EstadoAnimoCreate,
    EstadoAnimoResponse,
    SintomaResponse,
    RegistroSintomaCreate,
    RegistroSintomaResponse,
    HistorialResponse,
    RecomendacionResponse,
    CitaMedicaCreate,
    CitaMedicaResponse,
)
from app.services.wellness_rules import evaluar_bienestar

router = APIRouter(prefix="/health", tags=["health"])


def _get_paciente_id(request: Request) -> str:
    """Extrae el paciente autenticado desde el header X-User-Id (inyectado por el API Gateway)."""
    paciente_id = request.headers.get("X-User-Id")
    if not paciente_id:
        raise HTTPException(status_code=400, detail="Header X-User-Id requerido")
    return paciente_id


def _inicio_hoy() -> datetime:
    """Retorna el inicio del dia actual en UTC (00:00:00)."""
    hoy = datetime.utcnow().date()
    return datetime.combine(hoy, datetime.min.time())


# ─── Estado de Animo ──────────────────────────────────────────────────────────

@router.post("/mood", response_model=EstadoAnimoResponse, status_code=201)
def registrar_animo(
    datos: EstadoAnimoCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Registra el estado de animo del paciente. Se permiten multiples registros por dia."""
    paciente_id = _get_paciente_id(request)
    nuevo = EstadoAnimo(
        paciente_id=paciente_id,
        animo=datos.animo,
        fecha_hora=datetime.utcnow(),
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@router.get("/mood/hoy", response_model=List[EstadoAnimoResponse])
def animo_hoy(request: Request, db: Session = Depends(get_db)):
    """Devuelve todos los registros de estado de animo del paciente para el dia de hoy (UTC)."""
    paciente_id = _get_paciente_id(request)
    inicio = _inicio_hoy()
    return (
        db.query(EstadoAnimo)
        .filter(
            EstadoAnimo.paciente_id == paciente_id,
            EstadoAnimo.fecha_hora >= inicio,
        )
        .order_by(EstadoAnimo.fecha_hora.desc())
        .all()
    )


# ─── Sintomas ─────────────────────────────────────────────────────────────────

@router.get("/sintomas/catalogo", response_model=List[SintomaResponse])
def catalogo_sintomas(db: Session = Depends(get_db)):
    """Devuelve el catalogo fijo de sintomas disponibles. No requiere autenticacion."""
    return db.query(Sintoma).order_by(Sintoma.nombre).all()


@router.post("/sintomas", response_model=List[RegistroSintomaResponse], status_code=201)
def registrar_sintomas(
    datos: List[RegistroSintomaCreate],
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Registra uno o varios sintomas del paciente en un solo request.
    Cada item puede usar sintoma_id (del catalogo) o sintoma_otro (texto libre).
    """
    if not datos:
        raise HTTPException(status_code=400, detail="Debe enviar al menos un sintoma")

    paciente_id = _get_paciente_id(request)
    creados = []

    for item in datos:
        registro = RegistroSintoma(
            paciente_id=paciente_id,
            sintoma_id=item.sintoma_id,
            sintoma_otro=item.sintoma_otro,
            intensidad=item.intensidad,
            observacion=item.observacion,
            fecha_hora=datetime.utcnow(),
        )
        db.add(registro)
        creados.append(registro)

    db.commit()
    for r in creados:
        db.refresh(r)

    return creados


# ─── Historial ────────────────────────────────────────────────────────────────

@router.get("/historial", response_model=HistorialResponse)
def historial(
    request: Request,
    dias: int = 7,
    db: Session = Depends(get_db),
):
    """
    Devuelve el historial de animos y sintomas del paciente en los ultimos N dias.
    Parametro opcional: dias (default 7).
    """
    paciente_id = _get_paciente_id(request)
    desde = datetime.utcnow() - timedelta(days=dias)

    animos = (
        db.query(EstadoAnimo)
        .filter(
            EstadoAnimo.paciente_id == paciente_id,
            EstadoAnimo.fecha_hora >= desde,
        )
        .order_by(EstadoAnimo.fecha_hora.desc())
        .all()
    )

    sintomas = (
        db.query(RegistroSintoma)
        .filter(
            RegistroSintoma.paciente_id == paciente_id,
            RegistroSintoma.fecha_hora >= desde,
        )
        .order_by(RegistroSintoma.fecha_hora.desc())
        .all()
    )

    return HistorialResponse(animos=animos, sintomas=sintomas)


# ─── Recomendacion del dia ────────────────────────────────────────────────────

@router.get("/recomendacion-hoy", response_model=RecomendacionResponse)
def recomendacion_hoy(request: Request, db: Session = Depends(get_db)):
    """
    Devuelve un mensaje de bienestar calculado con un motor de reglas basado
    en el ultimo estado de animo y los sintomas registrados hoy por el paciente.

    Este endpoint NO diagnostica enfermedades ni recomienda medicamentos.
    Solo ofrece consejos generales de autocuidado.
    """
    paciente_id = _get_paciente_id(request)
    inicio = _inicio_hoy()

    # Ultimo estado de animo del dia
    ultimo_animo = (
        db.query(EstadoAnimo)
        .filter(
            EstadoAnimo.paciente_id == paciente_id,
            EstadoAnimo.fecha_hora >= inicio,
        )
        .order_by(EstadoAnimo.fecha_hora.desc())
        .first()
    )

    # Sintomas del dia
    sintomas_hoy = (
        db.query(RegistroSintoma)
        .filter(
            RegistroSintoma.paciente_id == paciente_id,
            RegistroSintoma.fecha_hora >= inicio,
        )
        .all()
    )

    animo_valor = ultimo_animo.animo.value if ultimo_animo else None
    mensaje = evaluar_bienestar(animo_valor, sintomas_hoy)

    return RecomendacionResponse(mensaje=mensaje)


# ─── Citas Médicas ────────────────────────────────────────────────────────────

@router.get("/citas/internal/activas")
def citas_internas_activas(db: Session = Depends(get_db)):
    """
    Endpoint interno para el Notification Service (sin autenticación requerida).
    Retorna citas activas y futuras para generar recordatorios.
    """
    ahora = datetime.utcnow()
    # Citas activas desde hoy en adelante (hasta 2 días en el futuro para anticipación)
    limite = ahora + timedelta(days=2)
    citas = (
        db.query(CitaMedica)
        .filter(
            CitaMedica.activo == True,
            CitaMedica.fecha_hora >= ahora,
            CitaMedica.fecha_hora <= limite
        )
        .all()
    )
    return [
        {
            "cita_id":      str(c.id),
            "paciente_id":  str(c.paciente_id),
            "especialidad": c.especialidad,
            "medico":       c.medico,
            "lugar":        c.lugar,
            "fecha_hora":   c.fecha_hora.isoformat()
        }
        for c in citas
    ]


@router.post("/citas", response_model=CitaMedicaResponse, status_code=201)
def crear_cita(
    datos: CitaMedicaCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Crea una cita médica para el paciente autenticado."""
    paciente_id = _get_paciente_id(request)
    nueva = CitaMedica(
        paciente_id=paciente_id,
        especialidad=datos.especialidad,
        medico=datos.medico,
        lugar=datos.lugar,
        fecha_hora=datos.fecha_hora,
        notas=datos.notas,
    )
    db.add(nueva)
    db.commit()
    db.refresh(nueva)
    return nueva


@router.get("/citas", response_model=List[CitaMedicaResponse])
def listar_citas(request: Request, db: Session = Depends(get_db)):
    """Lista todas las citas médicas activas del paciente autenticado."""
    paciente_id = _get_paciente_id(request)
    return (
        db.query(CitaMedica)
        .filter(CitaMedica.paciente_id == paciente_id, CitaMedica.activo == True)
        .order_by(CitaMedica.fecha_hora.asc())
        .all()
    )


@router.get("/citas/{cita_id}", response_model=CitaMedicaResponse)
def detalle_cita(cita_id: UUID, request: Request, db: Session = Depends(get_db)):
    """Obtiene el detalle de una cita específica del paciente."""
    paciente_id = _get_paciente_id(request)
    cita = db.query(CitaMedica).filter(
        CitaMedica.id == cita_id,
        CitaMedica.paciente_id == paciente_id,
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita médica no encontrada")
    return cita


@router.delete("/citas/{cita_id}")
def cancelar_cita(cita_id: UUID, request: Request, db: Session = Depends(get_db)):
    """Marca la cita como inactiva (cancelada)."""
    paciente_id = _get_paciente_id(request)
    cita = db.query(CitaMedica).filter(
        CitaMedica.id == cita_id,
        CitaMedica.paciente_id == paciente_id,
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita médica no encontrada")
    cita.activo = False
    db.commit()
    return {"message": f"Cita de {cita.especialidad} cancelada"}

