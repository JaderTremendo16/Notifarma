import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';

class FamilyLinkScreen extends StatefulWidget {
  const FamilyLinkScreen({super.key});

  @override
  State<FamilyLinkScreen> createState() => _FamilyLinkScreenState();
}

class _FamilyLinkScreenState extends State<FamilyLinkScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _myGeneratedCode;
  bool _isLoading = false;

  void _generateCode() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final code = await auth.generarCodigoVinculacion();
    setState(() {
      _myGeneratedCode = code;
      _isLoading = false;
    });
  }

  void _cancelCode() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.cancelarCodigoVinculacion();
    setState(() {
      if (ok) _myGeneratedCode = null;
      _isLoading = false;
    });

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código de vinculación cancelado con éxito 🗑️'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    }
  }

  void _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.vincularPorCodigo(code);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (ok) {
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Vinculación familiar completada con éxito! 🎉'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Código inválido o expirado'),
          backgroundColor: AppColors.sosRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;
    final isPaciente = user?.rol.toLowerCase() == 'paciente';
    final targetRole = isPaciente ? 'Cuidador Familiar' : 'Paciente / Familiar';

    return Column(
      children: [
        const SeniorHeader(subtitle: 'Vinculación y Red de Cuidado'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.diversity_3_rounded, color: AppColors.primaryBlue, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaciente ? 'Tu Red de Apoyo' : 'Tu Paciente Asignado',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Conecta a tu $targetRole usando códigos cortos de 6 caracteres (ej: NF-4829).',
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
                const SizedBox(height: 20),

                // CARD 1: GENERAR MI CÓDIGO
                Text(
                  'COMPARTIR MI CÓDIGO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      if (_myGeneratedCode != null) ...[
                        const Text(
                          'Tu código activo para entregar:',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryBlue, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _myGeneratedCode!,
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryBlue,
                                  letterSpacing: 3.0,
                                ),
                              ),
                              const SizedBox(width: 14),
                              IconButton(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _myGeneratedCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Código copiado al portapapeles 📋')),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, color: AppColors.primaryBlue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '⏱ Válido por 24 horas.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _cancelCode,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.sosRed,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            'Cancelar y quitar este código',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Presiona el botón para generar un código que tu familiar pueda escanear o digitar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _generateCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
                          label: const Text('GENERAR CÓDIGO DE ENLACE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // CARD 2: INGRESAR CÓDIGO DE FAMILIAR
                Text(
                  'CANJEAR CÓDIGO DE MI FAMILIAR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Si tu familiar ya generó un código, escríbelo aquí para enlazar de inmediato:',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'NF-XXXX',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            letterSpacing: 2.0,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _redeemCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('ENLAZAR FAMILIAR AHORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
