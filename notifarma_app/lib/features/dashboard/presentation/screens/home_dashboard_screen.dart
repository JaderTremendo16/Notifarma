import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';
import 'package:notifarma_app/features/health/providers/health_provider.dart';
import 'package:notifarma_app/features/medications/providers/medication_provider.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';
import 'package:notifarma_app/shared/widgets/top_notification_banner.dart';

class UnifiedHomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const UnifiedHomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<UnifiedHomeDashboardScreen> createState() => _UnifiedHomeDashboardScreenState();
}

class _UnifiedHomeDashboardScreenState extends State<UnifiedHomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MedicationProvider>(context, listen: false).fetchMedicationsData();
      Provider.of<HealthProvider>(context, listen: false).fetchHealthData();
    });
  }

  void _showEditMedicationModal(dynamic med) {
    final nombreCtrl = TextEditingController(text: med.nombre);
    final dosisCtrl = TextEditingController(text: med.dosis ?? '');
    final frecuenciaCtrl = TextEditingController(text: med.frecuenciaHoras.toString());
    final horaCtrl = TextEditingController(text: med.horaInicio);
    final stockCtrl = TextEditingController(text: med.stockActual.toString());
    final stockMinCtrl = TextEditingController(text: med.stockMinimoAlerta.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
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
              Text(
                'Editar Medicamento',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Nombre del Medicamento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosisCtrl,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Dosis (ej. 500mg / 1 tableta)',
                  border: OutlineInputBorder(),
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
                  final provider = Provider.of<MedicationProvider>(context, listen: false);
                  final success = await provider.updateMedication(
                    med.id.toString(),
                    nombre: nombreCtrl.text.trim(),
                    dosis: dosisCtrl.text.trim(),
                    frecuenciaHoras: int.tryParse(frecuenciaCtrl.text.trim()) ?? med.frecuenciaHoras,
                    horaInicio: horaCtrl.text.trim(),
                    stockActual: int.tryParse(stockCtrl.text.trim()) ?? med.stockActual,
                    stockMinimoAlerta: int.tryParse(stockMinCtrl.text.trim()) ?? med.stockMinimoAlerta,
                  );
                  if (!mounted) return;
                  if (success) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medicamento actualizado correctamente ✏️')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                child: const Text('GUARDAR CAMBIOS'),
              ),
            ],
          ),
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
            Icon(Icons.delete_outline_rounded, color: AppColors.sosRed, size: 28),
            SizedBox(width: 10),
            Text('Eliminar Medicamento', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${med.nombre}" del pastillero? Se conservará su historial de tomas pasadas.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<MedicationProvider>(context, listen: false);
              final ok = await provider.deleteMedication(med.id.toString());
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Medicamento "${med.nombre}" eliminado del pastillero 🗑️'),
                    backgroundColor: AppColors.textSecondary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddMedicationModal() {
    final nombreCtrl = TextEditingController();
    final dosisCtrl = TextEditingController();
    final frecuenciaCtrl = TextEditingController(text: '12');
    final horaCtrl = TextEditingController(text: '08:00:00');
    final stockCtrl = TextEditingController(text: '30');
    final stockMinCtrl = TextEditingController(text: '5');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
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
              Text(
                'Nuevo Medicamento',
                style: Theme.of(ctx).textTheme.headlineMedium,
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
                  final provider = Provider.of<MedicationProvider>(context, listen: false);
                  final success = await provider.createMedication(
                    nombre: nombreCtrl.text.trim(),
                    dosis: dosisCtrl.text.trim(),
                    frecuenciaHoras: int.tryParse(frecuenciaCtrl.text.trim()) ?? 12,
                    horaInicio: horaCtrl.text.trim(),
                    stockActual: int.tryParse(stockCtrl.text.trim()) ?? 30,
                    stockMinimoAlerta: int.tryParse(stockMinCtrl.text.trim()) ?? 5,
                  );
                  if (!mounted) return;
                  if (success) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medicamento guardado en el pastillero 🎉')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
                child: const Text('GUARDAR MEDICAMENTO'),
              ),
            ],
          ),
        );
      },
    );
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
                    await Provider.of<HealthProvider>(context, listen: false).fetchHealthData();
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
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                letterSpacing: 1.1,
                              ),
                            ),
                            IconButton(
                              onPressed: _showAddMedicationModal,
                              tooltip: 'Añadir Medicamento',
                              icon: const Icon(Icons.add_circle_rounded, color: AppColors.primaryBlue, size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Filter Chips: Todos / Mañana / Tarde / Noche
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Todos', '📋 Todos', medProvider, isDark),
                              const SizedBox(width: 8),
                              _buildFilterChip('Mañana', '🌅 Mañana', medProvider, isDark),
                              const SizedBox(width: 8),
                              _buildFilterChip('Tarde', '☀️ Tarde', medProvider, isDark),
                              const SizedBox(width: 8),
                              _buildFilterChip('Noche', '🌙 Noche', medProvider, isDark),
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
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.medication_liquid_rounded,
                                  size: 44,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay tomas programadas en este turno.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final m = meds[idx];
                              return _buildMedicationListItem(m, medProvider, isDark);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  bool _doseConfirmed = false;

  Widget _buildHeroCard(Map<String, dynamic>? proximo, MedicationProvider provider, bool isDark) {
    // Si no hay medicamentos en el pastillero
    if (provider.medications.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
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
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medication_outlined, color: AppColors.primaryBlue, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              'Pastillero Vacío',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No tienes medicamentos registrados aún.\nToca el botón "+" para agregar tu primer medicamento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    final title = proximo != null ? proximo['nombre'] : provider.medications.first.nombre;
    final dosis = proximo != null ? (proximo['dosis'] ?? '1 tableta') : provider.medications.first.dosis;
    final horaFormateada = proximo != null ? (proximo['hora_formateada'] as String?) : null;
    final infoHorario = horaFormateada != null ? '$horaFormateada • $dosis' : dosis;
    final medId = proximo != null ? proximo['medicamento_id'] : provider.medications.first.id;

    final isAlreadyTaken = medId != null && provider.isDoseTakenRecently(medId.toString());

    if (_doseConfirmed || isAlreadyTaken) {
      final lastToma = medId != null ? provider.getUltimaToma(medId.toString()) : null;
      String lastHoraStr = 'hoy';
      if (lastToma?.fechaHoraConfirmacion != null) {
        try {
          final dt = DateTime.parse(lastToma!.fechaHoraConfirmacion!).toLocal();
          final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          final min = dt.minute.toString().padLeft(2, '0');
          lastHoraStr = '$hour:$min $ampm';
        } catch (_) {}
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.successGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.successGreen.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.successGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              '¡Dosis de este Turno Tomada!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Confirmada a las $lastHoraStr para $title.\nEl botón se reactivará automáticamente en la próxima toma.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_clock_rounded, size: 18, color: AppColors.successGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Bloqueo activo contra tomas duplicadas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Determinar color dinámico según la hora del día (Mañana / Tarde / Noche)
    final nowHour = DateTime.now().hour;
    final Color scheduleColor = (nowHour >= 5 && nowHour < 12)
        ? AppColors.morningBlue // 🌅 Mañana (Azul Cielo Fresco)
        : (nowHour >= 12 && nowHour < 18)
            ? AppColors.afternoonOrange // ☀️ Tarde (Ámbar / Naranja Cálido)
            : AppColors.nightIndigo; // 🌙 Noche (Índigo Noche Relajante)

    final String scheduleLabel = (nowHour >= 5 && nowHour < 12)
        ? '🌅 DOSIS DE LA MAÑANA'
        : (nowHour >= 12 && nowHour < 18)
            ? '☀️ DOSIS DE LA TARDE'
            : '🌙 DOSIS DE LA NOCHE';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheduleColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: scheduleColor.withValues(alpha: isDark ? 0.1 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: scheduleColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  scheduleLabel,
                  style: TextStyle(
                    color: scheduleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheduleColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            infoHorario,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),

          // Action Button: ¡YA LA TOMÉ! con color dinámico de turno
          ElevatedButton.icon(
            onPressed: () async {
              if (medId != null) {
                final ok = await provider.registrarToma(medId.toString(), 'tomado');
                if (!mounted) return;
                if (ok) {
                  setState(() {
                    _doseConfirmed = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Excelente! Toma registrada y protegida contra duplicados 🎉'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Agrega un medicamento al pastillero primero')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: scheduleColor,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 2,
            ),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
            label: const Text(
              '¡YA LA TOMÉ!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary button: Remind in 15 min
          OutlinedButton.icon(
            onPressed: () {
              InAppNotificationService().show(
                title: '⏰ Recordatorio Pospuesto',
                message: 'Te avisaremos de nuevo en 15 minutos para tomar $title ($dosis).',
                type: TopNotificationType.medicationReminder,
                actionLabel: 'ENTENDIDO',
                onAction: () {},
                duration: const Duration(seconds: 5),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(
              Icons.history_toggle_off_rounded,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: 20,
            ),
            label: Text(
              'Recordarme en 15 minutos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, MedicationProvider provider, bool isDark) {
    final isSelected = provider.selectedFilter == key;
    return GestureDetector(
      onTap: () => provider.setFilter(key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.cardDark : Colors.white),
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
                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationListItem(dynamic m, MedicationProvider provider, bool isDark) {
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
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$hora • $dosisTxt',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: isLowStock ? AppColors.sosRed : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stock: $stock pastillas ${isLowStock ? "(¡Stock Bajo!)" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLowStock ? FontWeight.bold : FontWeight.w500,
                        color: isLowStock ? AppColors.sosRed : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: 24,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    const Icon(Icons.edit_rounded, size: 20, color: AppColors.primaryBlue),
                    const SizedBox(width: 10),
                    Text(
                      'Editar dosis / stock',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.sosRed),
                    SizedBox(width: 10),
                    Text(
                      'Eliminar pastilla',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.sosRed),
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
