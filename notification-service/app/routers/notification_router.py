# app/routers/notification_router.py

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
import uuid
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from sqlalchemy import or_

from app.database import get_db
import os
import httpx
from app.schemas.notification_schema import (
    NotificacionResponse,
    NotificacionConfirmarResponse,
    AlertaStockRequest,
)
from app.models.notification_model import Notificacion, EstadoNotificacion, TipoNotificacion
from app.services.scheduler_service import sincronizar_notificaciones

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000")
ZONA_COLOMBIA = ZoneInfo("America/Bogota")

router = APIRouter(prefix="/notifications", tags=["notifications"])


DEFAULT_TEST_PACIENTE_ID = "3f370ebf-9002-4064-9d0b-fbf8b36a5bec"

def _get_paciente_id(request: Request) -> str:
    """Extrae el paciente autenticado desde el header X-User-Id (inyectado por el API Gateway) o usa el paciente de prueba."""
    paciente_id = request.headers.get("X-User-Id")
    if not paciente_id:
        return DEFAULT_TEST_PACIENTE_ID
    return paciente_id


@router.get("/pendientes", response_model=List[NotificacionResponse])
def listar_pendientes(request: Request, db: Session = Depends(get_db)):
    """
    Lista las notificaciones pendientes del usuario autenticado (paciente o cuidador).
    Filtra por destinatario_id según el header X-User-Id inyectado por el API Gateway.
    """
    destinatario_id = _get_paciente_id(request)
    ahora_colombia = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    notificaciones = (
        db.query(Notificacion)
        .filter(
            Notificacion.destinatario_id == destinatario_id,
            Notificacion.estado == EstadoNotificacion.pendiente,
            Notificacion.fecha_hora_programada <= ahora_colombia,
        )
        .order_by(Notificacion.fecha_hora_programada.asc())
        .all()
    )
    return notificaciones


@router.post("/{id}/confirmar", response_model=NotificacionConfirmarResponse)
def confirmar_notificacion(id: UUID, request: Request, db: Session = Depends(get_db)):
    """
    El usuario (paciente o cuidador destinatario) confirma que atendió/vio la notificación.
    Cambia el estado a 'confirmada', deteniendo reintentos posteriores.
    """
    usuario_id = _get_paciente_id(request)
    notif = (
        db.query(Notificacion)
        .filter(
            Notificacion.id == id,
            (Notificacion.destinatario_id == usuario_id) | (Notificacion.paciente_id == usuario_id)
        )
        .first()
    )
    if not notif:
        raise HTTPException(status_code=404, detail="Notificación no encontrada")

    notif.estado = EstadoNotificacion.confirmada
    db.commit()
    db.refresh(notif)

    return NotificacionConfirmarResponse(
        message="Notificación confirmada correctamente",
        notificacion=notif
    )


@router.post("/internal/cerrar-por-referencia")
def cerrar_notificaciones_por_referencia(datos: dict, db: Session = Depends(get_db)):
    """
    Cierra todas las notificaciones pendientes asociadas a un ID de referencia (ej. una cita médica o toma).
    """
    ref_id = datos.get("referencia_id")
    if not ref_id:
        return {"cerradas": 0}
    
    pendientes = db.query(Notificacion).filter(
        Notificacion.referencia_id == UUID(ref_id),
        Notificacion.estado == EstadoNotificacion.pendiente
    ).all()

    for p in pendientes:
        p.estado = EstadoNotificacion.confirmada

    db.commit()
    return {"cerradas": len(pendientes)}


@router.post("/internal/cerrar-recordatorios-toma")
def cerrar_recordatorios_toma(datos: dict, db: Session = Depends(get_db)):
    referencia_id = datos.get("referencia_id")
    fecha_programada = datos.get("fecha_hora_programada")
    if not referencia_id or not fecha_programada:
        raise HTTPException(
            status_code=400,
            detail="referencia_id y fecha_hora_programada son requeridos",
        )

    try:
        id_medicamento = UUID(referencia_id)
        hora_programada = datetime.fromisoformat(fecha_programada)
    except (ValueError, TypeError) as error:
        raise HTTPException(status_code=400, detail="Datos de dosis no válidos") from error

    inicio = hora_programada - timedelta(minutes=5)
    fin = hora_programada + timedelta(minutes=5)
    pendientes = db.query(Notificacion).filter(
        Notificacion.referencia_id == id_medicamento,
        Notificacion.tipo == TipoNotificacion.medicamento,
        Notificacion.es_alerta_cuidador == False,
        Notificacion.estado == EstadoNotificacion.pendiente,
        Notificacion.fecha_hora_programada >= inicio,
        Notificacion.fecha_hora_programada <= fin,
        or_(
            Notificacion.mensaje.like("En 5 minutos:%"),
            Notificacion.mensaje.like("Hora de tomar tu medicamento:%"),
            Notificacion.mensaje.like("Aún no confirmas la toma de%"),
        ),
    ).all()

    for notificacion in pendientes:
        notificacion.estado = EstadoNotificacion.confirmada

    db.commit()
    return {"cerradas": len(pendientes)}


def trigger_sincronizacion_manual(db: Session = Depends(get_db)):
    """
    Endpoint de utilidad interna para disparar la sincronización inmediatamente
    (muy útil para pruebas automatizadas e integraciones).
    """
    sincronizar_notificaciones()
    return {"message": "Sincronización de notificaciones ejecutada"}


@router.post("/internal/alerta-stock")
def crear_alerta_stock(datos: AlertaStockRequest, db: Session = Depends(get_db)):
    """
    Endpoint interno para generar alerta de stock bajo tanto al paciente como a su cuidador.
    Se dispara cuando el stock_actual de un medicamento es <= stock_minimo_alerta.
    """
    ahora = datetime.utcnow()
    ahora_colombia = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    creadas = []

    # 1. Alerta para el PACIENTE
    # Verificar si ya tiene una alerta de stock pendiente sin confirmar para este medicamento
    alerta_paciente_existente = db.query(Notificacion).filter(
        Notificacion.referencia_id == datos.medicamento_id,
        Notificacion.destinatario_id == datos.paciente_id,
        Notificacion.estado == EstadoNotificacion.pendiente,
        Notificacion.mensaje.like("%dosis de " + datos.medicamento_nombre + "%")
    ).first()

    if not alerta_paciente_existente:
        notif_paciente = Notificacion(
            paciente_id=datos.paciente_id,
            destinatario_id=datos.paciente_id,
            es_alerta_cuidador=False,
            tipo=TipoNotificacion.medicamento,
            referencia_id=datos.medicamento_id,
            mensaje=f"Atención: Te quedan solo {datos.stock_actual} dosis de {datos.medicamento_nombre}. Recuerda surtir tu receta.",
            fecha_hora_programada=ahora_colombia,
            estado=EstadoNotificacion.pendiente,
            intentos=1,
            fecha_hora_ultimo_intento=ahora
        )
        db.add(notif_paciente)
        creadas.append("paciente")

    # 2. Alerta para el CUIDADOR (si existe vinculado)
    try:
        with httpx.Client(timeout=5.0) as client:
            res_auth = client.get(f"{AUTH_SERVICE_URL}/auth/internal/cuidador-de/{datos.paciente_id}")
            if res_auth.status_code == 200:
                cuidador_id = res_auth.json().get("cuidador_id")
                if cuidador_id:
                    alerta_cuidador_existente = db.query(Notificacion).filter(
                        Notificacion.referencia_id == datos.medicamento_id,
                        Notificacion.destinatario_id == cuidador_id,
                        Notificacion.estado == EstadoNotificacion.pendiente,
                        Notificacion.es_alerta_cuidador == True,
                        Notificacion.mensaje.like("%dosis de " + datos.medicamento_nombre + "%")
                    ).first()

                    if not alerta_cuidador_existente:
                        notif_cuidador = Notificacion(
                            paciente_id=datos.paciente_id,
                            destinatario_id=cuidador_id,
                            es_alerta_cuidador=True,
                            tipo=TipoNotificacion.medicamento,
                            referencia_id=datos.medicamento_id,
                            mensaje=f"Alerta de Stock: A tu familiar le quedan solo {datos.stock_actual} dosis de {datos.medicamento_nombre}. Recuerda surtir el medicamento.",
                            fecha_hora_programada=ahora_colombia,
                            estado=EstadoNotificacion.pendiente,
                            intentos=1,
                            fecha_hora_ultimo_intento=ahora
                        )
                        db.add(notif_cuidador)
                        creadas.append("cuidador")
    except Exception as e:
        # No interrumpir si auth-service no responde, se guarda la alerta del paciente
        pass

    db.commit()
    return {"message": "Alertas de stock procesadas", "destinatarios_notificados": creadas}


@router.post("/internal/alerta-personalizada")
def alerta_personalizada(datos: dict, db: Session = Depends(get_db)):
    """
    Permite a otros microservicios (como health-service al agendar una cita)
    enviar una notificación directa y personalizada a un usuario.
    """
    destinatario_id = datos.get("destinatario_id")
    if not destinatario_id:
        raise HTTPException(status_code=400, detail="destinatario_id es requerido")

    ahora = datetime.utcnow()
    ahora_colombia = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    nueva = Notificacion(
        paciente_id=UUID(destinatario_id),
        destinatario_id=UUID(destinatario_id),
        es_alerta_cuidador=False,
        tipo=TipoNotificacion.cita,
        referencia_id=UUID(datos["referencia_id"]) if datos.get("referencia_id") else uuid.uuid4(),
        mensaje=datos.get("mensaje", "Tienes una nueva notificación de NotiFarma"),
        fecha_hora_programada=ahora_colombia,
        estado=EstadoNotificacion.pendiente,
        intentos=1,
        fecha_hora_ultimo_intento=ahora,
    )
    db.add(nueva)
    db.commit()
    return {"message": "Notificación personalizada creada"}
