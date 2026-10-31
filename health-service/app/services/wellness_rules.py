# app/services/wellness_rules.py
#
# Motor de reglas de bienestar.
# Evalua el estado de animo y sintomas del dia para devolver un mensaje de autocuidado.
#
# RESTRICCION DEL PROYECTO:
#   - Este modulo NO diagnostica enfermedades.
#   - NO sugiere medicamentos ni dosis.
#   - Solo ofrece consejos generales de bienestar y autocuidado.
#   - Cuando corresponde, sugiere consultar a un profesional de salud.
#   - Es una lista de reglas simples — no usa modelos externos ni servicios de terceros.

from typing import List, Optional


MENSAJE_DEFAULT = "Recuerda registrar como te sientes durante el dia para llevar un mejor seguimiento de tu salud."

# Mensajes de bienestar personalizados segun el estado de animo del paciente
MENSAJES_POR_ANIMO = {
    "mal": (
        "Parece que no estas pasando un buen momento hoy. "
        "Descansa lo que puedas, toma tus medicamentos a tiempo y no dudes en buscar apoyo si lo necesitas."
    ),
    "regular": (
        "Tomatelo con calma hoy. "
        "Descansa un momento y presta atencion a como evoluciona tu bienestar durante el dia."
    ),
    "bien": (
        "Nos alegra saber que te sientes bien. "
        "Continua con tu rutina de cuidado y toma tus medicamentos segun lo programado."
    ),
    "muy_bien": (
        "¡Excelente dia! Sigue manteniendo habitos saludables y cumpliendo tu tratamiento."
    ),
}


def evaluar_bienestar(animo: Optional[str], sintomas: Optional[List] = None) -> str:
    """
    Evalua el estado de animo y retorna el mensaje correspondiente.
    Si no hay datos de animo para hoy, retorna el mensaje por defecto.
    """
    if not animo:
        return MENSAJE_DEFAULT

    return MENSAJES_POR_ANIMO.get(animo, MENSAJE_DEFAULT)
