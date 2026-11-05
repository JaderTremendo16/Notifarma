# 📋 Plan de Implementación: Correcciones Críticas de Frontend (NotiFarma)

Este documento detalla el estado final, desglose técnico y archivos modificados correspondientes a las 4 tareas críticas descritas en `TAREAS_PENDIENTES_FRONTEND.md`.

---

## 📊 Resumen de Tareas

| # | Tarea | Impacto / Estado | Archivos Principales |
|---|-------|------------------|----------------------|
| **1** | Habilitar intent de llamada en Android Manifest | ✅ **Completado** | `notifarma_app/android/app/src/main/AndroidManifest.xml` |
| **2** | Selector interactivo de hora (`TimePicker`) | ✅ **Completado** | `home_dashboard_screen.dart` / `medication_plan_screen.dart` |
| **3** | Sincronización horaria (UTC vs Local Colombia UTC-5) | ✅ **Completado** | `medication_service.py` / `date_formatter.dart` |
| **4** | Acciones activas del Cuidador (Crear med, recargar stock, agendar cita) | ✅ **Completado** | `role_home_screen.dart` / `medication_repository.dart` |

---

## 🚀 Desglose Paso a Paso

### ✅ Punto 1: Corrección de Intent de Llamada Telefónica en Android
* **Estado:** **COMPLETADO**
* **Archivo modificado:** `notifarma_app/android/app/src/main/AndroidManifest.xml`
* **Implementado:**
  1. Se declaró el bloque `<intent>` con la acción `android.intent.action.DIAL` y esquema `tel` dentro de `<queries>`.
  2. Con esto, Android 11+ (API 30+) ya no bloquea las consultas de paquete ni los lanzamientos de llamadas de emergencia (123) ni contactos de auxilio.
  3. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ Punto 2: Selector Interactivo de Hora (`TimePicker`)
* **Estado:** **COMPLETADO**
* **Archivos modificados:**
  - `notifarma_app/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart`
  - `notifarma_app/lib/features/medications/presentation/screens/medication_plan_screen.dart`
* **Implementado:**
  1. Se eliminó el texto estático quemado `'08:00:00'`.
  2. Al abrir los modales de creación o edición de medicamentos, se inicializa automáticamente con la hora actual (`TimeOfDay.now()`) o con la hora previamente registrada en caso de edición.
  3. Se reemplazó el campo estático por un campo táctil elegante (`InkWell` + `InputDecorator`) con ícono de reloj y flecha indicadora que despliega el selector nativo interactivo `showTimePicker(context: context, initialTime: selectedTime)`.
  4. Muestra la hora seleccionada en formato amigable y legible para el paciente o adulto mayor (ej: `09:30 AM`), mientras que internamente persiste y envía al backend el string exacto en formato estándar `HH:mm:ss` (`09:30:00`).
  5. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ Punto 3: Corrección del Desfase Horario (UTC vs Local Colombia UTC-5)
* **Estado:** **COMPLETADO**
* **Archivos modificados:**
  - `medication-service/app/services/medication_service.py`
  - `notifarma_app/lib/core/utils/date_formatter.dart`
* **Implementado:**
  1. **Cálculo en Backend (`medication_service.py`):**
     - Se reemplazó la comparación directa contra `datetime.utcnow()` que causaba el desfase de 5 horas.
     - Ahora calcula la próxima toma utilizando la hora local de Colombia `ZoneInfo("America/Bogota")`, empatando exactamente con la hora ingresada por el usuario en `hora_inicio`.
  2. **Frontend (`date_formatter.dart`):**
     - `DateFormatter.formatTimeString` ahora detecta y normaliza cadenas de tiempo o timestamps ISO UTC convirtiéndolas a la zona local mediante `.toLocal()`.
     - El envío de medicamentos desde el frontend conserva la hora local limpia `HH:mm:ss` seleccionada por el usuario sin conversiones dobles.
  3. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ Punto 4: Habilitar Acciones Activas del Cuidador
* **Estado:** **COMPLETADO**
* **Archivos modificados:**
  - `notifarma_app/lib/features/dashboard/presentation/screens/role_home_screen.dart`
  - `notifarma_app/lib/features/medications/data/repositories/medication_repository.dart`
* **Implementado:**
  1. **Inscribir Medicamento para el Familiar:**
     - Botón principal de acceso rápido en el dashboard: *"Inscribir Med"*.
     - Modal completo con el nuevo selector interactivo `TimePicker`.
     - El backend asocia automáticamente el tratamiento al paciente a cargo con auditoría médica de Cuidador.
  2. **Recarga de Inventario / Stock:**
     - En `MedicationRepository` se implementó `actualizarStock(medId, stockActual)` consumiendo `PATCH /medications/{id}/stock`.
     - Nueva sección *"MEDICAMENTOS DE MI FAMILIAR"* con indicador de stock y botón interactivo `+ Recargar` para cada prescripción.
     - Botón interactivo de recarga rápida también integrado en el listado de *"Alertas de Stock Bajo"*.
     - Modal de ingreso de unidades que ejecuta `PATCH /medications/{id}/stock` registrando la recarga en la auditoría clínica.
  3. **Agendar Citas Médicas:**
     - Botón principal: *"Agendar Cita"*.
     - Modal interactivo con `showDatePicker` y `showTimePicker` nativos, campos para especialidad, médico, lugar y notas.
     - Consume `POST /health/citas` y dispara la notificación automática al familiar.
  4. Verificado con `flutter analyze`: **0 issues**.

---

## 🛠️ Criterios de Aceptación y Verificación Cumplidos
- `flutter analyze` finaliza con **0 issues / No issues found**.
- Manifest de Android correctamente configurado con `<queries>`.
- Todos los formularios usan `showTimePicker`.
- Registro de medicamentos respeta la hora local de Colombia sin sumar 5 horas.
- Vista del cuidador dispone de botones funcionales para crear medicamento, recargar stock y agendar citas.

