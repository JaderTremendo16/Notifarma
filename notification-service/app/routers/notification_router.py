# app/routers/notification_router.py

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from datetime import datetime

from app.database import get_db
from app.models.notification_model import Notificacion, EstadoNotificacion
from app.schemas.notification_schema import NotificacionResponse, NotificacionConfirmarResponse
from app.services.scheduler_service import sincronizar_notificaciones

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _get_paciente_id(request: Request) -> str:
    """Extrae el paciente autenticado desde el header X-User-Id (inyectado por el API Gateway)."""
    paciente_id = request.headers.get("X-User-Id")
    if not paciente_id:
        raise HTTPException(status_code=400, detail="Header X-User-Id requerido")
    return paciente_id


@router.get("/pendientes", response_model=List[NotificacionResponse])
def listar_pendientes(request: Request, db: Session = Depends(get_db)):
    """
    Lista las notificaciones pendientes del paciente autenticado.
    El cliente móvil consulta este endpoint mediante POLLING periódico.
    """
    paciente_id = _get_paciente_id(request)
    notificaciones = (
        db.query(Notificacion)
        .filter(
            Notificacion.paciente_id == paciente_id,
            Notificacion.estado == EstadoNotificacion.pendiente
        )
        .order_by(Notificacion.fecha_hora_programada.asc())
        .all()
    )
    return notificaciones


@router.post("/{id}/confirmar", response_model=NotificacionConfirmarResponse)
def confirmar_notificacion(id: UUID, request: Request, db: Session = Depends(get_db)):
    """
    El paciente confirma que atendió/vio la notificación.
    Cambia el estado a 'confirmada', deteniendo reintentos posteriores.
    """
    paciente_id = _get_paciente_id(request)
    notif = (
        db.query(Notificacion)
        .filter(
            Notificacion.id == id,
            Notificacion.paciente_id == paciente_id
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


@router.post("/internal/trigger-sync")
def trigger_sincronizacion_manual(db: Session = Depends(get_db)):
    """
    Endpoint de utilidad interna para disparar la sincronización inmediatamente
    (muy útil para pruebas automatizadas e integraciones).
    """
    sincronizar_notificaciones()
    return {"message": "Sincronización de notificaciones ejecutada"}
