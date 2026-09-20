import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/shared/widgets/theme_toggle_switch.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    final isPaciente = (user?.rol.toLowerCase() == 'paciente');
    final roleName = isPaciente ? 'PACIENTE / ADULTO MAYOR' : 'CUIDADOR FAMILIAR';
    final roleColor = isPaciente ? AppColors.primaryBlue : AppColors.accentOrange;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with App Name & Theme Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'NOTIFARMA',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  ThemeToggleSwitch(
                    isDark: isDark,
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Success Icon & Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.successGreen.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.successGreen,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¡Ingreso Exitoso!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Autenticación correcta con el servidor',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // User Info & Role Badge
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Perfil Activo',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              roleName,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        icon: Icons.person_rounded,
                        label: 'Nombre',
                        value: user?.nombres ?? 'Usuario',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.email_rounded,
                        label: 'Correo',
                        value: user?.email ?? 'correo@ejemplo.com',
                        isDark: isDark,
                      ),
                      if (user?.edad != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.cake_rounded,
                          label: 'Edad',
                          value: '${user!.edad} años',
                          isDark: isDark,
                        ),
                      ],
                      if (user?.contactoEmergenciaNombre != null &&
                          user!.contactoEmergenciaNombre!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          icon: Icons.phone_in_talk_rounded,
                          label: 'Contacto de Emergencia',
                          value:
                              '${user.contactoEmergenciaNombre} (${user.contactoEmergenciaTelefono ?? "Sin tel."})',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Logout Button
              OutlinedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, color: AppColors.sosRed),
                label: Text(
                  'CERRAR SESIÓN',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sosRed,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
