import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/medications/providers/medication_provider.dart';
import 'package:notifarma_app/features/health/providers/health_provider.dart';
import 'package:notifarma_app/shared/widgets/top_notification_banner.dart';

class LinkCodeDialog extends StatefulWidget {
  const LinkCodeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const LinkCodeDialog(),
    );
  }

  @override
  State<LinkCodeDialog> createState() => _LinkCodeDialogState();
}

class _LinkCodeDialogState extends State<LinkCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  String? _generatedCode;
  bool _isLoading = false;

  void _generateCode() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final code = await auth.generarCodigoVinculacion();
    if (!mounted) return;
    setState(() {
      _generatedCode = code;
      _isLoading = false;
    });
    if (code == null) {
      InAppNotificationService().show(
        title: 'No se pudo generar el código',
        message:
            auth.errorMessage ??
            'Revisa tu vínculo familiar o inténtalo nuevamente.',
        type: TopNotificationType.sosAlert,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.vincularPorCodigo(code);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      await Future.wait([
        Provider.of<MedicationProvider>(
          context,
          listen: false,
        ).fetchMedicationsData(),
        Provider.of<HealthProvider>(context, listen: false).fetchHealthData(),
      ]);
      if (!mounted) return;

      Navigator.pop(context);
      InAppNotificationService().show(
        title: 'Vinculación completada',
        message:
            'La información se actualizará automáticamente en esta pantalla.',
        type: TopNotificationType.info,
        duration: const Duration(seconds: 4),
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
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final hasLinkedFamily =
        user?.cuidadorNombre?.isNotEmpty == true ||
        user?.pacienteNombre?.isNotEmpty == true;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.link_rounded, color: AppColors.primaryBlue, size: 28),
          SizedBox(width: 10),
          Text(
            'Vincular Familiar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Usa un código corto de 6 caracteres para conectar paciente y cuidador sin necesidad de correos largos.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),

            // Option 1: Generate Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'GENERAR MI CÓDIGO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasLinkedFamily) ...[
                    const Text(
                      'Esta cuenta ya tiene un vínculo familiar activo y no puede enlazar otro paciente o cuidador.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (_generatedCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _generatedCode!,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryBlue,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Válido por 24 horas. Dáselo a tu familiar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateCode,
                      icon: const Icon(Icons.qr_code_rounded),
                      label: const Text('Generar Código'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Option 2: Enter Code
            const Text(
              'O INGRESA EL CÓDIGO DE TU FAMILIAR:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              enabled: !_isLoading && !hasLinkedFamily,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
              decoration: InputDecoration(
                hintText: 'Ej: NF-4829',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading || hasLinkedFamily ? null : _redeemCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'VINCULAR AHORA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CERRAR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
