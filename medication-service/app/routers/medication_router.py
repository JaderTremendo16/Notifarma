# app/routers/medication_router.py

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from datetime import datetime

from app.database import get_db
from app.models.medication_model import Medicamento, Toma, EstadoToma
from app.schemas.medication_schema import (
    MedicamentoCreate,
    MedicamentoUpdate,
    MedicamentoResponse,
    TomaCreate,
    TomaResponse,
    ProximoMedicamentoResponse,
)
from app.services.medication_service import calcular_proxima_toma

router = APIRouter(prefix="/medications", tags=["medications"])


def _get_paciente_id(request: Request) -> str:
    """Extrae el paciente autenticado desde el header X-User-Id (inyectado por el API Gateway)."""
    paciente_id = request.headers.get("X-User-Id")
    if not paciente_id:
        raise HTTPException(status_code=400, detail="Header X-User-Id requerido")
    return paciente_id


# ─── Rutas estáticas — deben declararse ANTES de /{med_id} ───────────────────

@router.get("/tomas/historial", response_model=List[TomaResponse])
def historial_tomas(request: Request, db: Session = Depends(get_db)):
    """Historial completo de cumplimiento del paciente autenticado."""
    paciente_id = _get_paciente_id(request)
    tomas = (
        db.query(Toma)
        .filter(Toma.paciente_id == paciente_id)
        .order_by(Toma.fecha_hora_programada.desc())
        .all()
    )
    return tomas


@router.get("/proximo", response_model=ProximoMedicamentoResponse)
def proximo_medicamento(request: Request, db: Session = Depends(get_db)):
    """Devuelve el medicamento cuya próxima toma es la más cercana al momento actual (para el Dashboard)."""
    paciente_id = _get_paciente_id(request)
    medicamentos = (
        db.query(Medicamento)
        .filter(Medicamento.paciente_id == paciente_id, Medicamento.activo == True)
        .all()
    )

    if not medicamentos:
        raise HTTPException(status_code=404, detail="No hay medicamentos activos para este paciente")

    mejor       = None
    mejor_tiempo = None

    for med in medicamentos:
        proxima = calcular_proxima_toma(med.hora_inicio, med.frecuencia_horas)
        if mejor_tiempo is None or proxima < mejor_tiempo:
            mejor_tiempo = proxima
            mejor        = med

    return ProximoMedicamentoResponse(
        medicamento_id=mejor.id,
        nombre=mejor.nombre,
        dosis=mejor.dosis,
        proxima_toma=mejor_tiempo,
    )


@router.get("/internal/horarios-activos")
def horarios_activos(db: Session = Depends(get_db)):
    """
    Endpoint interno para uso exclusivo del Notification Service.
    No requiere autenticación — accesible únicamente dentro de la red Docker Compose.
    Devuelve todos los medicamentos activos con su horario para generar recordatorios.
    """
    medicamentos = db.query(Medicamento).filter(Medicamento.activo == True).all()
    return [
        {
            "medicamento_id":  str(med.id),
            "paciente_id":     str(med.paciente_id),
            "nombre":          med.nombre,
            "frecuencia_horas": med.frecuencia_horas,
            "hora_inicio":     str(med.hora_inicio),  # "HH:MM:SS"
        }
        for med in medicamentos
    ]


# ─── CRUD principal ───────────────────────────────────────────────────────────

@router.post("", response_model=MedicamentoResponse, status_code=201)
def crear_medicamento(
    datos: MedicamentoCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Crea un medicamento para el paciente autenticado vía X-User-Id."""
    paciente_id = _get_paciente_id(request)
    nuevo = Medicamento(
        paciente_id=paciente_id,
        nombre=datos.nombre,
        dosis=datos.dosis,
        frecuencia_horas=datos.frecuencia_horas,
        hora_inicio=datos.hora_inicio,
        fecha_inicio=datos.fecha_inicio,
        fecha_fin=datos.fecha_fin,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@router.get("", response_model=List[MedicamentoResponse])
def listar_medicamentos(request: Request, db: Session = Depends(get_db)):
    """Lista todos los medicamentos activos del paciente autenticado."""
    paciente_id = _get_paciente_id(request)
    return (
        db.query(Medicamento)
        .filter(Medicamento.paciente_id == paciente_id, Medicamento.activo == True)
        .all()
    )


@router.get("/{med_id}", response_model=MedicamentoResponse)
def detalle_medicamento(med_id: UUID, request: Request, db: Session = Depends(get_db)):
    """Devuelve el detalle de un medicamento específico del paciente."""
    paciente_id = _get_paciente_id(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    return med


@router.put("/{med_id}", response_model=MedicamentoResponse)
def editar_medicamento(
    med_id: UUID,
    datos: MedicamentoUpdate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Edita campos de un medicamento existente. Solo modifica los campos enviados."""
    paciente_id = _get_paciente_id(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")

    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(med, campo, valor)

    med.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(med)
    return med


@router.delete("/{med_id}")
def eliminar_medicamento(med_id: UUID, request: Request, db: Session = Depends(get_db)):
    """Marca el medicamento como inactivo (soft delete — conserva el historial)."""
    paciente_id = _get_paciente_id(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    med.activo     = False
    med.updated_at = datetime.utcnow()
    db.commit()
    return {"message": f"Medicamento '{med.nombre}' marcado como inactivo"}


# ─── Tomas ────────────────────────────────────────────────────────────────────

@router.post("/{med_id}/tomas", response_model=TomaResponse, status_code=201)
def registrar_toma(
    med_id: UUID,
    datos: TomaCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Registra una toma (tomado / omitido / pendiente) para un medicamento.
    Si no se envía fecha_hora_programada se usa el momento actual UTC.
    Si el estado es 'tomado' se registra fecha_hora_confirmacion automáticamente.
    """
    paciente_id = _get_paciente_id(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")

    fecha_hora_programada   = datos.fecha_hora_programada or datetime.utcnow()
    fecha_hora_confirmacion = datetime.utcnow() if datos.estado == EstadoToma.tomado else None

    toma = Toma(
        medicamento_id=med_id,
        paciente_id=paciente_id,
        fecha_hora_programada=fecha_hora_programada,
        estado=datos.estado,
        fecha_hora_confirmacion=fecha_hora_confirmacion,
    )
    db.add(toma)
    db.commit()
    db.refresh(toma)
    return toma
