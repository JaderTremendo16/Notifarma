# 📋 Guía Técnica Definitiva: Backend & Frontend (NotiFarma)

Este documento contiene los cambios técnicos aplicados en el **Backend** y la lista de tareas organizadas con código de ejemplo para el **Frontend (Flutter)**.

---

## 🛠️ PARTE 1: Cambios Realizados en el Backend (Completados)

1. **Validación Estricta de Teléfono (`auth-service`)**:
   - `contacto_emergencia_telefono` valida con Pydantic solo números de 7 a 15 dígitos. Cualquier carácter no numérico retorna error `422`.

2. **Identidad del Cuidador para el Paciente (`auth-service`)**:
   - `GET /auth/me` ahora incluye `cuidador_nombre` y `cuidador_email` si el paciente tiene a alguien vinculado, permitiendo mostrar en pantalla el nombre real de su familiar.
   - `GET /auth/internal/paciente-de/{cuidador_id}` ahora retorna también `paciente_nombre` y `paciente_email`.

3. **Nombre del Paciente en Dashboard del Cuidador (`medication-service`)**:
   - `GET /medications/cuidador/resumen-paciente` ahora entrega directamente `paciente_nombre` y `paciente_email` en el payload principal.

4. **Hora Formateada de la Próxima Dosis (`medication-service`)**:
   - `GET /medications/proximo` y el objeto `proximo_medicamento` del resumen del cuidador ahora incluyen el campo `"hora_formateada"` (ejemplo: `"08:00 AM"` o `"06:30 PM"`).

5. **Nota sobre Síntomas**:
   - Se descartó la pantalla compleja de síntomas y STT por decisión de alcance. El registro de bienestar en `health-service` permanece disponible de forma ligera para el estado de ánimo diario.

---

## 📱 PARTE 2: Tareas para tu Compañero de Frontend (Flutter)

---

### TAREA 1: Mostrar Nombre del Paciente en el Dashboard del Cuidador
* **Archivo:** `notifarma_app/lib/features/dashboard/presentation/screens/role_home_screen.dart`
* **Cambio:** En la vista del cuidador, leer la propiedad `resumen.pacienteNombre` proveniente de `GET /medications/cuidador/resumen-paciente`.
* **Visual:** Mostrar en el encabezado principal:
  > *"Cuidando a: **Carlos Pérez**"* (o *"Sin paciente vinculado"* si no tiene).

---

### TAREA 2: Mostrar Quién está Vinculado al Paciente y Botón Copiar Código
* **Archivos:** `family_link_screen.dart` y/o `profile_screen.dart`
* **Cambio:**
  1. Si `user.cuidadorNombre != null`:
     - Mostrar tarjeta destacada: *"Familiar vinculado: ${user.cuidadorNombre}"*.
  2. Al lado del código generado (ej: `NF-4829`), agregar un botón de copiar con `Clipboard`:
     ```dart
     IconButton(
       icon: const Icon(Icons.copy_rounded, color: AppColors.primaryBlue),
       tooltip: 'Copiar código',
       onPressed: () {
         Clipboard.setData(ClipboardData(text: codigoGenerado));
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('¡Código copiado al portapapeles! 📋')),
         );
       },
     )
     ```

---

### TAREA 3: Mostrar la Hora Exacta en la Próxima Dosis
* **Archivo:** `role_home_screen.dart` (tanto en la vista del paciente como del cuidador)
* **Cambio:**
  - En la tarjeta del próximo medicamento, el backend ahora entrega `proximo.horaFormateada` (ej: `"08:00 AM"`).
  - Reemplazar cualquier texto genérico por:
    ```dart
    Text(
      'Hora programada: ${proximo.horaFormateada ?? DateFormat('hh:mm a').format(proximo.proximaToma.toLocal())}',
      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
    )
    ```

---

### TAREA 4: Contactos Rápidos y Botón SOS como Llamada Real Nativa
* **Archivo:** `wellness_screen.dart` (sección Contactos Rápidos y botón SOS)
* **Cambio:** Usar `url_launcher` con esquema `tel:`:
  ```dart
  import 'package:url_launcher/url_launcher.dart';

  Future<void> _hacerLlamada(String numero) async {
    final cleanNumber = numero.replaceAll(RegExp(r'\s+|-'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el marcador para el número: $numero')),
      );
    }
  }
  ```
  - Al presionar **SOS**: llamar a `123`.
  - Al presionar **Contacto de Emergencia / Cuidador**: llamar al teléfono guardado del contacto.

---

### TAREA 5: Corregir Bug Visual de "Con dolor" vs "Mareado"
* **Archivo:** `wellness_screen.dart`
* **Cambio:** En la fila de emojis, no usar el mismo valor `'mal'` para ambos en la UI:
  ```dart
  _buildEmojiOption(context, 'dolor', '😣', 'Con dolor', selectedMood, healthProvider, isDark),
  _buildEmojiOption(context, 'mareo', '😵', 'Mareado', selectedMood, healthProvider, isDark),
  ```
  *(Al enviar al backend, se puede mapear ambos como `'mal'` si se desea mantener el enum de la base de datos).*

---

### TAREA 6: Corregir Descarga y Apertura del PDF en Celular Android
* **Archivo:** `notifarma_app/lib/core/utils/pdf_downloader.dart`
* **Problema:** En Android, los visores nativos no abren `data:application/pdf;base64...`.
* **Solución:**
  1. En `pubspec.yaml`:
     ```yaml
     path_provider: ^2.1.2
     open_filex: ^4.4.0
     ```
  2. En `pdf_downloader.dart`:
     ```dart
     import 'dart:io';
     import 'package:path_provider/path_provider.dart';
     import 'package:open_filex/open_filex.dart';

     // Para mobile (!kIsWeb):
     final dir = await getApplicationDocumentsDirectory();
     final file = File('${dir.path}/$filename');
     await file.writeAsBytes(bytes, flush: true);
     await OpenFilex.open(file.path);
     ```

---

### TAREA 7: Restringir a Solo Números en Teléfono de Registro
* **Archivo:** `register_screen.dart`
* **Cambio:**
  ```dart
  keyboardType: TextInputType.phone,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ],
  ```

---

### TAREA 8: Filtro de Medicamentos por Horario (Mañana / Tarde / Noche)
* **Archivo:** `medication_plan_screen.dart`
* **Cambio:** Añadir un `SegmentedButton` con opciones:
  - **Todos**
  - **Mañana** (06:00 a 11:59)
  - **Tarde** (12:00 a 17:59)
  - **Noche** (18:00 a 05:59)
  Filtrar la lista por el campo `hora_inicio` del medicamento.
