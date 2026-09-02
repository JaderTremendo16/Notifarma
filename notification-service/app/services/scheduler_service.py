# app/services/scheduler_service.py

import os
import logging
from datetime import datetime, timedelta, time
import httpx
from apscheduler.schedulers.background import BackgroundScheduler

from app.database import SessionLocal
from app.models.notification_model import Notificacion, TipoNotificacion, EstadoNotificacion

logger = logging.getLogger("notification_scheduler")
logging.basicConfig(level=logging.INFO)

MEDICATION_SERVICE_URL = os.getenv("MEDICATION_SERVICE_URL", "http://medication-service:8002")
HEALTH_SERVICE_URL = os.getenv("HEALTH_SERVICE_URL", "http://health-service:8003")
CHECK_INTERVAL_MINUTES = int(os.getenv("CHECK_INTERVAL_MINUTES", "5"))

scheduler = BackgroundScheduler()


def sincronizar_notificaciones():
    """
    1. Sincroniza recordatorios de medicamentos desde Medication Service.
    2. Sincroniza recordatorios de citas médicas desde Health Service:
       - Recordatorio con 1 día de anticipación (ventana ~24 horas antes).
       - Recordatorio con 1 hora de anticipación (ventana ~1 hora antes).
    3. Revisa reintentos para notificaciones pendientes sin confirmar (>15 min).
    """
    logger.info("Ejecutando proceso de sincronización de notificaciones...")
    db = SessionLocal()
    ahora = datetime.utcnow()

    try:
        # ──────────────────────────────────────────────────────────
        # 1. Sincronización de Medicamentos
        # ──────────────────────────────────────────────────────────
        try:
            with httpx.Client(timeout=10.0) as client:
                res = client.get(f"{MEDICATION_SERVICE_URL}/medications/internal/horarios-activos")
                medicamentos = res.json() if res.status_code == 200 else []
        except Exception as e:
            logger.error(f"Error al conectar con medication-service ({MEDICATION_SERVICE_URL}): {e}")
            medicamentos = []

        hoy = ahora.date()
        ventana_inicio = ahora - timedelta(minutes=5)
        ventana_fin = ahora + timedelta(minutes=10)

        for med in medicamentos:
            try:
                med_id = med["medicamento_id"]
                paciente_id = med["paciente_id"]
                nombre = med["nombre"]
                frecuencia_horas = int(med["frecuencia_horas"])
                partes = med["hora_inicio"].split(":")
                hora_t = time(int(partes[0]), int(partes[1]), int(partes[2]) if len(partes) > 2 else 0)

                toma_programada = datetime.combine(hoy, hora_t)
                while toma_programada.date() == hoy:
                    if ventana_inicio <= toma_programada <= ventana_fin:
                        ya_existe = db.query(Notificacion).filter(
                            Notificacion.paciente_id == paciente_id,
                            Notificacion.referencia_id == med_id,
                            Notificacion.tipo == TipoNotificacion.medicamento,
                            Notificacion.fecha_hora_programada == toma_programada
                        ).first()

                        if not ya_existe:
                            nueva_notif = Notificacion(
                                paciente_id=paciente_id,
                                tipo=TipoNotificacion.medicamento,
                                referencia_id=med_id,
                                mensaje=f"Hora de tomar tu medicamento: {nombre}",
                                fecha_hora_programada=toma_programada,
                                estado=EstadoNotificacion.pendiente,
                                intentos=1,
                                fecha_hora_ultimo_intento=ahora
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
                fecha_cita = datetime.fromisoformat(c["fecha_hora"])

                diferencia = fecha_cita - ahora
                minutos_restantes = diferencia.total_seconds() / 60.0

                # 2.1 Alerta con 1 DÍA de anticipación: entre 23h y 25h antes (1380 a 1500 minutos)
                if 1380 <= minutos_restantes <= 1500:
                    mensaje_1dia = f"Recordatorio: Mañana tienes tu cita médica de {especialidad}."
                    ya_notif_1dia = db.query(Notificacion).filter(
                        Notificacion.paciente_id == paciente_id,
                        Notificacion.referencia_id == cita_id,
                        Notificacion.tipo == TipoNotificacion.cita,
                        Notificacion.mensaje.like("Recordatorio: Mañana%")
                    ).first()

                    if not ya_notif_1dia:
                        db.add(Notificacion(
                            paciente_id=paciente_id,
                            tipo=TipoNotificacion.cita,
                            referencia_id=cita_id,
                            mensaje=mensaje_1dia,
                            fecha_hora_programada=ahora,
                            estado=EstadoNotificacion.pendiente,
                            intentos=1,
                            fecha_hora_ultimo_intento=ahora
                        ))
                        logger.info(f"Notificación de 1 día creada para cita de {especialidad} (paciente {paciente_id})")

                # 2.2 Alerta con 1 HORA previa a la cita: entre 45 y 75 minutos antes
                if 45 <= minutos_restantes <= 75:
                    mensaje_1hora = f"Recordatorio: En 1 hora es tu cita de {especialidad} en {lugar}."
                    ya_notif_1hora = db.query(Notificacion).filter(
                        Notificacion.paciente_id == paciente_id,
                        Notificacion.referencia_id == cita_id,
                        Notificacion.tipo == TipoNotificacion.cita,
                        Notificacion.mensaje.like("Recordatorio: En 1 hora%")
                    ).first()

                    if not ya_notif_1hora:
                        db.add(Notificacion(
                            paciente_id=paciente_id,
                            tipo=TipoNotificacion.cita,
                            referencia_id=cita_id,
                            mensaje=mensaje_1hora,
                            fecha_hora_programada=ahora,
                            estado=EstadoNotificacion.pendiente,
                            intentos=1,
                            fecha_hora_ultimo_intento=ahora
                        ))
                        logger.info(f"Notificación de 1 hora creada para cita de {especialidad} (paciente {paciente_id})")

            except Exception as cita_err:
                logger.error(f"Error procesando cita {c}: {cita_err}")

        # ──────────────────────────────────────────────────────────
        # 3. Reintentos de notificaciones pendientes sin confirmar
        # ──────────────────────────────────────────────────────────
        umbral_reintento = ahora - timedelta(minutes=15)
        pendientes_a_reintentar = db.query(Notificacion).filter(
            Notificacion.estado == EstadoNotificacion.pendiente,
            Notificacion.fecha_hora_ultimo_intento <= umbral_reintento
        ).all()

        for notif in pendientes_a_reintentar:
            notif.intentos += 1
            notif.fecha_hora_ultimo_intento = ahora

        db.commit()

    except Exception as general_err:
        logger.error(f"Error general en sincronizar_notificaciones: {general_err}")
        db.rollback()
    finally:
        db.close()


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
