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

from typing import List


MENSAJE_DEFAULT = "Recuerda registrar como te sientes durante el dia para llevar un mejor seguimiento de tu salud."

# Lista ordenada de reglas: se evaluan de arriba hacia abajo y se retorna el primer mensaje que aplique.
REGLAS = [
    {
        "condicion": lambda animo, sintomas: animo == "mal" and len(sintomas) > 0,
        "mensaje": (
            "Gracias por contarnos como te sientes. "
            "Si el malestar te preocupa o empeora, considera comunicarte con un profesional de salud."
        ),
    },
    {
        "condicion": lambda animo, sintomas: animo == "mal" and len(sintomas) == 0,
        "mensaje": (
            "Parece que no estas pasando un buen momento. "
            "Descansa lo que puedas y no dudes en buscar apoyo si lo necesitas."
        ),
    },
    {
        "condicion": lambda animo, sintomas: animo == "regular" and len(sintomas) > 0,
        "mensaje": (
            "Tomatelo con calma hoy. "
            "Si los sintomas persisten o se intensifican, es buena idea consultar a tu medico."
        ),
    },
    {
        "condicion": lambda animo, sintomas: animo == "regular",
        "mensaje": (
            "Tomatete un momento para descansar y presta atencion a como evoluciona tu estado durante el dia."
        ),
    },
    {
        "condicion": lambda animo, sintomas: animo in ("bien", "muy_bien") and len(sintomas) == 0,
        "mensaje": (
            "Parece que tienes un buen dia. "
            "Continua con tu rutina de cuidado y registra cualquier cambio que notes."
        ),
    },
    {
        "condicion": lambda animo, sintomas: animo in ("bien", "muy_bien") and len(sintomas) > 0,
        "mensaje": (
            "Tu animo es positivo, aunque tienes algunos sintomas reportados. "
            "Mantenlos en seguimiento por si cambian durante el dia."
        ),
    },
]


def evaluar_bienestar(animo: str | None, sintomas: List) -> str:
    """
    Evalua las reglas en orden y retorna el mensaje del primer caso que aplique.
    Si no hay datos de animo para hoy, retorna el mensaje por defecto.
    """
    if animo is None:
        return MENSAJE_DEFAULT

    for regla in REGLAS:
        if regla["condicion"](animo, sintomas):
            return regla["mensaje"]

    return MENSAJE_DEFAULT
