import io
import logging
import os
from datetime import datetime, date, timedelta, time, timezone
from zoneinfo import ZoneInfo
from typing import List, Optional
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.medication_model import Medicamento, Toma, EstadoToma, RegistroAuditoria
from app.schemas.medication_schema import (
    MedicamentoCreate,
    MedicamentoUpdate,
    MedicamentoResponse,
    StockUpdate,
    ResumenCuidadorResponse,
    TomaCreate,
    TomaResponse,
    ProximoMedicamentoResponse,
    RegistroAuditoriaResponse,
    PrediccionAgotamientoItem,
)
from app.services.medication_service import calcular_proxima_toma

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8004")
HEALTH_SERVICE_URL = os.getenv("HEALTH_SERVICE_URL", "http://health-service:8003")

router = APIRouter(prefix="/medications", tags=["medications"])
logger = logging.getLogger(__name__)


DEFAULT_TEST_PACIENTE_ID = "3f370ebf-9002-4064-9d0b-fbf8b36a5bec"

def _resolver_paciente_y_rol(request: Request) -> tuple[str, bool, str]:
    """
    Retorna (paciente_id, es_cuidador, user_id).
    Si quien llama es un cuidador vinculado, paciente_id será el del paciente a cargo.
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
    """Extrae el paciente autenticado o el paciente vinculado si quien consulta es cuidador."""
    paciente_id, _, _ = _resolver_paciente_y_rol(request)
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
        .filter(
            Medicamento.paciente_id == paciente_id,
            Medicamento.activo == True,
            Medicamento.stock_actual > 0,
        )
        .all()
    )

    if not medicamentos:
        raise HTTPException(status_code=404, detail="No hay medicamentos activos para este paciente")

    mejor       = None
    mejor_tiempo = None

    for med in medicamentos:
        proxima = calcular_proxima_toma(
            med.hora_inicio,
            med.frecuencia_horas,
            med.fecha_inicio,
            med.fecha_fin,
        )
        if proxima is None:
            continue
        if mejor_tiempo is None or proxima < mejor_tiempo:
            mejor_tiempo = proxima
            mejor        = med

    if mejor is None or mejor_tiempo is None:
        raise HTTPException(
            status_code=404,
            detail="No hay próximas tomas disponibles para los tratamientos activos.",
        )

    hora_str = mejor_tiempo.strftime("%I:%M %p")

    return ProximoMedicamentoResponse(
        medicamento_id=mejor.id,
        nombre=mejor.nombre,
        dosis=mejor.dosis,
        proxima_toma=mejor_tiempo,
        hora_formateada=hora_str,
    )


@router.get("/internal/horarios-activos")
def horarios_activos(db: Session = Depends(get_db)):
    """
    Endpoint interno para uso exclusivo del Notification Service.
    No requiere autenticación — accesible únicamente dentro de la red Docker Compose.
    Devuelve todos los medicamentos activos con su horario para generar recordatorios,
    respetando las fechas de vigencia (fecha_inicio y fecha_fin).
    """
    ahora_col = datetime.now(ZoneInfo("America/Bogota")).date()
    medicamentos = db.query(Medicamento).filter(Medicamento.activo == True).all()
    activos_vigentes = []
    for med in medicamentos:
        if med.fecha_inicio and ahora_col < med.fecha_inicio:
            continue
        if med.fecha_fin and ahora_col > med.fecha_fin:
            continue
        activos_vigentes.append({
            "medicamento_id":  str(med.id),
            "paciente_id":     str(med.paciente_id),
            "nombre":          med.nombre,
            "stock_actual":    med.stock_actual,
            "frecuencia_horas": med.frecuencia_horas,
            "hora_inicio":     str(med.hora_inicio),  # "HH:MM:SS"
            "fecha_inicio":    str(med.fecha_inicio) if med.fecha_inicio else None,
            "fecha_fin":       str(med.fecha_fin) if med.fecha_fin else None,
        })
    return activos_vigentes


@router.get("/internal/prediccion-agotamiento", response_model=List[PrediccionAgotamientoItem])
def prediccion_agotamiento_interno(db: Session = Depends(get_db)):
    """
    Endpoint interno para el Cron en segundo plano del Notification Service.
    Calcula cuántos días de tratamiento le quedan a cada medicamento activo
    en función de su stock actual y frecuencia de toma.
    """
    medicamentos = (
        db.query(Medicamento)
        .filter(Medicamento.activo == True, Medicamento.stock_actual > 0)
        .all()
    )

    resultados = []
    hoy = datetime.utcnow().date()

    for med in medicamentos:
        if med.frecuencia_horas <= 0:
            continue

        tomas_por_dia = 24.0 / med.frecuencia_horas
        dias_restantes = med.stock_actual / tomas_por_dia
        fecha_est = hoy + timedelta(days=int(dias_restantes))

        resultados.append(
            PrediccionAgotamientoItem(
                medicamento_id=med.id,
                paciente_id=med.paciente_id,
                nombre=med.nombre,
                stock_actual=med.stock_actual,
                frecuencia_horas=med.frecuencia_horas,
                tomas_por_dia=round(tomas_por_dia, 2),
                dias_restantes=round(dias_restantes, 1),
                fecha_estimada=fecha_est.isoformat(),
            )
        )

    return resultados


@router.get("/auditoria", response_model=List[RegistroAuditoriaResponse])
def listar_auditoria(
    limite: int = 50,
    request: Request = None,
    db: Session = Depends(get_db),
):
    """
    Retorna el log estructurado de auditoría clínica (quién tomó/recargó qué y cuándo).
    Accesible tanto por el paciente como por su cuidador.
    """
    user_id = _get_paciente_id(request)
    paciente_id = user_id

    # Si es un cuidador, buscar el paciente a cargo
    try:
        with httpx.Client(timeout=3.0) as client:
            res_auth = client.get(f"{AUTH_SERVICE_URL}/auth/internal/paciente-de/{user_id}")
            if res_auth.status_code == 200:
                paciente_id = res_auth.json().get("paciente_id")
    except Exception:
        pass

    logs = (
        db.query(RegistroAuditoria)
        .filter(RegistroAuditoria.paciente_id == paciente_id)
        .order_by(RegistroAuditoria.fecha_hora.desc())
        .limit(limite)
        .all()
    )
    return logs



@router.get("/stock/alertas", response_model=List[MedicamentoResponse])
def alertas_stock(request: Request, db: Session = Depends(get_db)):
    """
    Retorna la lista de medicamentos activos del paciente cuyo stock_actual
    es menor o igual a su stock_minimo_alerta.
    """
    paciente_id = _get_paciente_id(request)
    alertas = (
        db.query(Medicamento)
        .filter(
            Medicamento.paciente_id == paciente_id,
            Medicamento.activo == True,
            Medicamento.stock_actual <= Medicamento.stock_minimo_alerta,
        )
        .all()
    )
    return alertas


@router.get("/cuidador/resumen-paciente", response_model=ResumenCuidadorResponse)
def resumen_paciente_para_cuidador(request: Request, db: Session = Depends(get_db)):
    """
    Permite a un cuidador autenticado consultar el estado general de su paciente asignado:
    medicamentos activos, stock de cada uno, alertas de stock, tomas de hoy y próximo medicamento.
    """
    cuidador_id = request.headers.get("X-User-Id") or "d2802caa-7b8c-4145-9920-6893f8adecd0"

    paciente_nombre = None
    paciente_email = None
    # 1. Consultar a Auth Service cuál es el paciente vinculado a este cuidador
    try:
        with httpx.Client(timeout=5.0) as client:
            res_auth = client.get(f"{AUTH_SERVICE_URL}/auth/internal/paciente-de/{cuidador_id}")
            if res_auth.status_code != 200:
                raise HTTPException(status_code=404, detail="No tienes ningún paciente vinculado")
            auth_json = res_auth.json()
            paciente_id = auth_json.get("paciente_id")
            paciente_nombre = auth_json.get("paciente_nombre")
            paciente_email = auth_json.get("paciente_email")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error consultando servicio de autenticación: {e}")

    # 2. Medicamentos activos y alertas de stock
    medicamentos = (
        db.query(Medicamento)
        .filter(Medicamento.paciente_id == paciente_id, Medicamento.activo == True)
        .all()
    )
    alertas = [m for m in medicamentos if m.stock_actual <= m.stock_minimo_alerta]

    # 3. Tomas del día de hoy
    hoy_colombia = datetime.now(ZoneInfo("America/Bogota")).date()
    inicio_colombia = datetime.combine(hoy_colombia, time.min).replace(
        tzinfo=ZoneInfo("America/Bogota")
    )
    fin_colombia = datetime.combine(
        hoy_colombia + timedelta(days=1), time.min
    ).replace(tzinfo=ZoneInfo("America/Bogota"))
    hoy_inicio = inicio_colombia.astimezone(timezone.utc).replace(tzinfo=None)
    hoy_fin = fin_colombia.astimezone(timezone.utc).replace(tzinfo=None)
    tomas_raw = (
        db.query(Toma)
        .filter(
            Toma.paciente_id == paciente_id,
            Toma.fecha_hora_programada >= hoy_inicio,
            Toma.fecha_hora_programada < hoy_fin,
        )
        .order_by(Toma.fecha_hora_programada.asc())
        .all()
    )
    total_tomadas_hoy = sum(1 for t in tomas_raw if t.estado == EstadoToma.tomado)

    med_map = {m.id: m for m in medicamentos}
    tomas_hoy = []
    for t in tomas_raw:
        m = med_map.get(t.medicamento_id)
        tomas_hoy.append(TomaResponse(
            id=t.id,
            medicamento_id=t.medicamento_id,
            paciente_id=t.paciente_id,
            medicamento_nombre=m.nombre if m else "Medicamento",
            medicamento_dosis=m.dosis if m else None,
            fecha_hora_programada=t.fecha_hora_programada,
            estado=t.estado,
            fecha_hora_confirmacion=t.fecha_hora_confirmacion,
            created_at=t.created_at,
        ))

    # 4. Próximo medicamento a tomar
    proximo_data = None
    mejor = None
    mejor_tiempo = None
    for med in medicamentos:
        if med.stock_actual <= 0:
            continue
        proxima = calcular_proxima_toma(
            med.hora_inicio,
            med.frecuencia_horas,
            med.fecha_inicio,
            med.fecha_fin,
        )
        if proxima is None:
            continue
        if mejor_tiempo is None or proxima < mejor_tiempo:
            mejor_tiempo = proxima
            mejor = med
    if mejor:
        proximo_data = {
            "medicamento_id": str(mejor.id),
            "nombre": mejor.nombre,
            "dosis": mejor.dosis,
            "proxima_toma": mejor_tiempo.isoformat(),
            "hora_formateada": mejor_tiempo.strftime("%I:%M %p"),
        }

    return ResumenCuidadorResponse(
        paciente_id=UUID(paciente_id),
        paciente_nombre=paciente_nombre,
        paciente_email=paciente_email,
        total_medicamentos_activos=len(medicamentos),
        medicamentos=medicamentos,
        alertas_stock=alertas,
        tomas_hoy=tomas_hoy,
        total_tomas_hoy=len(tomas_hoy),
        total_tomadas_hoy=total_tomadas_hoy,
        proximo_medicamento=proximo_data,
    )


@router.get("/reporte-adherencia/pdf")
def descargar_reporte_adherencia_pdf(
    dias: int = 30,
    request: Request = None,
    db: Session = Depends(get_db),
):
    """
    Genera y descarga un reporte médico formal de adherencia y cumplimiento en formato PDF.
    Puede ser solicitado por el paciente o por su cuidador.
    """
    user_id = _get_paciente_id(request)
    paciente_id = user_id

    # Verificar si quien lo pide es un cuidador
    try:
        with httpx.Client(timeout=3.0) as client:
            res_auth = client.get(f"{AUTH_SERVICE_URL}/auth/internal/paciente-de/{user_id}")
            if res_auth.status_code == 200:
                paciente_id = res_auth.json().get("paciente_id")
    except Exception:
        pass

    # Consultar zona horaria del paciente
    zona_horaria_str = "America/Bogota"
    try:
        with httpx.Client(timeout=3.0) as client:
            res_tz = client.get(f"{AUTH_SERVICE_URL}/auth/internal/zona-horaria/{paciente_id}")
            if res_tz.status_code == 200:
                zona_horaria_str = res_tz.json().get("zona_horaria", "America/Bogota")
    except Exception:
        pass

    try:
        from zoneinfo import ZoneInfo
        tz_local = ZoneInfo(zona_horaria_str)
    except Exception:
        tz_local = None

    def _formatear_fecha_local(dt: Optional[datetime]) -> str:
        if not dt:
            return "-"
        if isinstance(dt, str):
            dt = datetime.fromisoformat(dt.replace("Z", "+00:00"))
        if tz_local:
            # Si el datetime en DB es ingenuo (naive), asumimos UTC
            if dt.tzinfo is None:
                dt_utc = dt.replace(tzinfo=ZoneInfo("UTC"))
            else:
                dt_utc = dt
            return dt_utc.astimezone(tz_local).strftime("%Y-%m-%d %I:%M %p")
        return dt.strftime("%Y-%m-%d %H:%M")

    # Fecha actual de emisión en hora local
    if tz_local:
        fecha_emision_str = datetime.now(tz_local).strftime("%Y-%m-%d %I:%M %p")
    else:
        fecha_emision_str = datetime.utcnow().strftime("%Y-%m-%d %H:%M")

    # Consultar tomas del periodo
    fecha_limite = datetime.utcnow() - timedelta(days=dias)
    tomas = (
        db.query(Toma)
        .filter(
            Toma.paciente_id == paciente_id,
            Toma.fecha_hora_programada >= fecha_limite,
        )
        .order_by(Toma.fecha_hora_programada.desc())
        .all()
    )

    medicamentos = (
        db.query(Medicamento)
        .filter(Medicamento.paciente_id == paciente_id)
        .all()
    )
    med_map = {str(m.id): m.nombre for m in medicamentos}

    # Consultar estados de ánimo desde health-service
    animos_reportados = []
    try:
        with httpx.Client(timeout=3.0) as client:
            res_health = client.get(
                f"{HEALTH_SERVICE_URL}/health/historial?dias={dias}",
                headers={"X-User-Id": str(paciente_id)},
            )
            if res_health.status_code == 200:
                h_data = res_health.json()
                animos_reportados = h_data.get("animos", [])
    except httpx.HTTPError as error:
        logger.warning("No se pudo consultar el historial de ánimo para el reporte: %s", error)

    total_tomas = len(tomas)
    total_tomadas = sum(1 for t in tomas if t.estado == EstadoToma.tomado)
    total_omitidas = sum(1 for t in tomas if t.estado == EstadoToma.omitido)
    total_pendientes = sum(1 for t in tomas if t.estado == EstadoToma.pendiente)

    porcentaje_adherencia = round((total_tomadas / total_tomas * 100), 1) if total_tomas > 0 else 100.0

    # Generación de PDF con ReportLab
    from reportlab.lib.pagesizes import letter
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=40,
        leftMargin=40,
        topMargin=40,
        bottomMargin=40,
    )
    story = []
    styles = getSampleStyleSheet()

    # Estilos
    titulo_style = ParagraphStyle(
        "TituloReporte",
        parent=styles["Heading1"],
        fontSize=20,
        leading=24,
        textColor=colors.HexColor("#0D47A1"),
        spaceAfter=6,
    )
    subtitulo_style = ParagraphStyle(
        "SubtituloReporte",
        parent=styles["Normal"],
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#555555"),
        spaceAfter=15,
    )
    seccion_style = ParagraphStyle(
        "Seccion",
        parent=styles["Heading2"],
        fontSize=14,
        leading=18,
        textColor=colors.HexColor("#1976D2"),
        spaceBefore=12,
        spaceAfter=8,
    )

    # Encabezado
    story.append(Paragraph("NotiFarma - Reporte de adherencia al tratamiento", titulo_style))
    story.append(Paragraph(
        f"Período evaluado: últimos {dias} días | Emisión ({zona_horaria_str}): "
        f"{fecha_emision_str}<br/>Resumen informativo basado en los registros de la aplicación; no reemplaza una valoración profesional.",
        subtitulo_style,
    ))
    story.append(Spacer(1, 10))

    # Resumen Ejecutivo
    story.append(Paragraph("Resumen de cumplimiento", seccion_style))
    nivel_cumplimiento = "EXCELENTE" if porcentaje_adherencia >= 85 else ("ACEPTABLE" if porcentaje_adherencia >= 70 else "EN RIESGO")
    color_adherencia = colors.HexColor("#2E7D32") if porcentaje_adherencia >= 85 else (colors.HexColor("#F57C00") if porcentaje_adherencia >= 70 else colors.HexColor("#C62828"))

    resumen_data = [
        ["Total Tomas Registradas", str(total_tomas), "Tomas Cumplidas (Tomadas)", str(total_tomadas)],
        ["Tomas Omitidas", str(total_omitidas), "Tomas Sin Confirmar", str(total_pendientes)],
        ["Porcentaje de Adherencia", f"{porcentaje_adherencia}%", "Diagnóstico de Adherencia", nivel_cumplimiento],
    ]
    t_resumen = Table(resumen_data, colWidths=[140, 100, 150, 110])
    t_resumen.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F4F6F9")),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CFD8DC")),
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('ALIGN', (1, 0), (1, -1), 'CENTER'),
        ('ALIGN', (3, 0), (3, -1), 'CENTER'),
        ('FONTNAME', (0, 2), (-1, 2), 'Helvetica-Bold'),
        ('TEXTCOLOR', (1, 2), (1, 2), color_adherencia),
        ('TEXTCOLOR', (3, 2), (3, 2), color_adherencia),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(t_resumen)
    story.append(Spacer(1, 15))

    # Medicamentos Activos y Stock
    from reportlab.platypus import Paragraph
    from xml.sax.saxutils import escape

    story.append(Paragraph("Tratamiento actual e indicaciones", seccion_style))
    celda_style = ParagraphStyle(
        "CeldaTratamiento",
        parent=styles["BodyText"],
        fontSize=7,
        leading=8,
    )
    med_table_data = [["Medicamento", "Dosis", "Frecuencia", "Hora", "Stock", "Estado", "Indicaciones"]]
    for m in medicamentos:
        if m.activo:
            alerta_txt = "ALERTA BAJO" if m.stock_actual <= m.stock_minimo_alerta else "OK"
            med_table_data.append([
                Paragraph(escape(m.nombre), celda_style),
                Paragraph(escape(m.dosis or "N/A"), celda_style),
                f"Cada {m.frecuencia_horas}h",
                str(m.hora_inicio),
                str(m.stock_actual),
                alerta_txt,
                Paragraph(escape(m.indicaciones or "-"), celda_style),
            ])
    if len(med_table_data) == 1:
        med_table_data.append(["Sin medicamentos registrados", "-", "-", "-", "-", "-", "-"])

    t_meds = Table(med_table_data, colWidths=[105, 55, 55, 48, 48, 58, 145])
    t_meds.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1976D2")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 8),
        ('FONTSIZE', (0, 1), (-1, -1), 7),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CFD8DC")),
        ('ALIGN', (1, 0), (-1, -1), 'CENTER'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
    ]))
    story.append(t_meds)
    story.append(Spacer(1, 15))

    # Últimas Tomas Registradas
    story.append(Paragraph("Tomas recientes (hasta 25 registros)", seccion_style))
    tomas_table_data = [["Medicamento", "Fecha y Hora Programada", "Estado", "Confirmado En"]]
    for t in tomas[:25]:
        nom = med_map.get(str(t.medicamento_id), "Medicamento")
        conf_txt = _formatear_fecha_local(t.fecha_hora_confirmacion)
        tomas_table_data.append([
            nom,
            _formatear_fecha_local(t.fecha_hora_programada),
            t.estado.value.upper(),
            conf_txt,
        ])
    if len(tomas_table_data) == 1:
        tomas_table_data.append(["No hay tomas registradas en este período", "-", "-", "-"])

    t_tomas = Table(tomas_table_data, colWidths=[150, 130, 80, 140])
    t_tomas.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#455A64")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CFD8DC")),
        ('ALIGN', (1, 0), (-1, -1), 'CENTER'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
    ]))
    story.append(t_tomas)
    story.append(Spacer(1, 15))

    story.append(Paragraph("Estados de ánimo registrados", seccion_style))
    if animos_reportados:
        animos_table_data = [["Fecha y hora", "Estado registrado"]]
        for animo in animos_reportados[:25]:
            fecha = _formatear_fecha_local(animo.get("fecha_hora"))
            valor = animo.get("animo") or "-"
            animos_table_data.append([fecha, str(valor).replace("_", " ").capitalize()])

        t_animos = Table(animos_table_data, colWidths=[180, 352])
        t_animos.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#00695C")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CFD8DC")),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
        ]))
        story.append(t_animos)
    else:
        story.append(Paragraph("No hay estados de ánimo registrados durante este período.", subtitulo_style))

    # Construir PDF
    doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()

    headers = {
        "Content-Disposition": f"attachment; filename=reporte_adherencia_{paciente_id}.pdf"
    }
    return Response(content=pdf_bytes, media_type="application/pdf", headers=headers)


# ─── CRUD principal ───────────────────────────────────────────────────────────

@router.post("", response_model=MedicamentoResponse, status_code=201)
def crear_medicamento(
    datos: MedicamentoCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    """Crea un medicamento para el paciente autenticado vía X-User-Id."""
    paciente_id, es_cuidador, user_id = _resolver_paciente_y_rol(request)
    nuevo = Medicamento(
        paciente_id=paciente_id,
        nombre=datos.nombre,
        dosis=datos.dosis,
        indicaciones=datos.indicaciones,
        frecuencia_horas=datos.frecuencia_horas,
        hora_inicio=datos.hora_inicio,
        fecha_inicio=datos.fecha_inicio,
        fecha_fin=datos.fecha_fin,
        stock_actual=datos.stock_actual or 0,
        stock_minimo_alerta=datos.stock_minimo_alerta if datos.stock_minimo_alerta is not None else 5,
    )
    db.add(nuevo)

    autor = "Cuidador" if es_cuidador else "Paciente"
    db.add(RegistroAuditoria(
        paciente_id=UUID(paciente_id),
        usuario_id=UUID(user_id),
        accion="CREAR_MEDICAMENTO",
        detalle=f"Medicamento '{nuevo.nombre}' ({nuevo.dosis or 'sin dosis'}) registrado por {autor}. Frecuencia: c/{nuevo.frecuencia_horas}h.",
        fecha_hora=datetime.utcnow()
    ))

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
    paciente_id, es_cuidador, user_id = _resolver_paciente_y_rol(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")

    cambios = []
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(med, campo, valor)
        cambios.append(f"{campo}={valor}")

    med.updated_at = datetime.utcnow()

    autor = "Cuidador" if es_cuidador else "Paciente"
    db.add(RegistroAuditoria(
        paciente_id=UUID(paciente_id),
        usuario_id=UUID(user_id),
        accion="EDITAR_MEDICAMENTO",
        detalle=f"Medicamento '{med.nombre}' modificado por {autor}. Cambios: {', '.join(cambios)}.",
        fecha_hora=datetime.utcnow()
    ))

    db.commit()
    db.refresh(med)
    return med


@router.delete("/{med_id}")
def eliminar_medicamento(med_id: UUID, request: Request, db: Session = Depends(get_db)):
    """Marca el medicamento como inactivo (soft delete — conserva el historial)."""
    paciente_id, es_cuidador, user_id = _resolver_paciente_y_rol(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    med.activo     = False
    med.updated_at = datetime.utcnow()

    autor = "Cuidador" if es_cuidador else "Paciente"
    db.add(RegistroAuditoria(
        paciente_id=UUID(paciente_id),
        usuario_id=UUID(user_id),
        accion="ELIMINAR_MEDICAMENTO",
        detalle=f"Medicamento '{med.nombre}' desactivado por {autor}.",
        fecha_hora=datetime.utcnow()
    ))

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
    La dosis se asocia a la ocurrencia más reciente del horario configurado.
    Si el estado es 'tomado':
      - Registra fecha_hora_confirmacion automáticamente.
      - Descuenta 1 unidad de stock_actual (si es > 0).
      - Si stock_actual <= stock_minimo_alerta, dispara alerta a Notification Service
        para notificar tanto al paciente como a su cuidador.
    """
    paciente_id, _, user_id = _resolver_paciente_y_rol(request)
    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).with_for_update().first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")

    ahora_local = datetime.now(ZoneInfo("America/Bogota")).replace(tzinfo=None)
    if med.fecha_inicio and ahora_local.date() < med.fecha_inicio:
        raise HTTPException(status_code=409, detail="El tratamiento aún no ha comenzado.")
    if med.fecha_fin and ahora_local.date() > med.fecha_fin:
        raise HTTPException(status_code=409, detail="El tratamiento ya finalizó.")

    fecha_ancla = med.fecha_inicio or ahora_local.date()
    toma_ancla = datetime.combine(fecha_ancla, med.hora_inicio)
    if med.fecha_inicio is None and toma_ancla > ahora_local:
        toma_ancla -= timedelta(days=1)
    if toma_ancla > ahora_local:
        raise HTTPException(status_code=409, detail="La hora de esta toma aún no llega.")

    frecuencia = max(med.frecuencia_horas, 1)
    ciclos_transcurridos = int((ahora_local - toma_ancla).total_seconds() // (frecuencia * 3600))
    toma_programada_local = toma_ancla + timedelta(hours=ciclos_transcurridos * frecuencia)
    toma_programada_utc = toma_programada_local.replace(
        tzinfo=ZoneInfo("America/Bogota")
    ).astimezone(ZoneInfo("UTC")).replace(tzinfo=None)

    # Una sola respuesta por dosis programada; el bloqueo de la fila evita carreras
    # entre solicitudes simultáneas desde más de un dispositivo.
    toma_existente = (
        db.query(Toma)
        .filter(
            Toma.medicamento_id == med_id,
            Toma.paciente_id == paciente_id,
            Toma.fecha_hora_programada == toma_programada_utc,
        )
        .first()
    )
    if toma_existente:
        if toma_existente.estado == EstadoToma.tomado:
            return toma_existente
        if datos.estado == EstadoToma.pendiente:
            return toma_existente
        if (
            toma_existente.estado == EstadoToma.omitido
            and datos.estado != EstadoToma.tomado
        ):
            return toma_existente

    if datos.estado == EstadoToma.tomado and med.stock_actual <= 0:
        raise HTTPException(
            status_code=400,
            detail=f"No hay stock suficiente para '{med.nombre}'. Recarga el medicamento antes de registrar la toma."
        )

    fecha_hora_confirmacion = (
        datetime.utcnow() if datos.estado == EstadoToma.tomado else None
    )

    toma = toma_existente or Toma(
        medicamento_id=med_id,
        paciente_id=paciente_id,
        fecha_hora_programada=toma_programada_utc,
    )
    toma.estado = datos.estado
    toma.fecha_hora_confirmacion = fecha_hora_confirmacion

    # Descuento de stock y disparo de alerta si se toma
    if datos.estado == EstadoToma.tomado:
        if med.stock_actual > 0:
            med.stock_actual -= 1
        
        if med.stock_actual <= med.stock_minimo_alerta:
            try:
                with httpx.Client(timeout=5.0) as client:
                    response = client.post(
                        f"{NOTIFICATION_SERVICE_URL}/notifications/internal/alerta-stock",
                        json={
                            "paciente_id": str(med.paciente_id),
                            "medicamento_id": str(med.id),
                            "medicamento_nombre": med.nombre,
                            "stock_actual": med.stock_actual,
                        }
                    )
                    response.raise_for_status()
            except httpx.HTTPError as error:
                logger.warning("No se pudo notificar el stock bajo de %s: %s", med.id, error)

    if toma_existente is None:
        db.add(toma)

    # Registrar evento en auditoría médica
    db.add(RegistroAuditoria(
        paciente_id=med.paciente_id,
        usuario_id=UUID(user_id),
        accion="REGISTRO_TOMA",
        detalle=f"Toma de '{med.nombre}' marcada como '{datos.estado.value}'. Stock restante: {med.stock_actual}",
        fecha_hora=datetime.utcnow()
    ))

    db.commit()
    db.refresh(toma)
    if datos.estado == EstadoToma.tomado:
        try:
            with httpx.Client(timeout=5.0) as client:
                response = client.post(
                    f"{NOTIFICATION_SERVICE_URL}/notifications/internal/cerrar-recordatorios-toma",
                    json={
                        "referencia_id": str(med.id),
                        "fecha_hora_programada": toma_programada_local.isoformat(),
                    },
                )
                response.raise_for_status()
        except httpx.HTTPError as error:
            logger.warning("No se pudieron cerrar los avisos de la toma %s: %s", toma.id, error)
    return toma


@router.patch("/{med_id}/stock", response_model=MedicamentoResponse)
def actualizar_stock(
    med_id: UUID,
    datos: StockUpdate,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Permite al paciente o al cuidador recargar o actualizar el inventario (stock)
    de un medicamento en el pastillero.
    """
    paciente_id, es_cuidador, user_id = _resolver_paciente_y_rol(request)

    med = db.query(Medicamento).filter(
        Medicamento.id == med_id,
        Medicamento.paciente_id == paciente_id,
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")

    stock_anterior = med.stock_actual
    med.stock_actual = datos.stock_actual
    if datos.stock_minimo_alerta is not None:
        med.stock_minimo_alerta = datos.stock_minimo_alerta

    med.updated_at = datetime.utcnow()

    autor = "Cuidador" if es_cuidador else "Paciente"
    diferencia = med.stock_actual - stock_anterior
    cambio_str = f"+{diferencia}" if diferencia >= 0 else f"{diferencia}"

    # Registrar evento en auditoría médica
    db.add(RegistroAuditoria(
        paciente_id=med.paciente_id,
        usuario_id=UUID(user_id),
        accion="RECARGA_STOCK",
        detalle=f"Stock de '{med.nombre}' actualizado por {autor} de {stock_anterior} a {med.stock_actual} unidades ({cambio_str}).",
        fecha_hora=datetime.utcnow()
    ))

    db.commit()
    db.refresh(med)
    return med
