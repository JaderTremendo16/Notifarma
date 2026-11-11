import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/services/notification_service.dart';
import 'package:notifarma_app/core/utils/audio_feedback.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';
import 'package:notifarma_app/features/health/data/models/appointment_model.dart';
import 'package:notifarma_app/features/health/providers/health_provider.dart';
import 'package:notifarma_app/features/medications/providers/medication_provider.dart';
import 'package:notifarma_app/features/health/presentation/widgets/appointment_edit_dialog.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';
import 'package:notifarma_app/shared/widgets/top_notification_banner.dart';

class UnifiedHomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const UnifiedHomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<UnifiedHomeDashboardScreen> createState() =>
      _UnifiedHomeDashboardScreenState();
}

class _UnifiedHomeDashboardScreenState
    extends State<UnifiedHomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MedicationProvider>(
        context,
        listen: false,
      ).fetchMedicationsData();
      Provider.of<HealthProvider>(context, listen: false).fetchHealthData();
    });
  }

  Future<void> _editAppointment(AppointmentModel appointment) async {
    final changes = await showAppointmentEditDialog(context, appointment);
    if (changes == null || !mounted) return;

    final provider = context.read<HealthProvider>();
    final ok = await provider.updateAppointment(
      id: appointment.id,
      especialidad: changes.especialidad,
      medico: changes.medico,
      lugar: changes.lugar,
      direccion: changes.direccion,
      fechaHoraIso: changes.fechaHoraIso,
      notas: changes.notas,
    );
    if (!mounted) return;
    if (ok) {
      AudioFeedback.playSuccess();
      await NotificationService().checkPendingNotifications();
      InAppNotificationService().show(
        title: 'Recordatorio actualizado',
        message: 'Los datos y avisos de la cita se actualizaron.',
        type: TopNotificationType.info,
        duration: const Duration(seconds: 3),
      );
    } else {
      InAppNotificationService().show(
        title: 'No se pudo actualizar',
        message:
            provider.errorMessage ?? 'Inténtalo de nuevo cuando haya conexión.',
        type: TopNotificationType.sosAlert,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar recordatorio'),
        content: Text(
          '¿Quieres cancelar el recordatorio de ${appointment.especialidad}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final provider = context.read<HealthProvider>();
    final ok = await provider.cancelAppointment(appointment.id);
    if (!mounted) return;
    if (ok) {
      AudioFeedback.playSuccess();
      await NotificationService().checkPendingNotifications();
      InAppNotificationService().show(
        title: 'Recordatorio cancelado',
        message: 'Se cancelaron los avisos asociados a la cita.',
        type: TopNotificationType.info,
        duration: const Duration(seconds: 3),
      );
    } else {
      InAppNotificationService().show(
        title: 'No se pudo cancelar',
        message:
            provider.errorMessage ?? 'Inténtalo de nuevo cuando haya conexión.',
        type: TopNotificationType.sosAlert,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _showEditMedicationModal(dynamic med) {
    final nombreCtrl = TextEditingController(text: med.nombre);
    final dosisCtrl = TextEditingController(text: med.dosis ?? '');
    final indicacionesCtrl = TextEditingController(
      text: med.indicaciones ?? '',
    );
    final frecuenciaCtrl = TextEditingController(
      text: med.frecuenciaHoras.toString(),
    );
    final horaCtrl = TextEditingController(text: med.horaInicio);
    final stockCtrl = TextEditingController(text: med.stockActual.toString());
    final stockMinCtrl = TextEditingController(
      text: med.stockMinimoAlerta.toString(),
    );

    // Extraer hora inicial para el TimePicker
    TimeOfDay selectedTime;
    try {
      final parts = med.horaInicio.split(':');
      selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      selectedTime = TimeOfDay.now();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final formattedTime = DateFormatter.formatTimeString(
              horaCtrl.text.trim(),
            );

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
                    Text(
                      'Editar Medicamento',
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Medicamento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dosisCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Dosis (ej. 500mg / 1 tableta)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: indicacionesCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones o notas',
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
                        prefixIcon: Icon(
                          Icons.access_time_rounded,
                          color: AppColors.primaryBlue,
                        ),
                        suffixIcon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      child: Text(
                        formattedTime.isNotEmpty
                            ? formattedTime
                            : 'Seleccionar Hora',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                            labelText: 'Stock Actual',
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
                      labelText: 'Alerta Stock Mínimo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (nombreCtrl.text.trim().isEmpty) return;
                      final provider = Provider.of<MedicationProvider>(
                        context,
                        listen: false,
                      );
                      final success = await provider.updateMedication(
                        med.id.toString(),
                        nombre: nombreCtrl.text.trim(),
                        dosis: dosisCtrl.text.trim(),
                        indicaciones: indicacionesCtrl.text.trim(),
                        frecuenciaHoras:
                            int.tryParse(frecuenciaCtrl.text.trim()) ??
                            med.frecuenciaHoras,
                        horaInicio: horaCtrl.text.trim(),
                        stockActual:
                            int.tryParse(stockCtrl.text.trim()) ??
                            med.stockActual,
                        stockMinimoAlerta:
                            int.tryParse(stockMinCtrl.text.trim()) ??
                            med.stockMinimoAlerta,
                      );
                      if (!mounted) return;
                      if (success) {
                        AudioFeedback.playSuccess();
                        if (ctx.mounted) Navigator.pop(ctx);
                        InAppNotificationService().show(
                          title: 'Medicamento actualizado',
                          message: 'Se guardaron los cambios correctamente.',
                          type: TopNotificationType.info,
                          duration: const Duration(seconds: 3),
                        );
                      } else {
                        InAppNotificationService().show(
                          title: 'No se pudo actualizar',
                          message:
                              provider.errorMessage ??
                              'Inténtalo de nuevo cuando haya conexión.',
                          type: TopNotificationType.sosAlert,
                          duration: const Duration(seconds: 4),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: const Text('GUARDAR CAMBIOS'),
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

  void _confirmDeleteMedication(dynamic med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: AppColors.sosRed,
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              'Eliminar Medicamento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${med.nombre}" del pastillero? Se conservará su historial de tomas pasadas.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<MedicationProvider>(
                context,
                listen: false,
              );
              final ok = await provider.deleteMedication(med.id.toString());
              if (!mounted) return;
              if (ok) {
                AudioFeedback.playSuccess();
                InAppNotificationService().show(
                  title: 'Medicamento eliminado',
                  message: 'Se quitó ${med.nombre} del pastillero.',
                  type: TopNotificationType.info,
                  duration: const Duration(seconds: 3),
                );
              } else {
                InAppNotificationService().show(
                  title: 'No se pudo eliminar',
                  message:
                      provider.errorMessage ??
                      'Inténtalo de nuevo cuando haya conexión.',
                  type: TopNotificationType.sosAlert,
                  duration: const Duration(seconds: 4),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            child: const Text(
              'ELIMINAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMedicationModal() {
    final nombreCtrl = TextEditingController();
    final dosisCtrl = TextEditingController();
    final indicacionesCtrl = TextEditingController();
    final frecuenciaCtrl = TextEditingController(text: '12');
    final stockCtrl = TextEditingController(text: '30');
    final stockMinCtrl = TextEditingController(text: '5');

    // Inicializar hora actual por defecto
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
            final formattedTime = DateFormatter.formatTimeString(
              horaCtrl.text.trim(),
            );

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
                    Text(
                      'Nuevo Medicamento',
                      style: Theme.of(ctx).textTheme.headlineMedium,
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Medicamento (ej. Losartán)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dosisCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Dosis (ej. 50mg / 1 tableta)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: indicacionesCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Indicaciones o notas',
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
                        prefixIcon: Icon(
                          Icons.access_time_rounded,
                          color: AppColors.accentOrange,
                        ),
                        suffixIcon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.accentOrange,
                        ),
                      ),
                      child: Text(
                        formattedTime.isNotEmpty
                            ? formattedTime
                            : 'Seleccionar Hora',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      final provider = Provider.of<MedicationProvider>(
                        context,
                        listen: false,
                      );
                      final success = await provider.createMedication(
                        nombre: nombreCtrl.text.trim(),
                        dosis: dosisCtrl.text.trim(),
                        indicaciones: indicacionesCtrl.text.trim().isNotEmpty
                            ? indicacionesCtrl.text.trim()
                            : null,
                        frecuenciaHoras:
                            int.tryParse(frecuenciaCtrl.text.trim()) ?? 12,
                        horaInicio: horaCtrl.text.trim(),
                        stockActual: int.tryParse(stockCtrl.text.trim()) ?? 30,
                        stockMinimoAlerta:
                            int.tryParse(stockMinCtrl.text.trim()) ?? 5,
                      );
                      if (!mounted) return;
                      if (success) {
                        AudioFeedback.playSuccess();
                        if (ctx.mounted) Navigator.pop(ctx);
                        InAppNotificationService().show(
                          title: 'Medicamento guardado',
                          message:
                              'Se agregó ${nombreCtrl.text.trim()} al pastillero.',
                          type: TopNotificationType.info,
                          duration: const Duration(seconds: 3),
                        );
                      } else {
                        InAppNotificationService().show(
                          title: 'No se pudo guardar',
                          message:
                              provider.errorMessage ??
                              'Inténtalo de nuevo cuando haya conexión.',
                          type: TopNotificationType.sosAlert,
                          duration: const Duration(seconds: 4),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                    ),
                    child: const Text('GUARDAR MEDICAMENTO'),
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

  void _showCrearCitaModal(BuildContext context) {
    final especialidadCtrl = TextEditingController();
    final medicoCtrl = TextEditingController();
    final lugarCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final notasCtrl = TextEditingController();

    final ahora = DateFormatter.nowColombia();
    DateTime selectedDate = ahora;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(
      ahora.add(const Duration(minutes: 30)),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dateStr =
                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.morningBlue,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Recordatorio de Cita',
                              style: Theme.of(ctx).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: especialidadCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Especialidad médica (ej. Odontología, Cardiología)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: medicoCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Médico (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lugarCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText:
                            'Centro Médico / Hospital (ej. Clínica Central)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: direccionCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText:
                            'Dirección o consultorio (ej. Calle 10 # 5-20)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: modalCtx,
                                initialDate: selectedDate,
                                firstDate: DateFormatter.nowColombia(),
                                lastDate: DateFormatter.nowColombia().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (pickedDate != null) {
                                setModalState(() => selectedDate = pickedDate);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.event_rounded,
                                  color: AppColors.morningBlue,
                                ),
                              ),
                              child: Text(
                                dateStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                builder: (context, child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(context)
                                        .copyWith(alwaysUse24HourFormat: false),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedTime != null) {
                                setModalState(() => selectedTime = pickedTime);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Hora',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.access_time_rounded,
                                  color: AppColors.morningBlue,
                                ),
                              ),
                              child: Text(
                                timeStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notasCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Indicaciones o notas (ej. Llevar exámenes de sangre)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (especialidadCtrl.text.trim().isEmpty) return;

                        // Validación: No permitir citas en fechas u horas pasadas
                        final fechaHoraCita = DateTime.utc(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        if (!fechaHoraCita.isAfter(
                          DateFormatter.nowColombia(),
                        )) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'La fecha y hora de la cita no puede ser en el pasado.',
                              ),
                              backgroundColor: AppColors.sosRed,
                            ),
                          );
                          return;
                        }

                        final fechaHoraIso = DateFormatter.toColombiaIsoString(
                          fechaHoraCita,
                        );

                        final healthProvider = Provider.of<HealthProvider>(
                          context,
                          listen: false,
                        );
                        final ok = await healthProvider.createAppointment(
                          especialidad: especialidadCtrl.text.trim(),
                          medico: medicoCtrl.text.trim().isNotEmpty
                              ? medicoCtrl.text.trim()
                              : null,
                          lugar: lugarCtrl.text.trim().isNotEmpty
                              ? lugarCtrl.text.trim()
                              : null,
                          direccion: direccionCtrl.text.trim().isNotEmpty
                              ? direccionCtrl.text.trim()
                              : null,
                          fechaHoraIso: fechaHoraIso,
                          notas: notasCtrl.text.trim().isNotEmpty
                              ? notasCtrl.text.trim()
                              : null,
                        );
                        if (!mounted) return;
                        if (ok) {
                          AudioFeedback.playSuccess();
                          if (ctx.mounted) Navigator.pop(ctx);
                          InAppNotificationService().show(
                            title: 'Recordatorio guardado',
                            message: 'Se programó el recordatorio de la cita médica.',
                            type: TopNotificationType.info,
                            duration: const Duration(seconds: 3),
                          );
                        } else {
                          InAppNotificationService().show(
                            title: 'No se pudo guardar',
                            message:
                                healthProvider.errorMessage ??
                                'Inténtalo de nuevo cuando haya conexión.',
                            type: TopNotificationType.sosAlert,
                            duration: const Duration(seconds: 4),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.morningBlue,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'GUARDAR RECORDATORIO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  bool _puedeConfirmarCita(String fechaHoraStr) {
    try {
      final fechaCita = DateFormatter.tryParseColombiaDateTime(fechaHoraStr);
      if (fechaCita == null) return false;
      final ahora = DateFormatter.nowColombia();
      final diferenciaMinutos = fechaCita.difference(ahora).inMinutes;
      return diferenciaMinutos <= 150 && diferenciaMinutos >= -120;
    } catch (_) {
      return false;
    }
  }

  String _mensajeCitaNoConfirmable(String fechaHoraStr) {
    try {
      final fechaCita = DateFormatter.tryParseColombiaDateTime(fechaHoraStr);
      if (fechaCita == null) {
        return 'No se pudo validar la hora de la cita.';
      }
      final ahora = DateFormatter.nowColombia();
      if (ahora.isBefore(fechaCita.subtract(const Duration(minutes: 150)))) {
        return 'Se habilitará 2 horas y media antes de la cita.';
      }
      if (ahora.isAfter(fechaCita.add(const Duration(hours: 2)))) {
        return 'El plazo para confirmar esta cita finalizó.';
      }
    } catch (_) {
      return 'No se pudo validar la hora de la cita.';
    }
    return 'La confirmación está disponible para esta cita.';
  }

  @override
  Widget build(BuildContext context) {
    final medProvider = Provider.of<MedicationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final proximo = medProvider.proximoMedicamento;
    final meds = medProvider.filteredMedications;

    return Column(
      children: [
        const SeniorHeader(subtitle: 'Inicio • Plan de Tomas del Día'),
        Expanded(
          child: medProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await medProvider.fetchMedicationsData();
                    if (!context.mounted) return;
                    await Provider.of<HealthProvider>(
                      context,
                      listen: false,
                    ).fetchHealthData();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. HERO CARD: TOCA PARA TOMAR (Próxima Toma Inmediata)
                        _buildHeroCard(proximo, medProvider, isDark),
                        const SizedBox(height: 20),

                        // 2. PRÓXIMAS TOMAS Y FILTROS POR JORNADA
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PLAN DE TOMAS DEL DÍA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                letterSpacing: 1.1,
                              ),
                            ),
                            IconButton(
                              onPressed: _showAddMedicationModal,
                              tooltip: 'Añadir Medicamento',
                              icon: const Icon(
                                Icons.add_circle_rounded,
                                color: AppColors.primaryBlue,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Filter Chips: Todos / Mañana / Tarde / Noche
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                'Todos',
                                'Todos',
                                medProvider,
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Mañana',
                                'Mañana',
                                medProvider,
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Tarde',
                                'Tarde',
                                medProvider,
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Noche',
                                'Noche',
                                medProvider,
                                isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Medication List
                        if (meds.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.medication_liquid_rounded,
                                  size: 44,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay tomas programadas en este turno.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: meds.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final m = meds[idx];
                              return _buildMedicationListItem(
                                m,
                                medProvider,
                                isDark,
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // SECCIÓN DE CITAS MÉDICAS PRÓXIMAS
                        _buildAppointmentsSection(context, isDark),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsSection(BuildContext context, bool isDark) {
    final healthProvider = Provider.of<HealthProvider>(context);
    final appointments = healthProvider.appointments
        .where((a) => a.activo)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.morningBlue,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'PRÓXIMAS CITAS MÉDICAS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.morningBlue,
                    size: 24,
                  ),
                  tooltip: 'Agregar Recordatorio de Cita',
                  onPressed: () => _showCrearCitaModal(context),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppColors.morningBlue,
                  ),
                  tooltip: 'Actualizar',
                  onPressed: () => healthProvider.fetchHealthData(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (appointments.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.morningBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.morningBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tienes citas médicas programadas por ahora.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: appointments.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final cita = appointments[idx];
              String fechaHoraFormateada = cita.fechaHora;
              final dt = DateFormatter.tryParseColombiaDateTime(cita.fechaHora);
              if (dt != null) {
                fechaHoraFormateada = DateFormatter.formatColombiaDateTime(dt);
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.morningBlue.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.15 : 0.03,
                      ),
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
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.morningBlue.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.medical_services_rounded,
                                  color: AppColors.morningBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  cita.especialidad,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cita.estado == 'asistida'
                                ? AppColors.successGreen.withValues(alpha: 0.15)
                                : cita.estado == 'no_asistida'
                                ? AppColors.sosRed.withValues(alpha: 0.15)
                                : cita.estado == 'sin_confirmar'
                                ? AppColors.afternoonOrange.withValues(
                                    alpha: 0.15,
                                  )
                                : AppColors.morningBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cita.estado == 'asistida'
                                ? 'Asistí ✓'
                                : cita.estado == 'no_asistida'
                                ? 'No asistí'
                                : cita.estado == 'sin_confirmar'
                                ? 'Sin confirmar'
                                : 'Programada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cita.estado == 'asistida'
                                  ? AppColors.successGreen
                                  : cita.estado == 'no_asistida'
                                  ? AppColors.sosRed
                                  : cita.estado == 'sin_confirmar'
                                  ? AppColors.afternoonOrange
                                  : AppColors.morningBlue,
                            ),
                          ),
                        ),
                        if (cita.estado == 'programada' ||
                            cita.estado == 'sin_confirmar')
                          PopupMenuButton<String>(
                            tooltip: 'Opciones de la cita',
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editAppointment(cita);
                              } else {
                                _cancelAppointment(cita);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar recordatorio'),
                              ),
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancelar cita'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fechaHoraFormateada,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    if (cita.lugar != null &&
                        cita.lugar!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_hospital_rounded,
                            size: 16,
                            color: AppColors.morningBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lugar: ${cita.lugar}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cita.direccion != null &&
                        cita.direccion!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppColors.sosRed,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Dirección: ${cita.direccion}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cita.medico != null &&
                        cita.medico!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_pin_rounded,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Médico: ${cita.medico}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cita.notas != null &&
                        cita.notas!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Indicaciones: ${cita.notas}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // BOTONES DE ASISTENCIA A LA CITA MÉDICA
                    if ((cita.estado == 'programada' ||
                            cita.estado == 'sin_confirmar') &&
                        _puedeConfirmarCita(cita.fechaHora))
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final ok = await healthProvider
                                    .updateAppointmentStatus(
                                      cita.id,
                                      'asistida',
                                    );
                                if (!context.mounted) return;
                                if (ok) {
                                  AudioFeedback.playConfirmation();
                                  await NotificationService()
                                      .checkPendingNotifications();
                                  InAppNotificationService().show(
                                    title: 'Asistencia registrada',
                                    message:
                                        'Marcaste que asististe a la cita.',
                                    type: TopNotificationType.info,
                                    duration: const Duration(seconds: 3),
                                  );
                                } else {
                                  InAppNotificationService().show(
                                    title: 'No se pudo actualizar',
                                    message: healthProvider.errorMessage ?? 'Inténtalo de nuevo cuando haya conexión.',
                                    type: TopNotificationType.sosAlert,
                                    duration: const Duration(seconds: 4),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'ASISTÍ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final ok = await healthProvider
                                    .updateAppointmentStatus(
                                      cita.id,
                                      'no_asistida',
                                    );
                                if (!context.mounted) return;
                                if (ok) {
                                  AudioFeedback.playSuccess();
                                  await NotificationService()
                                      .checkPendingNotifications();
                                  InAppNotificationService().show(
                                    title: 'Estado registrado',
                                    message:
                                        'Marcaste que no asististe a la cita.',
                                    type: TopNotificationType.info,
                                    duration: const Duration(seconds: 3),
                                  );
                                } else {
                                  InAppNotificationService().show(
                                    title: 'No se pudo actualizar',
                                    message: healthProvider.errorMessage ?? 'Inténtalo de nuevo cuando haya conexión.',
                                    type: TopNotificationType.sosAlert,
                                    duration: const Duration(seconds: 4),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight,
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              label: Text(
                                'NO ASISTÍ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else if ((cita.estado == 'programada' ||
                            cita.estado == 'sin_confirmar') &&
                        !_puedeConfirmarCita(cita.fechaHora))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _mensajeCitaNoConfirmable(cita.fechaHora),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  final Set<String> _submittingDoses = {};

  Widget _buildHeroCard(
    Map<String, dynamic>? proximo,
    MedicationProvider provider,
    bool isDark,
  ) {
    if (provider.medications.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_outlined,
                color: AppColors.primaryBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pastillero Vacío',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No tienes medicamentos registrados aún.\nToca el botón "+" para agregar tu primer medicamento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    // LISTAR TODAS LAS DOSIS PENDIENTES O PROGRAMADAS PARA EVITAR SUPERPOSICIÓN
    final medications = provider.medications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'RECORDATORIOS DE TOMA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: medications.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (ctx, idx) {
            final med = medications[idx];
            final medId = med.id.toString();
            final lastToma = provider.getUltimaToma(medId);
            final nextDose = provider.nextDoseAt(med);
            final isDoseRegistered = provider.isDoseRegisteredRecently(
              medId,
              frecuenciaHoras: med.frecuenciaHoras,
            );
            final isTaken =
                isDoseRegistered && lastToma?.estado.toLowerCase() == 'tomado';

            String lastHoraStr = 'hoy';
            if (lastToma?.fechaHoraConfirmacion != null) {
              try {
                final dt = DateFormatter.tryParseColombiaDateTime(
                  lastToma!.fechaHoraConfirmacion!,
                );
                if (dt != null) {
                  lastHoraStr = DateFormatter.formatColombiaTime(dt);
                }
              } catch (_) {}
            }

            final nowHour = DateFormatter.nowColombia().hour;
            final Color scheduleColor = (nowHour >= 5 && nowHour < 12)
                ? AppColors.morningBlue
                : (nowHour >= 12 && nowHour < 18)
                ? AppColors.afternoonOrange
                : AppColors.nightIndigo;

            final isOmitido =
                isDoseRegistered && lastToma?.estado.toLowerCase() == 'omitido';

            if (isTaken || isOmitido) {
              final isSuccess = isTaken;
              final Color badgeColor = isSuccess
                  ? AppColors.successGreen
                  : AppColors.sosRed;
              final Color bgContainer = isSuccess
                  ? (isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                        : const Color(0xFFF0FDF4))
                  : (isDark
                        ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                        : const Color(0xFFFEF2F2));

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: bgContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.nombre,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSuccess
                                  ? (isDark
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFF166534))
                                  : (isDark
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF991B1B)),
                            ),
                          ),
                          Text(
                            isSuccess
                                ? 'Dosis tomada a las $lastHoraStr • Registrada'
                                : 'Dosis omitida • Registrada para el turno actual',
                            style: TextStyle(
                              fontSize: 13,
                              color: isSuccess
                                  ? (isDark
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFF15803D))
                                  : (isDark
                                        ? const Color(0xFFFECACA)
                                        : const Color(0xFFB91C1C)),
                            ),
                          ),
                          if (nextDose != null)
                            Text(
                              'Próxima dosis: ${DateFormatter.formatColombiaDateTime(nextDose)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: scheduleColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheduleColor.withValues(
                      alpha: isDark ? 0.08 : 0.06,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          med.nombre,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheduleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          DateFormatter.formatTimeString(med.horaInicio),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scheduleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${med.dosis ?? "1 dosis"} • Cada ${med.frecuenciaHoras} hrs • Stock: ${med.stockActual}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (nextDose != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: AppColors.morningBlue,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Próxima dosis: ${DateFormatter.formatColombiaDateTime(nextDose)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.morningBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (med.indicaciones != null &&
                      med.indicaciones!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Indicaciones: ${med.indicaciones!}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.morningBlue,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              (_submittingDoses.contains(medId) ||
                                  med.stockActual <= 0)
                              ? null
                              : () async {
                                  setState(() => _submittingDoses.add(medId));
                                  final ok = await provider.registrarToma(
                                    medId,
                                    'tomado',
                                  );
                                  if (!mounted) return;
                                  setState(
                                    () => _submittingDoses.remove(medId),
                                  );
                                  if (ok) {
                                    AudioFeedback.playConfirmation();
                                    InAppNotificationService().show(
                                      title: 'Toma registrada',
                                      message:
                                          'Marcaste como tomada: ${med.nombre}.',
                                      type: TopNotificationType.info,
                                      duration: const Duration(seconds: 3),
                                    );
                                  } else {
                                    InAppNotificationService().show(
                                      title: 'No se pudo registrar',
                                      message:
                                          provider.errorMessage ??
                                          'No se pudo registrar la toma.',
                                      type: TopNotificationType.sosAlert,
                                      duration: const Duration(seconds: 4),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: med.stockActual <= 0
                                ? Colors.grey
                                : AppColors.successGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _submittingDoses.contains(medId)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          label: Text(
                            _submittingDoses.contains(medId)
                                ? 'REGISTRANDO...'
                                : (med.stockActual <= 0
                                      ? 'SIN STOCK'
                                      : 'YA LA TOMÉ'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _submittingDoses.contains(medId)
                            ? null
                            : () async {
                                setState(() => _submittingDoses.add(medId));
                                final ok = await provider.registrarToma(
                                  medId,
                                  'omitido',
                                );
                                if (!mounted) return;
                                setState(() => _submittingDoses.remove(medId));
                                if (ok) {
                                  AudioFeedback.playSuccess();
                                  InAppNotificationService().show(
                                    title: 'Dosis registrada',
                                    message:
                                        'Marcaste como no tomada: ${med.nombre}.',
                                    type: TopNotificationType.info,
                                    duration: const Duration(seconds: 3),
                                  );
                                } else {
                                  InAppNotificationService().show(
                                    title: 'No se pudo registrar',
                                    message: provider.errorMessage ?? 'No se pudo actualizar el estado de la dosis.',
                                    type: TopNotificationType.sosAlert,
                                    duration: const Duration(seconds: 4),
                                  );
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        label: Text(
                          'NO LA TOMÉ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    MedicationProvider provider,
    bool isDark,
  ) {
    final isSelected = provider.selectedFilter == key;
    return GestureDetector(
      onTap: () => provider.setFilter(key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationListItem(
    dynamic m,
    MedicationProvider provider,
    bool isDark,
  ) {
    final hora = DateFormatter.formatTimeString(m.horaInicio);
    final dosisTxt = m.dosis ?? '1 tableta';
    final stock = m.stockActual;
    final stockMin = m.stockMinimoAlerta;
    final isLowStock = stock <= stockMin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowStock
              ? AppColors.sosRed.withValues(alpha: 0.5)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLowStock
                  ? AppColors.sosRed.withValues(alpha: 0.1)
                  : AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: isLowStock ? AppColors.sosRed : AppColors.primaryBlue,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$hora • $dosisTxt',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: isLowStock
                          ? AppColors.sosRed
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stock: $stock pastillas ${isLowStock ? "(¡Stock Bajo!)" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLowStock
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isLowStock
                            ? AppColors.sosRed
                            : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: isDark ? AppColors.cardDark : Colors.white,
            onSelected: (val) {
              if (val == 'edit') {
                _showEditMedicationModal(m);
              } else if (val == 'delete') {
                _confirmDeleteMedication(m);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Editar dosis / stock',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: const Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.sosRed,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Eliminar pastilla',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sosRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
