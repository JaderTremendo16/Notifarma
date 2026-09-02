# 📋 Especificación — Medication, Health y Notification Service

> Contexto: proyecto NotiFarma (app de seguimiento de medicamentos, ODS 3 — Salud y Bienestar).
> Auth Service y API Gateway ya están construidos, probados y funcionando en Docker Compose.
> Estos 3 microservicios deben seguir EXACTAMENTE el mismo patrón arquitectónico ya validado.

## Patrón arquitectónico obligatorio (igual en los 3 servicios)

- **Stack:** Python + FastAPI + SQLAlchemy + PostgreSQL + Docker.
- **Estructura de carpetas por capas técnicas**, idéntica en los 3:
```text
nombre-service/
├── app/
│   ├── main.py
│   ├── database.py
│   ├── routers/
│   ├── models/
│   ├── schemas/
│   └── services/
├── requirements.txt
├── Dockerfile
├── .dockerignore
└── .env
```
- **Autenticación:** estos servicios NO validan JWT — el API Gateway ya lo valida y reenvía el `user_id` del paciente autenticado en el header `X-User-Id`. Cada endpoint debe leer ese header (`request.headers.get("X-User-Id")`) para saber de qué paciente se trata. NO usar `Depends(oauth2_scheme)` ni decodificar tokens en estos servicios.
- **Base de datos:** cada servicio tiene su propia base de datos separada dentro del mismo contenedor Postgres compartido (`medication_db`, `health_db`, `notification_db`), agregadas al `init.sql` existente.
- **Comunicación entre microservicios:** REST directo entre contenedores, usando el nombre del servicio en la red de Docker Compose (ej. `http://medication-service:8000`). Sin JWT en estas llamadas internas.
- **IDs:** UUID como primary key en todas las tablas (no autoincremental), igual que en Auth Service.
- **Timestamps:** todos en UTC (`datetime.utcnow`), igual que en Auth Service.
- **Cada servicio corre en su propio puerto** dentro de Docker Compose: Medication en 8002, Health en 8003, Notification en 8004 (Auth ya usa 8000, Gateway 8001).
- El API Gateway deberá extenderse para reenviar también `/medications/*`, `/health/*` y `/notifications/*` hacia estos 3 servicios (mismo patrón de proxy ya usado para `/auth/*`).

---

## 1. Medication Service (puerto 8002, base `medication_db`)

### Entidad: Medicamento
```text
- id (UUID, PK)
- paciente_id (UUID, viene del header X-User-Id, no se recibe en el body)
- nombre (string, obligatorio)
- dosis (string, ej. "500mg")
- frecuencia_horas (integer, ej. 12 = cada 12 horas)
- hora_inicio (time, ej. 08:00)
- fecha_inicio (date, opcional)
- fecha_fin (date, opcional)
- activo (boolean, default true — para "eliminar" sin borrar históricos)
- created_at, updated_at (datetime UTC)
```

### Entidad: Toma
```text
- id (UUID, PK)
- medicamento_id (UUID, FK -> Medicamento)
- paciente_id (UUID)
- fecha_hora_programada (datetime)
- estado (enum: pendiente / tomado / omitido, default pendiente)
- fecha_hora_confirmacion (datetime, nullable)
- created_at (datetime UTC)
```

### Endpoints
```text
POST   /medications                 → crear medicamento (body: nombre, dosis, frecuencia_horas, hora_inicio, fecha_inicio?, fecha_fin?)
GET    /medications                  → listar medicamentos activos del paciente (X-User-Id)
GET    /medications/proximo            → próximo medicamento a tomar según hora actual (para el Dashboard)
GET    /medications/{id}                 → detalle de un medicamento
PUT    /medications/{id}                   → editar medicamento
DELETE /medications/{id}                     → marcar como inactivo (no borrar)

POST   /medications/{id}/tomas                  → registrar una toma (body: estado)
GET    /medications/tomas/historial                → historial de cumplimiento del paciente (para pantalla Historial)
```

Endpoint interno (sin autenticación, para uso de Notification Service):
```text
GET    /medications/internal/horarios-activos    → lista de medicamentos con paciente_id y horario, para que Notification Service genere recordatorios
```

---

## 2. Health Service (puerto 8003, base `health_db`)

### Entidad: EstadoAnimo
```text
- id (UUID, PK)
- paciente_id (UUID)
- animo (enum: muy_bien / bien / regular / mal)
- fecha_hora (datetime)
- created_at (datetime UTC)
```
Múltiples registros por día permitidos (no hay restricción de uno por día).

### Entidad: Sintoma (catálogo fijo, se precarga, no la edita el usuario)
```text
- id (UUID, PK)
- nombre (string) — valores iniciales: "Dolor de cabeza", "Fatiga", "Mareo", "Náuseas", "Dolor muscular"
```

### Entidad: RegistroSintoma
```text
- id (UUID, PK)
- paciente_id (UUID)
- sintoma_id (UUID, FK -> Sintoma, nullable)
- sintoma_otro (string, nullable — se usa cuando el usuario elige "Otro" y escribe un síntoma libre)
- intensidad (enum: leve / moderada / fuerte)
- observacion (string, opcional)
- fecha_hora (datetime)
- created_at (datetime UTC)
```

### Endpoints
```text
POST   /health/mood                     → registrar estado de ánimo (body: animo)
GET    /health/mood/hoy                    → registros de ánimo de hoy del paciente

GET    /health/sintomas/catalogo               → catálogo fijo de síntomas
POST   /health/sintomas                          → registrar uno o varios síntomas (body: lista de {sintoma_id o sintoma_otro, intensidad, observacion})

GET    /health/historial                             → ánimo + síntomas de los últimos N días (query param opcional: dias, default 7)

GET    /health/recomendacion-hoy                        → mensaje de bienestar del día, calculado con motor de reglas interno
```

### Motor de reglas para `/health/recomendacion-hoy`
- Consulta el último `EstadoAnimo` de hoy y los `RegistroSintoma` de hoy del paciente (mismo servicio, sin llamar a otros microservicios).
- Implementar como una LISTA ORDENADA de reglas (condición → mensaje), evaluada de arriba hacia abajo, NO como if/elif anidados. Ejemplo de estructura:
```python
REGLAS = [
    {"condicion": lambda animo, sintomas: animo == "mal" and len(sintomas) > 0,
     "mensaje": "Gracias por contarnos cómo te sientes. Si el malestar te preocupa o empeora, considera comunicarte con un profesional de salud."},
    {"condicion": lambda animo, sintomas: animo == "regular",
     "mensaje": "Tómate un momento para descansar y presta atención a cómo evoluciona tu estado durante el día."},
    {"condicion": lambda animo, sintomas: animo in ("bien", "muy_bien") and len(sintomas) == 0,
     "mensaje": "Parece que tienes un buen día. Continúa con tu rutina de cuidado y registra cualquier cambio que notes."},
]
# mensaje por defecto si ninguna regla matchea: "Recuerda registrar cómo te sientes durante el día."
```
- **IMPORTANTE — restricción explícita del proyecto:** esta funcionalidad NO debe diagnosticar, NO debe sugerir enfermedades, NO debe recomendar medicamentos ni dosis. Solo consejos generales de bienestar/autocuidado, y cuando corresponda, sugerir consultar a un profesional. NO llamar a esta funcionalidad "IA" en el código, comentarios, ni documentación generada — es un motor de reglas simple, explícitamente NO usa modelos de lenguaje ni servicios de IA externos.

---

## 3. Notification Service (puerto 8004, base `notification_db`)

### Entidad: Notificacion
```text
- id (UUID, PK)
- paciente_id (UUID)
- tipo (enum: medicamento / cita)
- referencia_id (UUID — id del medicamento o cita relacionada)
- mensaje (string)
- fecha_hora_programada (datetime)
- estado (enum: pendiente / entregada / confirmada, default pendiente)
- intentos (integer, default 0)
- fecha_hora_ultimo_intento (datetime, nullable)
- created_at (datetime UTC)
```

### Endpoints
```text
GET    /notifications/pendientes           → notificaciones pendientes del paciente autenticado (el celular consulta esto por POLLING, cada cierto intervalo — no hay push real en el MVP)
POST   /notifications/{id}/confirmar          → el paciente confirma que la vio/atendió (detiene reintentos, pasa a estado "confirmada")
```

### Proceso interno recurrente (scheduler)
- Usar `APScheduler` corriendo dentro del mismo proceso de FastAPI (sin Celery, sin Redis, sin colas externas — mantener alcance simple).
- Cada 5 minutos (configurable), el proceso debe:
  1. Consultar `GET http://medication-service:8000/medications/internal/horarios-activos` (llamada REST interna, sin JWT) para saber qué medicamentos tienen horario en la ventana actual, y crear `Notificacion` tipo "medicamento" si no existe ya una para ese horario.
  2. Revisar `Notificacion` en estado "pendiente" cuyo `fecha_hora_ultimo_intento` supere un umbral (ej. 15 minutos) sin confirmación, e incrementar `intentos` + actualizar `fecha_hora_ultimo_intento` (esto es lo que el polling del celular va a volver a mostrar como "urgente").
- Las citas (tipo "cita") se generan igual pero con anticipación de 1 día — mismo mecanismo, sin necesitar lógica nueva aparte de leer la fecha programada de la cita (cuando exista esa entidad; no es parte del MVP inicial de Health Service en esta spec, se deja como extensión futura).

### Nota sobre notificaciones con sonido (fuera del alcance de este backend)
El sonido/vibración de alta prioridad al recibir la notificación NO se implementa en este microservicio — es responsabilidad del frontend Flutter (`flutter_local_notifications`, configurando un canal de notificación de prioridad alta). Este servicio solo debe exponer `GET /notifications/pendientes` de forma correcta y oportuna para que el polling del celular lo detecte y dispare la notificación local.

---

## Checklist de entrega esperado por cada servicio
- [ ] Modelos SQLAlchemy completos con los campos especificados arriba
- [ ] Schemas Pydantic (Create, Response, y los que hagan falta)
- [ ] Routers con los endpoints especificados, leyendo `X-User-Id` del header (no JWT)
- [ ] `database.py` con conexión a su base de datos específica vía `DATABASE_URL`
- [ ] `main.py` con `load_dotenv()` al inicio (antes de cualquier otro import), `Base.metadata.create_all()`, y el router incluido
- [ ] Dockerfile (imagen `python:3.11-slim`, copiar requirements primero, `--no-cache-dir`, puerto correspondiente, `--host 0.0.0.0`)
- [ ] `.dockerignore` (`.env`, `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `.git/`, `.gitignore`)
- [ ] Agregar el servicio nuevo al `docker-compose.yml` existente (con su propia variable de entorno `DATABASE_URL` apuntando a su base, healthcheck de Postgres como dependencia)
- [ ] Agregar su `CREATE DATABASE` correspondiente al `init.sql` compartido
