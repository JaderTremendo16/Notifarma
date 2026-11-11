# app/services/medication_service.py

from datetime import date, datetime, timedelta, time
from typing import Optional
from zoneinfo import ZoneInfo

ZONA_COLOMBIA = ZoneInfo("America/Bogota")


def calcular_proxima_toma(
    hora_inicio: time,
    frecuencia_horas: int,
    fecha_inicio: Optional[date] = None,
    fecha_fin: Optional[date] = None,
    ahora: Optional[datetime] = None,
) -> Optional[datetime]:
    """
    Dado un hora_inicio (hora local del paciente en Colombia) y frecuencia_horas,
    calcula la próxima toma programada a partir del momento actual en hora local Colombia (UTC-5).

    Ejemplo: hora_inicio=08:00, frecuencia_horas=8
      → tomas en 08:00, 16:00, 00:00, 08:00...
      Si ahora en Colombia son las 09:30 → la próxima es 16:00 (hora local Colombia).
    """
    if frecuencia_horas <= 0:
        raise ValueError("La frecuencia debe ser mayor que cero.")

    ahora_local = ahora or datetime.now(ZONA_COLOMBIA).replace(tzinfo=None)
    if ahora_local.tzinfo is not None:
        ahora_local = ahora_local.astimezone(ZONA_COLOMBIA).replace(tzinfo=None)

    inicio = fecha_inicio or ahora_local.date()
    primera_toma = datetime.combine(inicio, hora_inicio)
    if primera_toma > ahora_local:
        proxima = primera_toma
    else:
        ciclos = int(
            (ahora_local - primera_toma).total_seconds()
            // (frecuencia_horas * 3600)
        ) + 1
        proxima = primera_toma + timedelta(hours=ciclos * frecuencia_horas)

    if fecha_fin and proxima.date() > fecha_fin:
        return None
    return proxima
