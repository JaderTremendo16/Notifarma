# app/services/medication_service.py

from datetime import datetime, timedelta, time
from zoneinfo import ZoneInfo

ZONA_COLOMBIA = ZoneInfo("America/Bogota")


def calcular_proxima_toma(hora_inicio: time, frecuencia_horas: int) -> datetime:
    """
    Dado un hora_inicio (hora local del paciente en Colombia) y frecuencia_horas,
    calcula la próxima toma programada a partir del momento actual en hora local Colombia (UTC-5).

    Ejemplo: hora_inicio=08:00, frecuencia_horas=8
      → tomas en 08:00, 16:00, 00:00, 08:00...
      Si ahora en Colombia son las 09:30 → la próxima es 16:00 (hora local Colombia).
    """
    ahora_local = datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    hoy = ahora_local.date()

    # Primera toma del día actual según hora_inicio local
    primera_hoy = datetime.combine(hoy, hora_inicio)

    # Avanzar ciclos hasta superar el momento actual local
    proxima = primera_hoy
    while proxima <= ahora_local:
        proxima += timedelta(hours=frecuencia_horas)

    return proxima
