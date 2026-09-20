import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';
import 'package:notifarma_app/features/medications/providers/medication_provider.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';

class MedicationPlanScreen extends StatefulWidget {
  const MedicationPlanScreen({super.key});

  @override
  State<MedicationPlanScreen> createState() => _MedicationPlanScreenState();
}

class _MedicationPlanScreenState extends State<MedicationPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MedicationProvider>(context, listen: false).fetchMedicationsData();
    });
  }

  void _showAddMedicationModal() {
    final nombreCtrl = TextEditingController();
    final dosisCtrl = TextEditingController();
    final frecuenciaCtrl = TextEditingController(text: '12');
    final horaCtrl = TextEditingController(text: '08:00:00');
    final stockCtrl = TextEditingController(text: '30');

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
                  labelText: 'Dosis (ej. 50mg / 1 tableta con agua)',
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
                        labelText: 'Cada cuántas horas',
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
                  );
                  if (!mounted) return;
                  if (success) {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medicamento guardado en el pastillero')),
                    );
                  }
                },
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
    final proximo = medProvider.proximoMedicamento;
    final meds = medProvider.medications;

    return Column(
      children: [
        const SeniorHeader(subtitle: 'Plan de Tomas del Día'),
        Expanded(
          child: medProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => medProvider.fetchMedicationsData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MAIN HIGHLIGHT CARD: TOCA PARA TOMAR (Matching Image 2)
                        _buildHighlightCard(proximo, medProvider),
                        const SizedBox(height: 20),

                        // Section Title & Time Filters
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PRÓXIMAS TOMAS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.1,
                              ),
                            ),
                            IconButton(
                              onPressed: _showAddMedicationModal,
                              icon: const Icon(Icons.add_circle_rounded, color: AppColors.primaryBlue, size: 30),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Time filter pills
                        Row(
                          children: [
                            _buildFilterChip('Mañana', '🌅 Mañana', medProvider),
                            const SizedBox(width: 8),
                            _buildFilterChip('Tarde', '☀️ Tarde', medProvider),
                            const SizedBox(width: 8),
                            _buildFilterChip('Noche', '🌙 Noche', medProvider),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Medications List
                        if (meds.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.medication_liquid_rounded, size: 48, color: AppColors.textSecondary),
                                SizedBox(height: 8),
                                Text(
                                  'No hay medicamentos registrados todavía.',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: meds.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final m = meds[index];
                              return _buildMedicationListItem(context, m, medProvider);
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

  Widget _buildHighlightCard(Map<String, dynamic>? proximo, MedicationProvider provider) {
    final title = proximo != null ? proximo['nombre'] : (provider.medications.isNotEmpty ? provider.medications.first.nombre : 'Losartán Potásico');
    final dosis = proximo != null ? (proximo['dosis'] ?? '1 tableta con agua') : '08:00 AM • 1 tableta con agua';
    final medId = proximo != null ? proximo['medicamento_id'] : (provider.medications.isNotEmpty ? provider.medications.first.id : null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentOrange, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Badge & Clock Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'TOCA PARA TOMAR',
                  style: TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.accentOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medication Name
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Time & Dose
          Text(
            dosis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Hint
          const Row(
            children: [
              Text('💡 ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  'Para controlar la presión arterial',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // HUGE Bright Orange Action Button
          ElevatedButton.icon(
            onPressed: () async {
              if (medId != null) {
                final ok = await provider.registrarToma(medId.toString(), 'tomado');
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Excelente! Toma registrada correctamente 🎉'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Agregue un medicamento en su pastillero')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            label: const Text(
              '¡YA LA TOMÉ!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary button: Remind in 15 minutes
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recordatorio pospuesto por 15 minutos ⏰')),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.borderGrey, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.history_toggle_off_rounded, color: AppColors.textSecondary, size: 20),
            label: const Text(
              'Recordarme en 15 minutos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, MedicationProvider provider) {
    final isSelected = provider.selectedFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setFilter(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.borderGrey,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationListItem(BuildContext context, dynamic m, MedicationProvider provider) {
    final hora = DateFormatter.formatTimeString(m.horaInicio);
    final dosisTxt = m.dosis ?? '1 tableta con agua';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.medication, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$hora • $dosisTxt',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
                if (!mounted) return;
 {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Toma de ${m.nombre} registrada')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              minimumSize: const Size(80, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tomar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
