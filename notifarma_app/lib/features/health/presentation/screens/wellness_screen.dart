import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/health/providers/health_provider.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';
import 'package:notifarma_app/shared/widgets/top_notification_banner.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HealthProvider>(context, listen: false).fetchHealthData();
    });
  }

  void _hacerLlamada(
    BuildContext context,
    String numero,
    String destinatario,
  ) async {
    final cleanNumber = numero.replaceAll(RegExp(r'\s+|-'), '').trim();
    if (cleanNumber.isEmpty) {
      _showSnackBar(
        context,
        'No hay un número válido configurado para $destinatario.',
        isError: true,
      );
      return;
    }

    final Uri url = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!context.mounted) return;
        _showSnackBar(
          context,
          'No se pudo abrir el marcador para llamar a $destinatario ($cleanNumber).',
          isError: true,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'No se pudo abrir el marcador para llamar a $destinatario ($cleanNumber).',
        isError: true,
      );
    }
  }

  void _callEmergencyContact(
    BuildContext context,
    String? name,
    String? phone,
  ) {
    final contactName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : 'Contacto de Emergencia';
    final targetPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : '123';
    _hacerLlamada(context, targetPhone, contactName);
  }

  void _triggerSosAlert(BuildContext context, String? name, String? phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.sosRed,
              size: 32,
            ),
            SizedBox(width: 10),
            Text(
              '¡ALERTA SOS!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.sosRed,
              ),
            ),
          ],
        ),
        content: const Text(
          'Se activará la llamada directa a emergencias (123). ¿Desea realizar la llamada de auxilio ahora mismo?',
          style: TextStyle(fontSize: 18),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _hacerLlamada(context, '123', 'Línea de Emergencia (123)');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
            label: const Text(
              'LLAMAR AL 123',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 3),
        backgroundColor: isError ? AppColors.sosRed : AppColors.primaryBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthProvider = Provider.of<HealthProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final recommendation = healthProvider.recomendacionHoy;
    final selectedMood = healthProvider.selectedMood;
    final contactName =
        authProvider.user?.contactoEmergenciaNombre ?? 'María (Hija)';
    final contactPhone = authProvider.user?.contactoEmergenciaTelefono;

    return Column(
      children: [
        const SeniorHeader(subtitle: 'Seguimiento de Bienestar'),
        Expanded(
          child: healthProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => healthProvider.fetchHealthData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header: CHEQUEO DE BIENESTAR
                        Text(
                          'CHEQUEO DE BIENESTAR',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¿Cómo se siente en este momento?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Mood options use the existing palette instead of platform-dependent emoji glyphs.
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildMoodOption(
                                context,
                                'muy_bien',
                                Icons.sentiment_very_satisfied_rounded,
                                'Muy bien',
                                selectedMood,
                                healthProvider,
                                isDark,
                              ),
                              const SizedBox(width: 10),
                              _buildMoodOption(
                                context,
                                'bien',
                                Icons.sentiment_satisfied_rounded,
                                'Bien',
                                selectedMood,
                                healthProvider,
                                isDark,
                              ),
                              const SizedBox(width: 10),
                              _buildMoodOption(
                                context,
                                'regular',
                                Icons.sentiment_neutral_rounded,
                                'Regular',
                                selectedMood,
                                healthProvider,
                                isDark,
                              ),
                              const SizedBox(width: 10),
                              _buildMoodOption(
                                context,
                                'mal',
                                Icons.sentiment_dissatisfied_rounded,
                                'Mal',
                                selectedMood,
                                healthProvider,
                                isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // TARJETA DE RECOMENDACIÓN DE SALUD REAL
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.03,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.tips_and_updates_rounded,
                                      color: AppColors.primaryBlue,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CONSEJO DE BIENESTAR',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Recomendación del día',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.shield_outlined,
                                      color: AppColors.primaryBlue,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        recommendation,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // QUICK CONTACTS
                        Text(
                          'CONTACTOS RÁPIDOS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _callEmergencyContact(
                              context,
                              contactName,
                              contactPhone,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.phone_in_talk_rounded,
                                    color: AppColors.primaryBlue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Llamar a $contactName',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SOS EMERGENCY BUTTON (Matching Image 2)
                        GestureDetector(
                          onLongPress: () => _triggerSosAlert(
                            context,
                            contactName,
                            contactPhone,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sosRed,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sosRed.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'BOTÓN DE AUXILIO SOS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Mantenga presionado 2 segundos',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMoodOption(
    BuildContext context,
    String animoValue,
    IconData icon,
    String label,
    String? currentSelected,
    HealthProvider provider,
    bool isDark,
  ) {
    final isSelected = currentSelected == animoValue;

    return GestureDetector(
      onTap: provider.isRecordingMood
          ? null
          : () async {
              final ok = await provider.recordMood(animoValue);
              if (!context.mounted) return;
              if (ok) {
                InAppNotificationService().show(
                  title: 'Estado guardado',
                  message: 'Registramos cómo te sientes: $label.',
                  type: TopNotificationType.info,
                  duration: const Duration(seconds: 3),
                );
              } else {
                _showSnackBar(
                  context,
                  provider.errorMessage ??
                      'No se pudo guardar el estado de ánimo.',
                  isError: true,
                );
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryBlue.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                key: ValueKey('$animoValue-$isSelected'),
                size: 32,
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
