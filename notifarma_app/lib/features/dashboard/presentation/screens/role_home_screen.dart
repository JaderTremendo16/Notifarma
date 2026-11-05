import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';
import 'package:notifarma_app/core/utils/pdf_downloader.dart';
import 'package:notifarma_app/features/auth/presentation/widgets/link_code_dialog.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/dashboard/presentation/screens/main_shell_screen.dart';
import 'package:notifarma_app/features/health/data/repositories/health_repository.dart';
import 'package:notifarma_app/features/medications/data/repositories/medication_repository.dart';
import 'package:notifarma_app/shared/widgets/theme_toggle_switch.dart';
import 'package:notifarma_app/shared/widgets/top_notification_banner.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final MedicationRepository _medRepo = MedicationRepository();
  final HealthRepository _healthRepo = HealthRepository();
  Map<String, dynamic>? _resumenCuidador;
  bool _isLoading = true;
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    _fetchCuidadorData();
  }

  Future<void> _fetchCuidadorData() async {
    setState(() => _isLoading = true);
    final data = await _medRepo.getResumenCuidador();
    if (mounted) {
      setState(() {
        _resumenCuidador = data;
        _isLoading = false;
      });
    }
  }

  void _downloadAdherencePdf(BuildContext context) async {
    setState(() => _isDownloadingPdf = true);
    InAppNotificationService().show(
      title: '📄 Generando Reporte PDF',
      message: 'Procesando el historial médico con zona horaria local...',
      type: TopNotificationType.info,
      duration: const Duration(seconds: 3),
    );

    try {
      final bytes = await _medRepo.downloadAdherencePdf(dias: 30);
      if (bytes.isNotEmpty) {
        await PdfDownloader.downloadPdfBytes(bytes, 'reporte_adherencia_cuidador.pdf');
        if (!mounted) return;
        InAppNotificationService().show(
          title: '✅ Reporte Descargado',
          message: 'El informe de adherencia se ha guardado correctamente.',
          type: TopNotificationType.info,
          duration: const Duration(seconds: 4),
        );
      } else {
        throw Exception('El archivo recibido está vacío');
      }
    } catch (e) {
      if (!mounted) return;
      InAppNotificationService().show(
        title: '❌ Error al Descargar',
        message: 'No se pudo generar el reporte: $e',
        type: TopNotificationType.sosAlert,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  // ─── ACCIÓN 1: MODAL INSCRIBIR MEDICAMENTO PARA EL PACIENTE ───
  void _showAddMedicationModal(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final dosisCtrl = TextEditingController();
    final frecuenciaCtrl = TextEditingController(text: '12');
    final stockCtrl = TextEditingController(text: '30');
    final stockMinCtrl = TextEditingController(text: '5');

    TimeOfDay selectedTime = TimeOfDay.now();
    final hStr = selectedTime.hour.toString().padLeft(2, '0');
    final mStr = selectedTime.minute.toString().padLeft(2, '0');
    final horaCtrl = TextEditingController(text: '$hStr:$mStr:00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final formattedTime = DateFormatter.formatTimeString(horaCtrl.text.trim());

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medication_rounded, color: AppColors.accentOrange, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Inscribir Medicamento',
                        style: Theme.of(ctx).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Se asociará automáticamente al plan de tu familiar.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreCtrl,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Medicamento (ej. Losartán)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dosisCtrl,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Dosis (ej. 50mg / 1 tableta)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // SELECTOR INTERACTIVO DE HORA (TimePicker)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: modalCtx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedTime = picked;
                          final h = picked.hour.toString().padLeft(2, '0');
                          final m = picked.minute.toString().padLeft(2, '0');
                          horaCtrl.text = '$h:$m:00';
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hora de la Primera Toma',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time_rounded, color: AppColors.accentOrange),
                        suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentOrange),
                      ),
                      child: Text(
                        formattedTime.isNotEmpty ? formattedTime : 'Seleccionar Hora',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: frecuenciaCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'Cada cuántas hrs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'Stock Inicial',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockMinCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Alerta Stock Mínimo (ej. 5)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (nombreCtrl.text.trim().isEmpty) return;
                      try {
                        await _medRepo.createMedication(
                          nombre: nombreCtrl.text.trim(),
                          dosis: dosisCtrl.text.trim(),
                          frecuenciaHoras: int.tryParse(frecuenciaCtrl.text.trim()) ?? 12,
                          horaInicio: horaCtrl.text.trim(),
                          stockActual: int.tryParse(stockCtrl.text.trim()) ?? 30,
                          stockMinimoAlerta: int.tryParse(stockMinCtrl.text.trim()) ?? 5,
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchCuidadorData();
                        InAppNotificationService().show(
                          title: '✅ Medicamento Inscrito',
                          message: 'Se programó ${nombreCtrl.text.trim()} para tu familiar.',
                          type: TopNotificationType.info,
                          duration: const Duration(seconds: 4),
                        );
                      } catch (e) {
                        InAppNotificationService().show(
                          title: '❌ Error',
                          message: 'Error al inscribir medicamento: $e',
                          type: TopNotificationType.sosAlert,
                          duration: const Duration(seconds: 4),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('GUARDAR EN PASTILLERO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── ACCIÓN 2: MODAL RECARGA DE STOCK ───
  void _showRecargarStockModal(BuildContext context, dynamic med) {
    final cantidadCtrl = TextEditingController(text: '30');
    final stockActual = med['stock_actual'] ?? 0;
    final nombreMed = med['nombre'] ?? 'Medicamento';
    final medId = med['id'] ?? med['medicamento_id'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primaryBlue, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recargar Stock',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medicamento: $nombreMed',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock disponible actual: $stockActual pastillas.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cantidadCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: '¿Cuántas unidades se adquirieron?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondaryLight, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final agregadas = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
              if (agregadas <= 0) return;
              final nuevoStock = stockActual + agregadas;

              try {
                await _medRepo.actualizarStock(medId.toString(), stockActual: nuevoStock);
                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchCuidadorData();
                InAppNotificationService().show(
                  title: '📦 Stock Actualizado',
                  message: 'Se recargaron +$agregadas unidades de $nombreMed (Total: $nuevoStock).',
                  type: TopNotificationType.info,
                  duration: const Duration(seconds: 4),
                );
              } catch (e) {
                InAppNotificationService().show(
                  title: '❌ Error',
                  message: 'Error al recargar stock: $e',
                  type: TopNotificationType.sosAlert,
                  duration: const Duration(seconds: 4),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('CONFIRMAR RECARGA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── ACCIÓN 3: MODAL AGENDAR CITA MÉDICA ───
  void _showAgendarCitaModal(BuildContext context) {
    final especialidadCtrl = TextEditingController();
    final medicoCtrl = TextEditingController();
    final lugarCtrl = TextEditingController();
    final notasCtrl = TextEditingController();

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
            final timeStr = selectedTime.format(context);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.morningBlue, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Agendar Cita Médica',
                          style: Theme.of(ctx).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tu familiar recibirá una notificación automática con los detalles.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: especialidadCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Especialidad (ej. Cardiología, Control General)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: medicoCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Médico (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lugarCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Lugar / Clínica (ej. Hospital Central)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // SELECCIÓN DE FECHA Y HORA
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: modalCtx,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (pickedDate != null) {
                                setModalState(() => selectedDate = pickedDate);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event_rounded, color: AppColors.morningBlue),
                              ),
                              child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: modalCtx,
                                initialTime: selectedTime,
                              );
                              if (pickedTime != null) {
                                setModalState(() => selectedTime = pickedTime);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Hora',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time_rounded, color: AppColors.morningBlue),
                              ),
                              child: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notasCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notas o indicaciones adicionales',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (especialidadCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor indique la especialidad')),
                          );
                          return;
                        }

                        final h = selectedTime.hour.toString().padLeft(2, '0');
                        final m = selectedTime.minute.toString().padLeft(2, '0');
                        final fechaHoraIso = '${DateFormat('yyyy-MM-dd').format(selectedDate)}T$h:$m:00';

                        try {
                          await _healthRepo.createAppointment(
                            especialidad: especialidadCtrl.text.trim(),
                            medico: medicoCtrl.text.trim().isNotEmpty ? medicoCtrl.text.trim() : null,
                            lugar: lugarCtrl.text.trim().isNotEmpty ? lugarCtrl.text.trim() : null,
                            fechaHoraIso: fechaHoraIso,
                            notas: notasCtrl.text.trim().isNotEmpty ? notasCtrl.text.trim() : null,
                          );
                          if (!mounted) return;
                          if (ctx.mounted) Navigator.pop(ctx);
                          InAppNotificationService().show(
                            title: '📅 Cita Agendada con Éxito',
                            message: 'Se notificó a tu familiar sobre la cita de ${especialidadCtrl.text.trim()}.',
                            type: TopNotificationType.info,
                            duration: const Duration(seconds: 4),
                          );
                        } catch (e) {
                          InAppNotificationService().show(
                            title: '❌ Error',
                            message: 'Error al agendar cita: $e',
                            type: TopNotificationType.sosAlert,
                            duration: const Duration(seconds: 4),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.morningBlue,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('AGENDAR CITA MÉDICA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Si es Paciente, entra directamente al shell principal
    if (user != null && user.rol.toLowerCase() == 'paciente') {
      return const MainShellScreen();
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final pacienteNombre = _resumenCuidador?['paciente_nombre'] as String?;
    final totalMeds = _resumenCuidador?['total_medicamentos_activos'] ?? 0;
    final totalTomasHoy = _resumenCuidador?['total_tomas_hoy'] ?? 0;
    final totalTomadasHoy = _resumenCuidador?['total_tomadas_hoy'] ?? 0;
    final proximoMed = _resumenCuidador?['proximo_medicamento'] as Map<String, dynamic>?;
    final alertasStock = (_resumenCuidador?['alertas_stock'] as List?) ?? [];
    final tomasHoyList = (_resumenCuidador?['tomas_hoy'] as List?) ?? [];
    final medicamentosList = (_resumenCuidador?['medicamentos'] as List?) ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCuidadorData,
          color: AppColors.primaryBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_rounded,
                            color: AppColors.accentOrange,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PANEL DEL CUIDADOR',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentOrange,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'NotiFarma Familiar',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ThemeToggleSwitch(
                      isDark: isDark,
                      onChanged: (val) => themeProvider.toggleTheme(val),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Greeting & Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        child: const Icon(Icons.person_rounded, color: AppColors.primaryBlue, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola, ${user?.nombres ?? "Cuidador"}!',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Monitoreo en tiempo real de tu familiar',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: pacienteNombre != null
                                    ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                    : AppColors.afternoonOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: pacienteNombre != null
                                      ? AppColors.primaryBlue.withValues(alpha: 0.3)
                                      : AppColors.afternoonOrange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    pacienteNombre != null
                                        ? Icons.favorite_rounded
                                        : Icons.person_search_rounded,
                                    size: 14,
                                    color: pacienteNombre != null
                                        ? AppColors.primaryBlue
                                        : AppColors.afternoonOrange,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      pacienteNombre != null
                                          ? 'Cuidando a: $pacienteNombre'
                                          : 'Sin paciente vinculado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: pacienteNombre != null
                                            ? AppColors.primaryBlue
                                            : AppColors.afternoonOrange,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _fetchCuidadorData,
                        tooltip: 'Actualizar',
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  // KPI SUMMARY TILES
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Tomas de Hoy',
                          value: '$totalTomadasHoy / $totalTomasHoy',
                          subtitle: totalTomasHoy > 0 && totalTomadasHoy >= totalTomasHoy
                              ? '¡100% Completado! 🎉'
                              : 'En progreso',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.successGreen,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Pastillero Activo',
                          value: '$totalMeds',
                          subtitle: 'Tratamientos activos',
                          icon: Icons.medication_rounded,
                          color: AppColors.primaryBlue,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── ACCIONES ACTIVAS DEL CUIDADOR (GESTIÓN MÉDICA) ───
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddMedicationModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Inscribir Med',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAgendarCitaModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.morningBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Agendar Cita',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PRÓXIMA DOSIS DEL PACIENTE
                  if (proximoMed != null)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.morningBlue.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.morningBlue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.alarm_rounded, color: AppColors.morningBlue, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PRÓXIMA DOSIS PROGRAMADA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.morningBlue,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  proximoMed['nombre'] ?? 'Medicamento',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                                Text(
                                  (proximoMed['hora_formateada'] != null ? '${proximoMed['hora_formateada']} • ' : '') + (proximoMed['dosis'] ?? '1 tableta'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // ALERTAS DE STOCK BAJO (Si existen)
                  if (alertasStock.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.afternoonOrange.withValues(alpha: 0.7), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.afternoonOrange, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '¡Alerta de Stock Bajo (${alertasStock.length})!',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.afternoonOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Los siguientes medicamentos están por agotarse en el botiquín del paciente:',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...alertasStock.map((a) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.circle, size: 8, color: AppColors.afternoonOrange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${a['nombre']} • Quedan ${a['stock_actual']} pastillas',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showRecargarStockModal(context, a),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.afternoonOrange,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'Recargar',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // GESTIÓN DE MEDICAMENTOS Y RECARGA DE STOCK
                  if (medicamentosList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MEDICAMENTOS DE MI FAMILIAR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                '${medicamentosList.length} activos',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: medicamentosList.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 16),
                            itemBuilder: (ctx, i) {
                              final m = medicamentosList[i];
                              final medName = m['nombre'] ?? 'Medicamento';
                              final dosis = m['dosis'] ?? '';
                              final stock = m['stock_actual'] ?? 0;
                              final isLow = stock <= (m['stock_minimo_alerta'] ?? 5);

                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isLow
                                          ? AppColors.afternoonOrange.withValues(alpha: 0.15)
                                          : AppColors.primaryBlue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.medication_rounded,
                                      color: isLow ? AppColors.afternoonOrange : AppColors.primaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medName,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          dosis.isNotEmpty ? '$dosis • Stock: $stock' : 'Stock: $stock pastillas',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isLow ? AppColors.afternoonOrange : AppColors.textSecondaryLight,
                                            fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showRecargarStockModal(context, m),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: const Size(60, 32),
                                      side: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: AppColors.primaryBlue),
                                    label: const Text('+ Recargar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // TOMAS DEL DÍA
                  if (tomasHoyList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HISTORIAL DE HOY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tomasHoyList.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (ctx, idx) {
                              final t = tomasHoyList[idx];
                              final isTomado = (t['estado'] ?? '').toString().toLowerCase() == 'tomado';
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isTomado ? Icons.check_circle_rounded : Icons.pending_rounded,
                                        color: isTomado ? AppColors.successGreen : AppColors.afternoonOrange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Dosis programada #${idx + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isTomado
                                          ? AppColors.successGreen.withValues(alpha: 0.15)
                                          : AppColors.afternoonOrange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isTomado ? 'TOMADA' : 'PENDIENTE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isTomado ? AppColors.successGreen : AppColors.afternoonOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                ],

                // ACCIÓN 1: Descargar Reporte PDF
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, color: AppColors.sosRed, size: 26),
                          SizedBox(width: 10),
                          Text(
                            'Reporte de Adherencia (PDF)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Descarga el informe médico formal con los horarios locales y estadísticas para la consulta médica.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isDownloadingPdf ? null : () => _downloadAdherencePdf(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sosRed,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isDownloadingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded, color: Colors.white),
                        label: Text(
                          _isDownloadingPdf ? 'DESCARGANDO...' : 'DESCARGAR INFORME CLÍNICO',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ACCIÓN 2: Vincular otro Paciente
                OutlinedButton.icon(
                  onPressed: () => LinkCodeDialog.show(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.primaryBlue.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, color: AppColors.primaryBlue),
                  label: const Text(
                    'VINCULAR / CAMBIAR CÓDIGO FAMILIAR',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout Button
                TextButton.icon(
                  onPressed: () async {
                    await authProvider.logout();
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondaryLight),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
