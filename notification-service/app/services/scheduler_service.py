# app/services/scheduler_service.py

import os
import logging
from datetime import datetime, timedelta, time
from zoneinfo import ZoneInfo
import httpx
from apscheduler.schedulers.background import BackgroundScheduler

from app.database import SessionLocal
from app.models.notification_model import Notificacion, TipoNotificacion, EstadoNotificacion

logger = logging.getLogger("notification_scheduler")
logging.basicConfig(level=logging.INFO)

ZONA_COLOMBIA = ZoneInfo("America/Bogota")
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8000")
MEDICATION_SERVICE_URL = os.getenv("MEDICATION_SERVICE_URL", "http://medication-service:8002")
HEALTH_SERVICE_URL = os.getenv("HEALTH_SERVICE_URL", "http://health-service:8003")
CHECK_INTERVAL_MINUTES = int(os.getenv("CHECK_INTERVAL_MINUTES", "1"))

scheduler = BackgroundScheduler()


def sincronizar_notificaciones():
    """
    1. Sincroniza recordatorios de medicamentos desde Medication Service.
    2. Sincroniza recordatorios de citas médicas desde Health Service:
       - Recordatorio con 1 día de anticipación (ventana ~24 horas antes).
       - Recordatorio con 1 hora de anticipación (ventana ~1 hora antes).
    3. Revisa reintentos para notificaciones pendientes sin confirmar (>15 min).
       - Si una notificación de medicamento del paciente (es_alerta_cuidador = false)
         llega a intentos = 2 (a punto de generar el 3er intento), se consulta al
         Auth Service para verificar si tiene un cuidador vinculado. De existir,
         se genera una alerta al cuidador (es_alerta_cuidador = true).
    """
    logger.info("Ejecutando proceso de sincronización de notificaciones...")
    db = SessionLocal()
    ahora_utc = datetime.utcnow()
    ahora_col = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)

    try:
        # ──────────────────────────────────────────────────────────
        # 1. Sincronización de Medicamentos (Hora Colombia)
        # ──────────────────────────────────────────────────────────
        try:
            with httpx.Client(timeout=10.0) as client:
                res = client.get(f"{MEDICATION_SERVICE_URL}/medications/internal/horarios-activos")
                medicamentos = res.json() if res.status_code == 200 else []
        except Exception as e:
            logger.error(f"Error al conectar con medication-service ({MEDICATION_SERVICE_URL}): {e}")
            medicamentos = []

        hoy_col = ahora_col.date()
        # Ventana estricta: sólo alertar si la toma es en los próximos 5 minutos o hace máximo 2 minutos
        ventana_inicio = ahora_col - timedelta(minutes=2)
        ventana_fin = ahora_col + timedelta(minutes=5)

        for med in medicamentos:
            try:
                med_id = med["medicamento_id"]
                paciente_id = med["paciente_id"]
                nombre = med["nombre"]
                frecuencia_horas = int(med["frecuencia_horas"])
                partes = med["hora_inicio"].split(":")
                hora_t = time(int(partes[0]), int(partes[1]), int(partes[2]) if len(partes) > 2 else 0)

                # Si no tiene stock disponible (0 dosis), no generar aviso de "Hora de tomar"
                # ya que se disparan las alertas de agotamiento de stock
                stock_actual = med.get("stock_actual", 1)
                if stock_actual <= 0:
                    continue
                toma_programada = datetime.combine(hoy_col, hora_t)
                while toma_programada.date() == hoy_col:
                    if ventana_inicio <= toma_programada <= ventana_fin:
                        ya_existe = db.query(Notificacion).filter(
                            Notificacion.paciente_id == paciente_id,
                            Notificacion.destinatario_id == paciente_id,
                            Notificacion.referencia_id == med_id,
                            Notificacion.tipo == TipoNotificacion.medicamento,
                            Notificacion.fecha_hora_programada == toma_programada
                        ).first()

                        if not ya_existe:
                            nueva_notif = Notificacion(
                                paciente_id=paciente_id,
                                destinatario_id=paciente_id,
                                es_alerta_cuidador=False,
                                tipo=TipoNotificacion.medicamento,
                                referencia_id=med_id,
                                mensaje=f"Hora de tomar tu medicamento: {nombre}",
                                fecha_hora_programada=toma_programada,
                                estado=EstadoNotificacion.pendiente,
                                intentos=1,
                                fecha_hora_ultimo_intento=ahora_utc
                            )
                            db.add(nueva_notif)
                            logger.info(f"Notificación creada: med {nombre} para paciente {paciente_id}")

                    toma_programada += timedelta(hours=frecuencia_horas)
            except Exception as item_err:
                logger.error(f"Error procesando medicamento {med}: {item_err}")

        # ──────────────────────────────────────────────────────────
        # 2. Sincronización de Citas Médicas (1 día y 1 hora antes)
        # ──────────────────────────────────────────────────────────
        try:
            with httpx.Client(timeout=10.0) as client:
                res_citas = client.get(f"{HEALTH_SERVICE_URL}/health/citas/internal/activas")
                citas = res_citas.json() if res_citas.status_code == 200 else []
        except Exception as e:
            logger.error(f"Error al conectar con health-service ({HEALTH_SERVICE_URL}): {e}")
            citas = []

        for c in citas:
            try:
                cita_id = c["cita_id"]
                paciente_id = c["paciente_id"]
                especialidad = c["especialidad"]
                lugar = c.get("lugar") or "tu centro médico"
                direccion = c.get("direccion")
                sitio_str = f"{lugar} ({direccion})" if direccion else lugar
                fecha_cita = datetime.fromisoformat(c["fecha_hora"])
                estado_cita = c.get("estado", "programada")

                # Si la cita ya fue respondida (asistida o no_asistida), no generar recordatorios
                if estado_cita in ["asistida", "no_asistida"]:
                    continue

                # Comparar contra la hora local de Colombia para evitar desfases
                diferencia = fecha_cita - ahora_col
                minutos_restantes = diferencia.total_seconds() / 60.0

                # Consultar cuidador vinculado para enviar alertas a AMBOS (paciente y cuidador)
                cuidador_id = None
                try:
                    with httpx.Client(timeout=3.0) as client_auth:
                        res_auth = client_auth.get(f"{AUTH_SERVICE_URL}/auth/internal/cuidador-de/{paciente_id}")
                        if res_auth.status_code == 200:
                            cuidador_id = res_auth.json().get("cuidador_id")
                except Exception:
                    pass

                # 2.1 Alerta con 24 HORAS de anticipación: ventana 23h a 25h (1380 a 1500 min)
                if 1380 <= minutos_restantes <= 1500:
                    mensaje_24h_pac = f"Recordatorio: Mañana tienes tu cita médica de {especialidad} en {sitio_str}."
                    ya_notif_24h = db.query(Notificacion).filter(
                        Notificacion.paciente_id == paciente_id,
                        Notificacion.destinatario_id == paciente_id,
                        Notificacion.referencia_id == cita_id,
                        Notificacion.tipo == TipoNotificacion.cita,
                        Notificacion.mensaje.like("Recordatorio: Mañana%")
                    ).first()

                    if not ya_notif_24h:
                        db.add(Notificacion(
                            paciente_id=paciente_id,
                            destinatario_id=paciente_id,
                            es_alerta_cuidador=False,
                            tipo=TipoNotificacion.cita,
                            referencia_id=cita_id,
                            mensaje=mensaje_24h_pac,
                            fecha_hora_programada=ahora_col,
                            estado=EstadoNotificacion.pendiente,
                            intentos=1,
                            fecha_hora_ultimo_intento=ahora_utc
                        ))
                        # Enviar también al cuidador si está vinculado
                        if cuidador_id:
                            db.add(Notificacion(
                                paciente_id=paciente_id,
                                destinatario_id=cuidador_id,
                                es_alerta_cuidador=True,
                                tipo=TipoNotificacion.cita,
                                referencia_id=cita_id,
                                mensaje=f"Recordatorio familiar: Mañana tu familiar tiene cita médica de {especialidad} en {sitio_str}.",
                                fecha_hora_programada=ahora_col,
                                estado=EstadoNotificacion.pendiente,
                                intentos=1,
                                fecha_hora_ultimo_intento=ahora_utc
                            ))
                        logger.info(f"Notificación de 24h creada para cita de {especialidad} (paciente {paciente_id})")

                # 2.2 Alerta con 2 HORAS Y MEDIA (150 min) antes: ventana 135 a 165 minutos
                if 135 <= minutos_restantes <= 165:
                    mensaje_2h5_pac = f"Recordatorio: En 2 horas y media es tu cita de {especialidad} en {sitio_str}. Prepara tus documentos."
                    ya_notif_2h5 = db.query(Notificacion).filter(
                        Notificacion.paciente_id == paciente_id,
                        Notificacion.destinatario_id == paciente_id,
                        Notificacion.referencia_id == cita_id,
                        Notificacion.tipo == TipoNotificacion.cita,
                        Notificacion.mensaje.like("Recordatorio: En 2 horas y media%")
                    ).first()

                    if not ya_notif_2h5:
                        db.add(Notificacion(
                            paciente_id=paciente_id,
                            destinatario_id=paciente_id,
                            es_alerta_cuidador=False,
                            tipo=TipoNotificacion.cita,
                            referencia_id=cita_id,
                            mensaje=mensaje_2h5_pac,
                            fecha_hora_programada=ahora_col,
                            estado=EstadoNotificacion.pendiente,
                            intentos=1,
                            fecha_hora_ultimo_intento=ahora_utc
                        ))
                        # Enviar también al cuidador si está vinculado
                        if cuidador_id:
                            db.add(Notificacion(
                                paciente_id=paciente_id,
                                destinatario_id=cuidador_id,
                                es_alerta_cuidador=True,
                                tipo=TipoNotificacion.cita,
                                referencia_id=cita_id,
                                mensaje=f"Recordatorio familiar: En 2 horas y media es la cita de {especialidad} de tu familiar en {sitio_str}.",
                                fecha_hora_programada=ahora_col,
                                estado=EstadoNotificacion.pendiente,
                                intentos=1,
                                fecha_hora_ultimo_intento=ahora_utc
                            ))
                        logger.info(f"Notificación de 2.5h creada para cita de {especialidad} (paciente {paciente_id})")

                # 2.3 Cierre de jornada: si pasaron más de 2 horas desde la cita y sigue sin confirmar
                if minutos_restantes <= -120 and estado_cita == "programada":
                    if cuidador_id:
                        alerta_cita_perdida = db.query(Notificacion).filter(
                            Notificacion.referencia_id == cita_id,
                            Notificacion.destinatario_id == cuidador_id,
                            Notificacion.mensaje.like("%asistencia a la cita no fue confirmada%")
                        ).first()
                        if not alerta_cita_perdida:
                            db.add(Notificacion(
                                paciente_id=paciente_id,
                                destinatario_id=cuidador_id,
                                es_alerta_cuidador=True,
                                tipo=TipoNotificacion.cita,
                                referencia_id=cita_id,
                                mensaje=f"Aviso de cita médica: La asistencia a la cita de {especialidad} de tu familiar no fue confirmada.",
                                fecha_hora_programada=ahora_col,
                                estado=EstadoNotificacion.pendiente,
                                intentos=1,
                                fecha_hora_ultimo_intento=ahora_utc
                            ))
                            logger.info(f"Aviso enviado al cuidador: cita de {especialidad} sin confirmar")

            except Exception as cita_err:
                logger.error(f"Error procesando cita {c}: {cita_err}")

        # ──────────────────────────────────────────────────────────
        # 3. Reintentos y Aviso por Toma Sin Confirmar al Cuidador
        # ──────────────────────────────────────────────────────────
        # Reintento cada 5 minutos:
        # Minuto -5: Aviso anticipado (intento 1)
        # Minuto  0: Alarma de toma (intento 2)
        # Minuto +5: Segundo aviso de insistencia (intento 3)
        # Minuto +10: A los 10 min de la toma programada, se cierra la notificación activa
        #             del paciente como 'sin_confirmar' y se genera la alerta al cuidador.
        umbral_reintento = ahora_utc - timedelta(minutes=5)
        pendientes_a_reintentar = db.query(Notificacion).filter(
            Notificacion.estado == EstadoNotificacion.pendiente,
            Notificacion.fecha_hora_ultimo_intento <= umbral_reintento,
            Notificacion.es_alerta_cuidador == False  # Las alertas al cuidador no reintentan
        ).all()

        for notif in pendientes_a_reintentar:
            if notif.tipo == TipoNotificacion.medicamento:
                # Si han pasado 10 o más minutos desde la hora programada de la toma:
                minutos_desde_programada = (ahora_col - notif.fecha_hora_programada).total_seconds() / 60.0
                if minutos_desde_programada >= 10.0 or notif.intentos >= 3:
                    try:
                        with httpx.Client(timeout=10.0) as client:
                            res_auth = client.get(f"{AUTH_SERVICE_URL}/auth/internal/cuidador-de/{notif.paciente_id}")
                            if res_auth.status_code == 200:
                                data_auth = res_auth.json()
                                cuidador_id = data_auth.get("cuidador_id")
                                if cuidador_id:
                                    alerta_existente = db.query(Notificacion).filter(
                                        Notificacion.referencia_id == notif.referencia_id,
                                        Notificacion.destinatario_id == cuidador_id,
                                        Notificacion.es_alerta_cuidador == True,
                                        Notificacion.fecha_hora_programada == notif.fecha_hora_programada
                                    ).first()

                                    if not alerta_existente:
                                        nombre_med = notif.mensaje.replace("Hora de tomar tu medicamento: ", "")
                                        mensaje_cuidador = f"Tu familiar aún no ha confirmado la toma de {nombre_med} (programada a las {notif.fecha_hora_programada.strftime('%I:%M %p')})."
                                        alerta_cuidador = Notificacion(
                                            paciente_id=notif.paciente_id,
                                            destinatario_id=cuidador_id,
                                            es_alerta_cuidador=True,
                                            tipo=TipoNotificacion.medicamento,
                                            referencia_id=notif.referencia_id,
                                            mensaje=mensaje_cuidador,
                                            fecha_hora_programada=notif.fecha_hora_programada,
                                            estado=EstadoNotificacion.pendiente,
                                            intentos=1,
                                            fecha_hora_ultimo_intento=ahora_utc
                                        )
                                        db.add(alerta_cuidador)
                                        logger.info(f"Alerta enviada al cuidador {cuidador_id}: toma sin confirmar para paciente {notif.paciente_id}")
                    except Exception as esc_err:
                        logger.error(f"Error al enviar alerta al cuidador para paciente {notif.paciente_id}: {esc_err}")

                    # Cerrar el aviso activo del paciente para no dejarlo colgado
                    notif.estado = EstadoNotificacion.entregada

            notif.intentos += 1
            notif.fecha_hora_ultimo_intento = ahora_utc

        db.commit()

        # ──────────────────────────────────────────────────────────
        # 4. Evaluación Predictiva de Agotamiento de Stock (Proactivo)
        # ──────────────────────────────────────────────────────────
        evaluar_agotamiento_preventivo_stock(db, ahora)

    except Exception as general_err:
        logger.error(f"Error general en sincronizar_notificaciones: {general_err}")
        db.rollback()
    finally:
        db.close()


def evaluar_agotamiento_preventivo_stock(db, ahora):
    """
    Cron / Tarea proactiva:
    Consulta Medication Service para saber a qué medicamentos les quedan <= 3 días de pastillas.
    Si detecta riesgo de desabastecimiento, genera una notificación preventiva tanto al paciente
    como a su cuidador (evitando duplicar si ya se envió en las últimas 24 horas).
    """
    try:
        with httpx.Client(timeout=10.0) as client:
            res_pred = client.get(f"{MEDICATION_SERVICE_URL}/medications/internal/prediccion-agotamiento")
            medicamentos = res_pred.json() if res_pred.status_code == 200 else []
    except Exception as e:
        logger.error(f"Error al conectar con predicción de stock ({MEDICATION_SERVICE_URL}): {e}")
        return

    umbral_24h = ahora - timedelta(hours=24)

    for item in medicamentos:
        try:
            dias_restantes = item["dias_restantes"]
            if dias_restantes <= 3.0 and item["stock_actual"] > 0:
                paciente_id = item["paciente_id"]
                med_id = item["medicamento_id"]
                nombre_med = item["nombre"]
                fecha_est = item["fecha_estimada"]

                # Verificar si ya se envió alerta preventiva recientemente (< 24 horas)
                ya_notificado = db.query(Notificacion).filter(
                    Notificacion.referencia_id == med_id,
                    Notificacion.paciente_id == paciente_id,
                    Notificacion.mensaje.like("Aviso preventivo:%"),
                    Notificacion.created_at >= umbral_24h
                ).first()

                if not ya_notificado:
                    # 1. Notificación preventiva al PACIENTE
                    msg_paciente = (
                        f"Aviso preventivo: Al ritmo actual, tus pastillas de {nombre_med} se agotarán en "
                        f"{dias_restantes} días (aprox. {fecha_est}). Recuerda pedir tu fórmula médica a tiempo."
                    )
                    db.add(Notificacion(
                        paciente_id=paciente_id,
                        destinatario_id=paciente_id,
                        es_alerta_cuidador=False,
                        tipo=TipoNotificacion.medicamento,
                        referencia_id=med_id,
                        mensaje=msg_paciente,
                        fecha_hora_programada=ahora,
                        estado=EstadoNotificacion.pendiente,
                        intentos=1,
                        fecha_hora_ultimo_intento=ahora
                    ))

                    # 2. Notificación preventiva al CUIDADOR (si existe)
                    try:
                        with httpx.Client(timeout=5.0) as client_auth:
                            res_auth = client_auth.get(f"{AUTH_SERVICE_URL}/auth/internal/cuidador-de/{paciente_id}")
                            if res_auth.status_code == 200:
                                cuidador_id = res_auth.json().get("cuidador_id")
                                if cuidador_id:
                                    msg_cuidador = (
                                        f"Aviso preventivo: Al ritmo actual, las pastillas de {nombre_med} de tu familiar se agotarán en "
                                        f"{dias_restantes} días (aprox. {fecha_est})."
                                    )
                                    db.add(Notificacion(
                                        paciente_id=paciente_id,
                                        destinatario_id=cuidador_id,
                                        es_alerta_cuidador=True,
                                        tipo=TipoNotificacion.medicamento,
                                        referencia_id=med_id,
                                        mensaje=msg_cuidador,
                                        fecha_hora_programada=ahora,
                                        estado=EstadoNotificacion.pendiente,
                                        intentos=1,
                                        fecha_hora_ultimo_intento=ahora
                                    ))
                    except Exception as err_cuid:
                        logger.error(f"Error consultando cuidador para alerta preventiva de {nombre_med}: {err_cuid}")

                    db.commit()
                    logger.info(f"Alerta preventiva de agotamiento creada para {nombre_med} (Paciente {paciente_id})")
        except Exception as item_err:
            logger.error(f"Error procesando predicción para item {item}: {item_err}")


def iniciar_scheduler():
    """Inicia el scheduler en background cada CHECK_INTERVAL_MINUTES minutos."""
    if not scheduler.running:
        scheduler.add_job(
            sincronizar_notificaciones,
            "interval",
            minutes=CHECK_INTERVAL_MINUTES,
            id="job_sync_notificaciones",
            replace_existing=True,
            next_run_time=datetime.utcnow() + timedelta(seconds=10)  # Primera ejecución a los 10 segundos
        )
        scheduler.start()
        logger.info(f"APScheduler iniciado. Intervalo: cada {CHECK_INTERVAL_MINUTES} minutos.")


def detener_scheduler():
    """Detiene el scheduler limpiamente al cerrar la app."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("APScheduler detenido.")

