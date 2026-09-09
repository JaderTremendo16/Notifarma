# 💊 NotiFarma — Backend (Microservicios)

Backend para **NotiFarma**, una aplicación diseñada para el seguimiento y gestión de medicamentos, bienestar y recordatorios para adultos mayores (alineada con el **ODS 3: Salud y Bienestar**).

---

## 🏗️ Arquitectura del Sistema

El backend está compuesto por **5 componentes contenerizados** que se comunican dentro de una red privada de Docker:

```text
                                 ┌─────────────────────────────────┐
                                 │   Frontend Móvil (Flutter)     │
                                 └────────────────┬────────────────┘
                                                  │ (HTTP / JSON)
                                                  ▼
                                 ┌─────────────────────────────────┐
                                 │     API Gateway (Puerto 8001)   │
                                 │  - Valida Token JWT             │
                                 │  - Inyecta header X-User-Id     │
                                 └────┬───────────┬───────────┬────┘
                                      │           │           │
                 ┌────────────────────┘           │           └────────────────────┐
                 ▼                                ▼                                ▼
   ┌───────────────────────────┐    ┌───────────────────────────┐    ┌───────────────────────────┐
   │       Auth Service        │    │    Medication Service     │    │      Health Service       │
   │       (Puerto 8000)       │    │       (Puerto 8002)       │    │       (Puerto 8003)       │
   │  - Registro / Login       │    │  - Medicamentos           │    │  - Registro de Ánimo      │
   │  - Emisión de JWT         │    │  - Tomas (Historial)      │    │  - Registro de Síntomas   │
   │  - Vinculación Cuidador   │    │  - Próxima toma           │    │  - Motor Reglas Bienestar │
   └─────────────┬─────────────┘    └─────────────┬─────────────┘    └─────────────┬─────────────┘
                 │                                │ (Consulta interna)             │
                 │                                └──────────────┐                 │
                 │                                               ▼                 │
                 │                                 ┌───────────────────────────┐   │
                 │                                 │   Notification Service    │   │
                 │                                 │       (Puerto 8004)       │   │
                 │                                 │  - APScheduler recurrente │   │
                 │                                 │  - Polling para Flutter   │   │
                 │                                 └─────────────┬─────────────┘   │
                 │                                               │                 │
                 └───────────────────────┬───────────────────────┴─────────────────┘
                                         ▼
                          ┌─────────────────────────────┐
                          │   PostgreSQL Compartido     │
                          │   auth_db                   │
                          │   medication_db             │
                          │   health_db                 │
                          │   notification_db           │
                          └─────────────────────────────┘
```

---

## 🚀 Cómo Iniciar el Proyecto

### 1. Requisitos Previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y corriendo.
- Puerto `5432` (Postgres) y puertos `8000-8004` libres en tu máquina.

### 2. Iniciar todos los servicios

Desde la carpeta raíz del proyecto (`NotiFarma`):

```bash
docker compose up --build
```

> **Nota para la primera vez:** Si ya existía el volumen de Postgres y faltan bases de datos, resetea el volumen con:
>
> ```bash
> docker compose down -v
> docker compose up --build
> ```

---

## 📱 Guía para Desarrolladores Frontend (Flutter)

### 1. URL Base Única

El frontend **SOLO debe comunicarse con el API Gateway**:

- **En emulador Android:** `http://10.0.2.2:8001`
- **En dispositivo físico (misma red Wi-Fi):** `http://<IP_DE_TU_PC>:8001`
- **En emulador iOS o Web:** `http://localhost:8001`

> ⚠️ **¡No llames directamente a los puertos 8000, 8002, 8003 o 8004 desde Flutter!** El Gateway se encarga de validar tu sesión y reenviar la petición al microservicio correspondiente.

---

### 2. Flujo de Autenticación

1. Registrarse (`POST /auth/register`) o Iniciar sesión (`POST /auth/login`).
2. Al iniciar sesión recibes:
   ```json
   {
     "access_token": "eyJhbGciOi...",
     "token_type": "bearer"
   }
   ```
3. Guarda el `access_token` en almacenamiento seguro (`flutter_secure_storage` o `shared_preferences`).
4. Para **todos los demás endpoints**, envía el encabezado:
   ```http
   Authorization: Bearer <access_token>
   ```

---

### 3. Zonas Horarias y Horarios (Colombia UTC-5)

- **Fechas y Timestamps:** El backend siempre responde fechas en formato ISO-8601 en **UTC** (ej: `"2026-09-02T20:30:00Z"`).
  En Flutter, conviértelas a la hora del celular con:
  ```dart
  DateTime fechaUtc = DateTime.parse(jsonString);
  DateTime fechaLocal = fechaUtc.toLocal(); // Convierte automáticamente a la hora del dispositivo
  ```
- **Hora de Medicamentos (`hora_inicio`):** Se envía en formato `"HH:mm:ss"` (ej: `"08:00:00"`). Representa la hora habitual del paciente en su día a día.

---

## 📚 Catálogo de Endpoints (vía API Gateway: `http://localhost:8001`)

### 🔐 1. Autenticación y Perfil (`/auth`)

| Método | Ruta | Header Auth | Descripción |
|---|---|---|---|
| `POST` | `/auth/register` | No | Registro de paciente o cuidador. |
| `POST` | `/auth/login` | No | Inicia sesión y devuelve el JWT token. |
| `GET` | `/auth/me` | Bearer Token | Obtiene los datos del usuario logueado. |
| `POST` | `/auth/vincular-cuidador` | Bearer Token | Vincula un cuidador mediante su correo electrónico. |
| `GET` | `/auth/cuidador/mi-paciente` | Bearer Token (Cuidador) | **Para Cuidador:** Obtiene los datos y perfil de su paciente a cargo. |
| `GET` | `/auth/internal/cuidador-de/{paciente_id}` | No (Interno) | *Uso interno:* Retorna el `cuidador_id` vinculado al paciente. |
| `GET` | `/auth/internal/paciente-de/{cuidador_id}` | No (Interno) | *Uso interno:* Retorna el `paciente_id` vinculado al cuidador. |

---

### 💊 2. Medicamentos, Stock y Tomas (`/medications`)

| Método | Ruta | Header Auth | Descripción |
|---|---|---|---|
| `POST` | `/medications` | Bearer Token | Crea un nuevo medicamento (soporta `stock_actual` y `stock_minimo_alerta`). |
| `GET` | `/medications` | Bearer Token | Lista medicamentos activos del paciente. |
| `GET` | `/medications/proximo` | Bearer Token | **Para el Dashboard:** Próximo medicamento a tomar. |
| `GET` | `/medications/stock/alertas` | Bearer Token | Lista medicamentos cuyo stock es menor o igual al mínimo. |
| `PATCH` | `/medications/{id}/stock` | Bearer Token | **Pastillero:** Recarga o ajusta el stock actual y mínimo. |
| `GET` | `/medications/cuidador/resumen-paciente` | Bearer Token (Cuidador) | **Dashboard Cuidador:** Resumen completo del paciente (meds, stock, tomas de hoy). |
| `GET` | `/medications/reporte-adherencia/pdf?dias=30` | Bearer Token | **Reporte Clínico:** Descarga PDF formal de cumplimiento para consulta médica. |
| `GET` | `/medications/{id}` | Bearer Token | Detalle completo de un medicamento. |
| `PUT` | `/medications/{id}` | Bearer Token | Actualiza dosis, frecuencia o fechas. |
| `DELETE` | `/medications/{id}` | Bearer Token | Eliminación suave (soft delete). |
| `POST` | `/medications/{id}/tomas` | Bearer Token | Registra toma (`tomado`, `omitido`, `pendiente`). Resta 1 al stock si fue tomado. |
| `GET` | `/medications/tomas/historial` | Bearer Token | **Para pantalla Historial:** Registro de cumplimiento. |

#### Ejemplo crear medicamento con stock (`POST /medications`):
```json
{
  "nombre": "Losartán",
  "dosis": "50mg",
  "frecuencia_horas": 12,
  "hora_inicio": "08:00:00",
  "fecha_inicio": "2026-09-01",
  "stock_actual": 30,
  "stock_minimo_alerta": 5
}
```

#### Ejemplo recargar stock (`PATCH /medications/{id}/stock`):
```json
{
  "stock_actual": 20,
  "stock_minimo_alerta": 5
}
```

---

### 🩺 3. Salud, Bienestar y Citas Médicas (`/health`)

| Método | Ruta | Header Auth | Descripción |
|---|---|---|---|
| `POST` | `/health/mood` | Bearer Token | Registra estado de ánimo (`muy_bien`, `bien`, `regular`, `mal`). |
| `GET` | `/health/mood/hoy` | Bearer Token | Registros de ánimo de hoy del paciente. |
| `GET` | `/health/sintomas/catalogo` | No requerida | Catálogo fijo de síntomas (Dolor de cabeza, Mareo, etc.). |
| `POST` | `/health/sintomas` | Bearer Token | Registra uno o varios síntomas (admite catálogo o síntoma libre). |
| `GET` | `/health/historial?dias=7` | Bearer Token | Historial consolidado de ánimo y síntomas (últimos N días). |
| `GET` | `/health/recomendacion-hoy` | Bearer Token | **Mensaje de autocuidado del día** generado por el motor de reglas. |
| `POST` | `/health/citas` | Bearer Token | Agenda una nueva cita médica. |
| `GET` | `/health/citas` | Bearer Token | Lista las citas médicas activas y futuras del paciente. |
| `GET` | `/health/citas/{id}` | Bearer Token | Detalle completo de una cita médica. |
| `DELETE` | `/health/citas/{id}` | Bearer Token | Cancela/inactiva una cita médica. |

---

### 🔔 4. Notificaciones, Recordatorios y Alertas de Stock (`/notifications`)

El microservicio genera automáticamente recordatorios de medicamentos, citas y alertas de stock bajo.

| Método | Ruta | Header Auth | Descripción |
|---|---|---|---|
| `GET` | `/notifications/pendientes` | Bearer Token | **Polling periódico:** Consulta notificaciones pendientes dirigidas a este usuario (`destinatario_id`). |
| `POST` | `/notifications/{id}/confirmar` | Bearer Token | El usuario (paciente o cuidador) confirma que atendió la alerta. |

#### 🛡️ Alerta de Stock Bajo (Paciente y Cuidador):
Cuando una toma es marcada como `tomado` y el `stock_actual` disminuye hasta ser `<= stock_minimo_alerta`:
1. El **Paciente** recibe: *"Atención: Te quedan solo {X} dosis de {Medicamento}. Recuerda surtir tu receta."*
2. El **Cuidador** recibe: *"Alerta de Stock: A tu familiar le quedan solo {X} dosis de {Medicamento}. Recuerda surtir el medicamento."*
Ambos usuarios ven la alerta en su respectivo `GET /notifications/pendientes`.


#### Cómo implementarlo en Flutter:

1. **Configurar un Timer o Worker periódico (cada 1 o 2 minutos):**
   - Llama a `GET /notifications/pendientes`.
   - Si la lista contiene elementos, dispara una notificación local en el dispositivo usando `flutter_local_notifications` con canal de sonido de alta prioridad.
2. **Al pulsar la notificación o botón "Tomado":**
   - Llama a `POST /notifications/{id}/confirmar` para que el backend deje de reenviarla.

---

## 🧪 Pruebas Automatizadas

Cada microservicio cuenta con su suite de pruebas en PowerShell:

- **Medication Service:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "C:\Users\jader\.gemini\antigravity-ide\brain\77b8c796-5d59-4fa9-9572-a0a7d8c14629\test_medication_service.ps1"
  ```
- **Health Service:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "C:\Users\jader\.gemini\antigravity-ide\brain\77b8c796-5d59-4fa9-9572-a0a7d8c14629\test_health_service.ps1"
  ```
- **Notification Service:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "C:\Users\jader\.gemini\antigravity-ide\brain\77b8c796-5d59-4fa9-9572-a0a7d8c14629\test_notification_service.ps1"
  ```
