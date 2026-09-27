import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/utils/pdf_downloader.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/medications/data/repositories/medication_repository.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final MedicationRepository _medRepo = MedicationRepository();
  List<dynamic> _auditoriaLogs = [];
  bool _loadingAudit = false;

  @override
  void initState() {
    super.initState();
    _loadAuditoria();
  }

  void _loadAuditoria() async {
    setState(() => _loadingAudit = true);
    try {
      final logs = await _medRepo.getAuditoriaClinica();
      if (mounted) {
        setState(() {
          _auditoriaLogs = logs;
          _loadingAudit = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAudit = false);
    }
  }

  bool _downloadingPdf = false;

  void _downloadAdherencePdf(BuildContext context) async {
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await _medRepo.downloadAdherencePdf(dias: 30);
      if (bytes.isNotEmpty) {
        await PdfDownloader.downloadPdfBytes(bytes, 'reporte_adherencia_notifarma.pdf');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Reporte PDF descargado y generado con éxito! 📄'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } else {
        throw Exception('El archivo recibido está vacío');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar reporte: $e'),
          backgroundColor: AppColors.sosRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    return Column(
      children: [
        const SeniorHeader(subtitle: 'Mi Perfil y Reportes'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CARD 1: User Profile Details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
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
                          Text(
                            'Información Personal',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              (user?.rol ?? 'PACIENTE').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      _buildInfoRow(Icons.person_rounded, 'Nombre Completo', user?.nombres ?? 'Usuario', isDark),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.email_rounded, 'Correo Electrónico', user?.email ?? 'correo@ejemplo.com', isDark),
                      if (user?.edad != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.cake_rounded, 'Edad', '${user!.edad} años', isDark),
                      ],
                      if (user?.contactoEmergenciaNombre != null && user!.contactoEmergenciaNombre!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.contact_phone_rounded,
                          'Contacto de Emergencia',
                          '${user.contactoEmergenciaNombre} (${user.contactoEmergenciaTelefono ?? "Sin tel."})',
                          isDark,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CARD 2: Reporte Clínico en PDF (Hora Local)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, color: AppColors.sosRed, size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Informe Clínico Oficial (PDF)',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Genera el documento PDF formal con el porcentaje de adherencia médica y horarios ajustados a la zona local para tu consulta médica.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _downloadingPdf ? null : () => _downloadAdherencePdf(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sosRed,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _downloadingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded, color: Colors.white),
                        label: Text(
                          _downloadingPdf ? 'DESCARGANDO REPORTE...' : 'DESCARGAR REPORTE PDF',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CARD 3: Auditoría Clínica y Trazabilidad Médica (Backend endpoint /medications/auditoria)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_edu_rounded, color: AppColors.primaryBlue, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Auditoría y Trazabilidad',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: _loadAuditoria,
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registro cronológico de quién tomó o recargó medicamentos en el sistema:',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loadingAudit)
                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                      else if (_auditoriaLogs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No hay eventos de auditoría registrados todavía.',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _auditoriaLogs.length > 5 ? 5 : _auditoriaLogs.length,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 16,
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                          itemBuilder: (ctx, i) {
                            final item = _auditoriaLogs[i];
                            final accion = item['accion'] ?? 'EVENTO';
                            final detalle = item['detalle'] ?? '';
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accion == 'REGISTRO_TOMA'
                                        ? AppColors.successGreen.withValues(alpha: 0.12)
                                        : AppColors.accentOrange.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    accion == 'REGISTRO_TOMA' ? Icons.check_circle_outline : Icons.inventory_2_outlined,
                                    size: 16,
                                    color: accion == 'REGISTRO_TOMA' ? AppColors.successGreen : AppColors.accentOrange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        accion,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      if (detalle.isNotEmpty)
                                        Text(
                                          detalle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () => authProvider.logout(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.sosRed),
                  label: const Text(
                    'CERRAR SESIÓN',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.sosRed),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
