# 📋 Plan de Mejoras y Sincronización NotiFarma (Backend & Frontend)

Este documento detalla los cambios realizados en el **Backend** y la guía técnica paso a paso de lo que tu compañero debe implementar en el **Frontend (Flutter)** para dejar el sistema 100% operativo y listo para la sustentación.

---

## 🛠️ PARTE 1: Cambios Realizados en el Backend (Tus tareas)

### 1. Validación Estricta de Teléfono de Emergencia (`auth-service`)
- **Archivo:** `auth-service/app/schemas/user_schema.py`
- **Cambio:** Se implementó un `@field_validator("contacto_emergencia_telefono")` que rechaza letras, símbolos extraños o números con menos de 7 o más de 15 dígitos.
- **Resultado:** Si el frontend o un usuario intenta enviar letras o números incompletos, el backend responde con error `422 Unprocessable Entity` y el mensaje exacto.

### 2. Integración de Síntomas y Bienestar en el Reporte PDF (`medication-service` & `health-service`)
- **Archivos:** 
  - `docker-compose.yml`: Se añadió `HEALTH_SERVICE_URL: http://health-service:8003` al entorno de `medication-service`.
  - `medication-service/app/routers/medication_router.py`:
    - Al solicitar el PDF (`/medications/reporte-adherencia/pdf`), ahora se consulta el historial de síntomas y estados de ánimo del paciente en `health-service`.
    - Se incorporó la sección **"🩺 Registro de Síntomas y Bienestar del Paciente"** dentro del PDF con ReportLab, listando fecha, síntoma, severidad y observaciones escritas/dictadas.

---

## 📱 PARTE 2: Tareas para tu Compañero de Frontend (Flutter)

Compártele las siguientes secciones para que las implemente en la aplicación móvil:

---

### TAREA 1: Corregir Bug de Selección de Ánimo (Con dolor vs Mareado)
* **Archivo:** `notifarma_app/lib/features/health/presentation/screens/wellness_screen.dart`
* **Problema:** En las líneas 145 y 147, tanto "Con dolor" como "Mareado" tienen configurado el mismo valor clave `'mal'`. Por eso, al seleccionar uno, se iluminaban ambos.
* **Solución requerida:**
  Cambiar los identificadores para que sean independientes o agruparlos lógicamente:
  ```dart
  _buildEmojiOption(context, 'dolor', '😣', 'Con dolor', selectedMood, healthProvider, isDark),
  _buildEmojiOption(context, 'mareo', '😵', 'Mareado', selectedMood, healthProvider, isDark),
  ```
  *(O si se mantiene `'mal'` para ambos en la DB, manejar el estado visual por emoji o etiqueta, no solo por el valor clave).*

---

### TAREA 2: Flujo Condicional de Registro de Síntomas (Escrito o STT / Voz)
* **Archivo:** `wellness_screen.dart` y nueva pantalla o modal de síntomas.
* **Comportamiento esperado:**
  1. Si el paciente selecciona **"Muy bien"** (🤩) o **"Bien"** (😊):
     - Se registra directamente el ánimo y se muestra el mensaje de autocuidado.
  2. Si el paciente selecciona **"Regular"** (😐), **"Con dolor"** (😣) o **"Mareado"** (😵):
     - Registrar el ánimo y **desplegar inmediatamente un BottomSheet o navegar a `ReportarSintomasScreen`**.
  3. **En la vista de síntomas:**
     - Consultar el catálogo con `GET /health/sintomas/catalogo` para mostrar Chips seleccionables: `Dolor de cabeza`, `Fatiga`, `Mareo`, `Náuseas`, `Dolor muscular`.
     - Slider o selector de severidad: `Leve`, `Moderada`, `Fuerte`.
     - Campo de texto libre para detalles u "Otro síntoma".
     - **Soporte de Voz (Speech-To-Text):** 
       - Si no usan el micrófono nativo del teclado del celular (Gboard ya transcribe voz a texto automáticamente en cualquier `TextField`), pueden agregar la librería `speech_to_text: ^6.6.1` en `pubspec.yaml` con un botón de micrófono junto al campo de notas.
     - Botón **"Guardar Síntomas"** que hace `POST /health/sintomas` con la lista de síntomas seleccionados.

---

### TAREA 3: Corregir Descarga y Apertura del PDF en Celular Android
* **Archivo:** `notifarma_app/lib/core/utils/pdf_downloader.dart`
* **Problema:** Actualmente usa `launchUrl(Uri.parse('data:application/pdf;base64,...'))`. En Android los navegadores y visores de PDF no abren Data URIs binarios directos, por lo que la notificación sale pero el PDF nunca se muestra ni se guarda.
* **Solución requerida:**
  1. Agregar en `pubspec.yaml`:
     ```yaml
     path_provider: ^2.1.2
     open_filex: ^4.4.0
     ```
  2. En `pdf_downloader.dart`, para plataformas móviles (`!kIsWeb`):
     ```dart
     import 'dart:io';
     import 'package:path_provider/path_provider.dart';
     import 'package:open_filex/open_filex.dart';

     // Obtener directorio de documentos temporales o descargas
     final dir = await getApplicationDocumentsDirectory();
     final file = File('${dir.path}/$filename');
     await file.writeAsBytes(bytes, flush: true);

     // Abrir el PDF inmediatamente con el visor del celular
     await OpenFilex.open(file.path);
     ```

---

### TAREA 4: Restricción de solo números en el teléfono de emergencia
* **Archivo:** `notifarma_app/lib/features/auth/presentation/screens/register_screen.dart`
* **Solución requerida:**
  En el `TextFormField` del teléfono de emergencia:
  1. Agregar `keyboardType: TextInputType.phone`.
  2. Agregar formateador para impedir caracteres que no sean dígitos:
     ```dart
     inputFormatters: [
       FilteringTextInputFormatter.digitsOnly,
       LengthLimitingTextInputFormatter(10),
     ],
     ```
  3. Validar en el `validator` que no contenga letras y tenga al menos 7 dígitos.

---

### TAREA 5: Filtro de Medicamentos por Horario / Momento del Día
* **Archivo:** `notifarma_app/lib/features/medications/presentation/screens/medication_plan_screen.dart`
* **Solución requerida:**
  Agregar un `SegmentedButton` o pestañas de filtro rápido:
  - **Todos**
  - **Mañana** (06:00 a 11:59)
  - **Tarde** (12:00 a 17:59)
  - **Noche** (18:00 a 05:59)
  Filtrar la lista comparando la propiedad `hora_inicio` de cada medicamento con la franja horaria seleccionada.
