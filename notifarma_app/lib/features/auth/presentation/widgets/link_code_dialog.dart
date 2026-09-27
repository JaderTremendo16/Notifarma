import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';

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
    setState(() {
      _generatedCode = code;
      _isLoading = false;
    });
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Vinculación familiar exitosa! 🎉'),
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
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Text(
                    'GENERAR MI CÓDIGO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 8),
                  if (_generatedCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue, width: 2),
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
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0),
              decoration: InputDecoration(
                hintText: 'Ej: NF-4829',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _redeemCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('VINCULAR AHORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
