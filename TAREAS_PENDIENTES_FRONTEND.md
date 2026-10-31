# 🚨 TAREAS PENDIENTES FRONTEND — CORRECCIONES CRÍTICAS (NotiFarma)

Este documento detalla las correcciones obligatorias y pendientes en el Frontend que impiden el flujo funcional de la aplicación y la sustentación del proyecto.

---

## 1. 📞 ERROR CRÍTICO: Botón SOS y Llamada de Emergencia no funcionan
* **Problema:** Al presionar "Llamar al 123" o llamar al familiar, la aplicación no abre el marcador telefónico de Android.
* **Causa técnica:** A partir de Android 11 (API 30+), el sistema operativo bloquea llamadas implícitas si el esquema no está declarado en el manifiesto.
* **Solución requerida:**
  Editar el archivo: `notifarma_app/android/app/src/main/AndroidManifest.xml`
  Agregar el intent dentro del bloque `<queries>` existente:
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.DIAL" />
          <data android:scheme="tel" />
      </intent>
      <intent>
          <action android:name="android.intent.action.PROCESS_TEXT"/>
          <data android:mimeType="text/plain"/>
      </intent>
  </queries>
  ```

---

## 2. 👨‍⚕️ PENDIENTE: Acciones del Cuidador (Gestión Activa de Medicamentos y Citas)
* **Problema:** En el Dashboard del Cuidador (`role_home_screen.dart`), el cuidador solo puede "ver" datos de forma pasiva. No puede inscribir medicamentos, recargar pastillas ni agendar citas a su familiar, a pesar de que el backend ya tiene los endpoints listos con auditoría clínica.
* **Solución requerida en `role_home_screen.dart`:**
  1. **Agregar botón de Crear Medicamento:**
     - Colocar un botón principal (o `FloatingActionButton`): *"Inscribir Medicamento para mi Familiar"*.
     - Reutilizar el modal `_showAddMedicationModal()`. El backend asocia automáticamente el medicamento al paciente vinculado y registra la auditoría como creada por el Cuidador.
  2. **Acción de Recarga de Stock:**
     - En la lista de medicamentos del paciente, agregar un botón o ícono `+ Recargar Stock`.
     - Debe abrir un modal simple para ingresar cuántas unidades se compraron/recargaron y llamar al endpoint existente: `PATCH /medications/{id}/stock`.
  3. **Agendar Citas Médicas:**
     - Agregar un botón *"Agendar Cita Médica"* que permita seleccionar fecha, hora, especialidad, médico y lugar, consumiendo `POST /health/citas`. Al guardarse, el paciente recibe una notificación automática.

---

## 3. ⏰ HORA PREDETERMINADA: Eliminar '08:00:00' quemado en el formulario
* **Problema:** Al abrir el formulario de agregar medicamento, el campo de hora tiene siempre como texto fijo `'08:00:00'`.
* **Archivo afectado:** `notifarma_app/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart` (línea 200).
* **Solución requerida:**
  - Reemplazar el `TextField` estático con texto quemado por un selector interactivo nativo `showTimePicker(context: context, initialTime: TimeOfDay.now())`.
  - Debe mostrar la hora seleccionada formateada amigablemente (ej: `09:30 AM`) y guardar internamente el string `HH:mm:ss` para enviarlo al backend.

---

## 4. 🌐 DESFASE HORARIO (UTC vs Hora Local Colombia)
* **Problema:** Al programar un medicamento para las 12:00 PM, el sistema calcula la próxima dosis a las 5:00 PM (5 horas de diferencia).
* **Causa técnica:** Colombia es **UTC-5**. Si la app envía un string sin especificar zona o convierte erróneamente con `.toUtc()`, el servidor Docker (que opera en UTC) suma las 5 horas de diferencia.
* **Solución requerida:**
  - Asegurar que la hora enviada en el campo `hora_inicio` de `POST /medications` sea la hora local exacta elegida por el usuario en formato `HH:mm:ss` (ej: `12:00:00`), sin convertirla dos veces ni forzarla a UTC antes de enviarla.
  - Al recibir datetimes del backend con sufijo `Z` o UTC (como `proxima_toma`), formatearlos siempre usando `.toLocal()` antes de mostrarlos en pantalla.

---

## 📋 Checklist de Entrega para Frontend:
- [ ] `<queries>` de llamadas telefónicas agregado a `AndroidManifest.xml`.
- [ ] Botón SOS y contacto rápido abren el marcador nativo (`123` / número real).
- [ ] Cuidador puede presionar botón para inscribir medicamento a su familiar.
- [ ] Cuidador puede recargar stock de un medicamento.
- [ ] Cuidador puede agendar cita médica.
- [ ] Selector `TimePicker` interactivo en lugar del string `'08:00:00'` quemado.
- [ ] Horas de dosis y tomas sincronizadas correctamente con la hora local de Colombia.
