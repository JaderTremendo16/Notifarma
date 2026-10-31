import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/utils/pdf_downloader.dart';
import 'package:notifarma_app/features/auth/presentation/widgets/link_code_dialog.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/dashboard/presentation/screens/main_shell_screen.dart';
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
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.circle, size: 8, color: AppColors.afternoonOrange),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${a['nombre']} • Quedan ${a['stock_actual']} pastillas',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )),
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
