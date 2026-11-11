import os
import logging
import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List, Tuple
from uuid import UUID
from datetime import datetime, date, timedelta, timezone
from zoneinfo import ZoneInfo

from app.database import get_db
from app.models.health_model import EstadoAnimo, CitaMedica
from app.schemas.health_schema import (
    EstadoAnimoCreate,
    EstadoAnimoResponse,
    HistorialResponse,
    RecomendacionResponse,
    CitaMedicaCreate,
    CitaMedicaUpdate,
    CitaMedicaResponse,
    CitaEstadoUpdate,
)
from app.services.wellness_rules import evaluar_bienestar

router = APIRouter(prefix="/health", tags=["health"])

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8004")

DEFAULT_TEST_PACIENTE_ID = "3f370ebf-9002-4064-9d0b-fbf8b36a5bec"
ZONA_COLOMBIA = ZoneInfo("America/Bogota")
logger = logging.getLogger(__name__)


def _cerrar_notificaciones_cita(cita_id: UUID) -> None:
    try:
        with httpx.Client(timeout=3.0) as client:
            response = client.post(
                f"{NOTIFICATION_SERVICE_URL}/notifications/internal/cerrar-por-referencia",
                json={"referencia_id": str(cita_id)},
            )
            response.raise_for_status()
    except httpx.HTTPError as error:
        logger.warning("No se pudieron cerrar avisos de la cita %s: %s", cita_id, error)

def _resolver_paciente_y_rol(request: Request) -> Tuple[str, bool, str]:
    """
    Retorna (paciente_id, es_cuidador, user_id).
    Si quien llama es un cuidador vinculado, paciente_id será el de su paciente a cargo.
    """
    user_id = request.headers.get("X-User-Id") or DEFAULT_TEST_PACIENTE_ID
    paciente_id = user_id
    es_cuidador = False

    try:
        with httpx.Client(timeout=3.0) as client:
            res_auth = client.get(f"{AUTH_SERVICE_URL}/auth/internal/paciente-de/{user_id}")
            if res_auth.status_code == 200:
                p_id = res_auth.json().get("paciente_id")
                if p_id:
                    paciente_id = p_id
                    es_cuidador = True
    except Exception:
        pass

    return paciente_id, es_cuidador, user_id

def _get_paciente_id(request: Request) -> str:
    paciente_id, _, _ = _resolver_paciente_y_rol(request)
    return paciente_id


def _inicio_hoy() -> datetime:
    """Retorna el inicio del día en Colombia como fecha UTC sin zona."""
    inicio_colombia = datetime.combine(
        datetime.now(ZONA_COLOMBIA).date(),
        datetime.min.time(),
        tzinfo=ZONA_COLOMBIA,
    )
    return inicio_colombia.astimezone(timezone.utc).replace(tzinfo=None)


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
    """Devuelve los registros del día actual en Colombia."""
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


# ─── Historial ────────────────────────────────────────────────────────────────

@router.get("/historial", response_model=HistorialResponse)
def historial(
    request: Request,
    dias: int = 7,
    db: Session = Depends(get_db),
):
    """
    Devuelve el historial de animos del paciente en los ultimos N dias.
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

    return HistorialResponse(animos=animos, sintomas=[])


# ─── Recomendacion del dia ────────────────────────────────────────────────────

@router.get("/recomendacion-hoy", response_model=RecomendacionResponse)
def recomendacion_hoy(request: Request, db: Session = Depends(get_db)):
    """
    Devuelve un mensaje de bienestar calculado con un motor de reglas basado
    en el ultimo estado de animo registrado hoy por el paciente.

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

    animo_valor = ultimo_animo.animo.value if ultimo_animo else None
    mensaje = evaluar_bienestar(animo_valor)

    return RecomendacionResponse(mensaje=mensaje)


# ─── Citas Médicas ────────────────────────────────────────────────────────────

@router.get("/citas/internal/activas")
def citas_internas_activas(db: Session = Depends(get_db)):
    """
    Endpoint interno para el Notification Service (sin autenticación requerida).
    Retorna citas recientes y futuras para recordatorios y detección de citas sin confirmar.
    """
    ahora = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    inicio = ahora - timedelta(days=1)
    limite = ahora + timedelta(days=2)
    citas = (
        db.query(CitaMedica)
        .filter(
            CitaMedica.activo == True,
            CitaMedica.fecha_hora >= inicio,
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
            "direccion":    c.direccion,
            "estado":       c.estado,
            "fecha_hora":   c.fecha_hora.replace(tzinfo=ZONA_COLOMBIA).isoformat()
        }
        for c in citas
    ]


@router.post("/citas/internal/{cita_id}/sin-confirmar")
def marcar_cita_sin_confirmar(cita_id: UUID, db: Session = Depends(get_db)):
    cita = db.query(CitaMedica).filter(
        CitaMedica.id == cita_id,
        CitaMedica.activo == True,
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita médica no encontrada")

    ahora = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    if ahora < cita.fecha_hora + timedelta(hours=2):
        raise HTTPException(
            status_code=409,
            detail="La cita aún está dentro del período de confirmación.",
        )
    if cita.estado == "programada":
        cita.estado = "sin_confirmar"
        db.commit()
        db.refresh(cita)
    return {"estado": cita.estado}


@router.post("/citas", response_model=CitaMedicaResponse, status_code=201)
def crear_cita(
    datos: CitaMedicaCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Crea una cita médica para el paciente autenticado o para el paciente a cargo del cuidador.
    Si la cita es creada por un cuidador, se genera una notificación para el paciente.
    """
    paciente_id, es_cuidador, user_id = _resolver_paciente_y_rol(request)
    nueva = CitaMedica(
        paciente_id=paciente_id,
        especialidad=datos.especialidad,
        medico=datos.medico,
        lugar=datos.lugar,
        direccion=datos.direccion,
        fecha_hora=datos.fecha_hora,
        notas=datos.notas,
        estado="programada",
    )
    db.add(nueva)
    db.commit()
    db.refresh(nueva)

    # Si fue creada por un cuidador, enviar notificación al paciente
    if es_cuidador:
        try:
            with httpx.Client(timeout=3.0) as client:
                client.post(
                    f"{NOTIFICATION_SERVICE_URL}/notifications/internal/alerta-personalizada",
                    json={
                        "destinatario_id": str(paciente_id),
                        "tipo": "CITA_MEDICA",
                        "titulo": "📅 Nueva Cita Médica Programada",
                        "referencia_id": str(nueva.id),
                        "mensaje": f"Tu cuidador te ha agendado una cita de {datos.especialidad} para el {datos.fecha_hora.strftime('%Y-%m-%d %I:%M %p')}.",
                    }
                )
        except httpx.HTTPError as error:
            logger.warning("No se pudo notificar la nueva cita %s: %s", nueva.id, error)

    return nueva


@router.get("/citas", response_model=List[CitaMedicaResponse])
def listar_citas(request: Request, db: Session = Depends(get_db)):
    """Lista todas las citas médicas activas del paciente autenticado o a cargo."""
    paciente_id, _, _ = _resolver_paciente_y_rol(request)
    return (
        db.query(CitaMedica)
        .filter(CitaMedica.paciente_id == paciente_id, CitaMedica.activo == True)
        .order_by(CitaMedica.fecha_hora.asc())
        .all()
    )


@router.put("/citas/{cita_id}", response_model=CitaMedicaResponse)
def actualizar_cita(
    cita_id: UUID,
    datos: CitaMedicaUpdate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Permite al paciente o cuidador actualizar fecha, hora, lugar, dirección o notas de una cita."""
    paciente_id, _, _ = _resolver_paciente_y_rol(request)
    cita = db.query(CitaMedica).filter(
        CitaMedica.id == cita_id,
        CitaMedica.paciente_id == paciente_id,
        CitaMedica.activo == True,
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita médica no encontrada")

    if (
        datos.fecha_hora is not None
        and datos.fecha_hora <= datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    ):
        raise HTTPException(
            status_code=409,
            detail="La fecha y hora de la cita debe ser futura.",
        )

    if datos.especialidad is not None:
        cita.especialidad = datos.especialidad
    if datos.medico is not None:
        cita.medico = datos.medico
    if datos.lugar is not None:
        cita.lugar = datos.lugar
    if datos.direccion is not None:
        cita.direccion = datos.direccion
    if datos.fecha_hora is not None:
        if datos.fecha_hora != cita.fecha_hora:
            cita.estado = "programada"
        cita.fecha_hora = datos.fecha_hora
    if datos.notas is not None:
        cita.notas = datos.notas

    db.commit()
    db.refresh(cita)
    _cerrar_notificaciones_cita(cita.id)
    return cita


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


@router.patch("/citas/{cita_id}/estado", response_model=CitaMedicaResponse)
def actualizar_estado_cita(
    cita_id: UUID,
    datos: CitaEstadoUpdate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Permite al paciente o cuidador registrar asistencia ('asistida') o indicar ('no_asistida')."""
    paciente_id, _, _ = _resolver_paciente_y_rol(request)
    cita = db.query(CitaMedica).filter(
        CitaMedica.id == cita_id,
        CitaMedica.paciente_id == paciente_id,
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita médica no encontrada")
    
    estado = datos.estado
    if cita.estado == estado:
        return cita
    if estado in {"asistida", "no_asistida"}:
        ahora = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
        inicio_confirmacion = cita.fecha_hora - timedelta(minutes=150)
        fin_confirmacion = cita.fecha_hora + timedelta(hours=2)
        if not inicio_confirmacion <= ahora <= fin_confirmacion:
            raise HTTPException(
                status_code=409,
                detail="La asistencia solo se puede confirmar desde 2 horas y media antes hasta 2 horas después de la cita.",
            )

    cita.estado = estado
    db.commit()
    db.refresh(cita)

    # Si la cita fue marcada como asistida o no_asistida, cerrar automáticamente
    # cualquier notificación pendiente asociada a esta cita en notification-service
    if cita.estado in ["asistida", "no_asistida"]:
        _cerrar_notificaciones_cita(cita.id)

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
    _cerrar_notificaciones_cita(cita.id)
    return {"message": f"Cita de {cita.especialidad} cancelada"}
