# 📋 Plan de Implementación Frontend y Registro de Cambios (NotiFarma)

Este documento detalla el desglose, estado y registro técnico de las 8 tareas de refinamiento del Frontend acordadas sobre el reporte de mejoras (`INFORME_MEJORAS_BACKEND_FRONTEND.md`).

---

## 📊 Estado General de Avance

| Tarea | Descripción | Estado |
| :--- | :--- | :---: |
| **Tarea 1** | Mostrar nombre del paciente en el Dashboard del Cuidador | ✅ **Completada** |
| **Tarea 2** | Mostrar familiar vinculado al paciente y botón para copiar código | ✅ **Completada** |
| **Tarea 3** | Mostrar la hora exacta formateada en la próxima dosis | ✅ **Completada** |
| **Tarea 4** | Contactos rápidos y botón SOS con llamada nativa real (`tel:`) | ✅ **Completada** |
| **Tarea 5** | Corregir diferenciación visual de emojis ("Con dolor" vs "Mareado") | ❌ **(No se realizará)** |
| **Tarea 6** | Descarga y apertura nativa de PDF en celular Android | ✅ **Completada** |
| **Tarea 7** | Restringir a solo números el teléfono en el formulario de registro | ✅ **Completada** |
| **Tarea 8** | Filtro por turnos de horario en la pantalla de medicamentos | ✅ **Completada** |

---

## 🚀 Desglose Detallado de lo Implementado

### ✅ TAREA 1: Nombre del Paciente en el Dashboard del Cuidador
* **Estado:** **COMPLETADA**
* **Archivo modificado:** `notifarma_app/lib/features/dashboard/presentation/screens/role_home_screen.dart`
* **Detalle técnico:**
  1. Lectura del campo `paciente_nombre` desde `_resumenCuidador`.
  2. Badge reactivo bajo el saludo que muestra:
     - 💙 Con paciente: `Cuidando a: [Nombre]` con ícono de corazón.
     - 🧡 Sin paciente: `Sin paciente vinculado` con ícono de búsqueda.
  3. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ TAREA 2: Mostrar Quién está Vinculado al Paciente y Copiado de Código
* **Estado:** **COMPLETADA**
* **Archivos modificados:**
  - `notifarma_app/lib/features/auth/data/models/user_model.dart`
  - `notifarma_app/lib/features/auth/presentation/screens/family_link_screen.dart`
  - `notifarma_app/lib/features/dashboard/presentation/screens/profile_screen.dart`
* **Detalle técnico:**
  1. Se añadieron `cuidadorNombre` y `cuidadorEmail` al `UserModel` con su mapeo bidireccional JSON.
  2. En `FamilyLinkScreen`: Se añadió la tarjeta destacada en verde esmeralda con check verificado (`Icons.verified_user_rounded`): *"VÍNCULO FAMILIAR ACTIVO - Familiar vinculado: [Nombre]"* con su correo.
  3. En `FamilyLinkScreen`: El botón interactivo de copiar código al portapapeles (`Clipboard.setData`) ya está operativo al lado de cada código generado con su SnackBar informativo.
  4. En `ProfileScreen`: Se añadió el renglón de información *"Familiar Vinculado"* bajo los datos personales del usuario.
  5. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ TAREA 3: Hora Exacta en la Próxima Dosis
* **Estado:** **COMPLETADA**
* **Archivos modificados:**
  - `notifarma_app/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart`
  - `notifarma_app/lib/features/dashboard/presentation/screens/role_home_screen.dart`
* **Detalle técnico:**
  1. En `HomeDashboardScreen` (Vista del Paciente): Se lee el campo `hora_formateada` entregado por el backend en `proximo_medicamento`, renderizando en la Hero Card el horario exacto: `"$horaFormateada • $dosis"` (ej: `08:00 AM • 1 tableta`) en lugar de datos estáticos.
  2. En `RoleHomeScreen` (Dashboard del Cuidador): Se integró el horario exacto `hora_formateada` en la tarjeta de próxima dosis programada para el familiar: `"${proximoMed['hora_formateada']} • ${proximoMed['dosis']}"`.
  3. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ TAREA 4: Llamada Telefónica Real en Contactos y Botón SOS
* **Estado:** **COMPLETADA**
* **Archivos modificados:**
  - `notifarma_app/lib/features/health/presentation/screens/wellness_screen.dart`
  - `notifarma_app/lib/features/auth/presentation/screens/pin_access_screen.dart`
* **Detalle técnico:**
  1. Se implementó el método reutilizable `_hacerLlamada(BuildContext context, String numero, String destinatario)` que sanea caracteres especiales, espacios y guiones (`RegExp(r'\s+|-')`) y abre el marcador nativo del sistema operativo mediante `Uri(scheme: 'tel', path: cleanNumber)`.
  2. **Botón SOS de Auxilio**: Al confirmar en el modal de alerta SOS, se realiza la llamada directa e inmediata a la línea de emergencias (`123`).
  3. **Contacto Rápido de Emergencia**: Realiza la llamada directamente al número registrado por el usuario en `contactoEmergenciaTelefono` (con fallback de auxilio si no tiene número configurado).
  4. **Pantalla de PIN (`PinAccessScreen`)**: También se actualizó el botón de auxilio telefónico para vincular dinámicamente el teléfono real de emergencia del usuario (`user?.contactoEmergenciaTelefono`).
  5. Feedback y control de fallbacks amigable ante dispositivos sin servicio o capacidades telefónicas con SnackBar en color de alerta.
  6. Verificado con `flutter analyze`: **0 issues**.

---

### ❌ TAREA 5: Corregir Diferenciación Visual de Emojis de Estado de Ánimo (No se realizará)
* **Estado:** **CANCELADA / DESCARTADA (No se realizará)**
* **Motivo:** Descartada por decisión de diseño y producto.
* **Archivo afectado:** `notifarma_app/lib/features/health/presentation/screens/wellness_screen.dart`

---

### ✅ TAREA 6: Descarga y Apertura Nativa de PDF en Celular Android
* **Estado:** **COMPLETADA**
* **Archivos modificados:**
  - `notifarma_app/pubspec.yaml`
  - `notifarma_app/lib/core/utils/pdf_downloader.dart`
* **Detalle técnico:**
  1. Se agregaron las dependencias oficiales `path_provider` y `open_filex` al proyecto Flutter.
  2. En `PdfDownloader.downloadPdfBytes`:
     - Para la Web (`kIsWeb`): Se preserva la descarga directa transparente mediante Blob HTML (`savePdfFileWeb`).
     - Para Móvil Android / iOS / Desktop: Los bytes binarios del reporte de adherencia se escriben en disco local (`getApplicationDocumentsDirectory()`) y se abre de inmediato con el visor nativo predeterminado del sistema operativo (`OpenFilex.open`), eliminando de raíz el fallo de los Data URIs y pantallas en blanco en navegadores móviles.
  3. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ TAREA 7: Restricción Numérica en Teléfono de Registro
* **Estado:** **COMPLETADA**
* **Archivo modificado:**
  - `notifarma_app/lib/features/auth/presentation/screens/register_screen.dart`
* **Detalle técnico:**
  1. En el campo de `contacto_emergencia_telefono`:
     - Teclado telefónico (`TextInputType.phone`).
     - Filtro estricto que solo permite dígitos (`FilteringTextInputFormatter.digitsOnly`).
     - Limitador de longitud máxima hasta 15 dígitos (`LengthLimitingTextInputFormatter(15)`).
     - Validador en el formulario que comprueba que la longitud esté entre 7 y 15 dígitos, garantizando 100% de cumplimiento con el validador Pydantic del backend (`auth-service/app/schemas/user_schema.py`).
  2. Adicionalmente, en el campo de `edad`:
     - Se aplicó `FilteringTextInputFormatter.digitsOnly`, longitud máxima de 3 dígitos y validación de rango (1 a 130 años).
  3. Verificado con `flutter analyze`: **0 issues**.

---

### ✅ TAREA 8: Filtro por Horario en Pantalla de Medicamentos
* **Estado:** **COMPLETADA**
* **Archivos modificados:**
  - `notifarma_app/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart`
  - `notifarma_app/lib/features/medications/presentation/screens/medication_plan_screen.dart`
  - `notifarma_app/lib/features/medications/providers/medication_provider.dart`
* **Detalle técnico:**
  1. En `MedicationProvider`:
     - Se añadió la opción y estado por defecto `'Todos'` al filtro de medicamentos.
     - En `filteredMedications`, si el filtro activo es `'Todos'`, retorna la lista completa sin exclusiones; si es `'Mañana'`, `'Tarde'` o `'Noche'`, segmenta con precisión según la hora de inicio de cada prescripción (`horaInicio`).
  2. En `HomeDashboardScreen` y `MedicationPlanScreen`:
     - Se integró la barra de chips con desplazamiento horizontal ergonómico para adultos mayores que contiene las 4 opciones:
       - 📋 **Todos**
       - 🌅 **Mañana** (05:00 a 11:59)
       - ☀️ **Tarde** (12:00 a 17:59)
       - 🌙 **Noche** (18:00 a 04:59)
     - La lista reactiva se conecta directamente a `medProvider.filteredMedications`, reflejando instantáneamente los medicamentos de la jornada seleccionada o el listado general al seleccionar 'Todos'.
  3. Verificado con `flutter analyze`: **0 issues**.

---

## 🛠️ Criterios de Aceptación y Calidad Cumplidos
- `flutter analyze` finaliza con **0 issues / No issues found**.
- Compatibilidad verificada tanto en Web como en Android.
- Todas las rutas y modelos se mantienen sincronizados con los endpoints del API Gateway (`:8001`).
- Sin dependencias rotas ni archivos auxiliares temporales.

