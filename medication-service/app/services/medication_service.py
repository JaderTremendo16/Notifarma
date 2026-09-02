# app/services/medication_service.py

from datetime import datetime, timedelta, time


def calcular_proxima_toma(hora_inicio: time, frecuencia_horas: int) -> datetime:
    """
    Dado un hora_inicio y frecuencia_horas, calcula la próxima toma
    programada a partir del momento actual (UTC).

    Ejemplo: hora_inicio=08:00, frecuencia_horas=8
      → tomas en 08:00, 16:00, 00:00, 08:00...
      Si ahora son las 09:30 → próxima es 16:00.
    """
    ahora = datetime.utcnow()
    hoy   = ahora.date()

    # Primera toma del día actual según hora_inicio
    primera_hoy = datetime.combine(hoy, hora_inicio)

    # Avanzar ciclos hasta superar el momento actual
    proxima = primera_hoy
    while proxima <= ahora:
        proxima += timedelta(hours=frecuencia_horas)

    return proxima
