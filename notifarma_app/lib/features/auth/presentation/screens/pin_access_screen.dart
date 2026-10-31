import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/shared/widgets/senior_header.dart';

class PinAccessScreen extends StatelessWidget {
  final VoidCallback onPinSuccess;

  const PinAccessScreen({super.key, required this.onPinSuccess});

  void _callEmergencyContact(BuildContext context, String? name, String? phone) async {
    final contactName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Contacto de Emergencia';
    final targetPhone = (phone != null && phone.trim().isNotEmpty) ? phone.trim() : '123';
    final cleanNumber = targetPhone.replaceAll(RegExp(r'\s+|-'), '').trim();

    final Uri url = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!context.mounted) return;
        _showSnackBar(context, 'No se pudo abrir el marcador para llamar a $contactName ($cleanNumber).', isError: true);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, 'No se pudo abrir el marcador para llamar a $contactName ($cleanNumber).', isError: true);
    }
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 3),
        backgroundColor: isError ? AppColors.sosRed : AppColors.primaryBlue,
      ),
    );
  }

  void _showLoginModal(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

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
                'Iniciar Sesión',
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final success = await authProvider.login(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  if (success) {
                    Navigator.pop(ctx);
                    onPinSuccess();
                  } else {
                    if (!context.mounted) return;
                    _showSnackBar(context, authProvider.errorMessage ?? 'Error al iniciar sesión');
                  }
                },
                child: const Text('INGRESAR'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final pin = authProvider.enteredPin;

    return Column(
      children: [
        const SeniorHeader(subtitle: 'Acceso Seguro con PIN'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'MARQUE SU CLAVE DE 4 DÍGITOS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),

                // PIN Indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppColors.primaryBlue : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? AppColors.primaryBlue : AppColors.borderGrey,
                          width: 3,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Keypad 3x4 Grid
                Column(
                  children: [
                    _buildRow(context, ['1', '2', '3']),
                    const SizedBox(height: 12),
                    _buildRow(context, ['4', '5', '6']),
                    const SizedBox(height: 12),
                    _buildRow(context, ['7', '8', '9']),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Fingerprint button
                        _buildActionKey(
                          context,
                          icon: Icons.fingerprint_rounded,
                          label: 'HUELLA',
                          borderColor: AppColors.primaryBlue,
                          textColor: AppColors.primaryBlue,
                          onTap: () {
                            onPinSuccess();
                          },
                        ),
                        // Number 0
                        _buildNumberKey(context, '0'),
                        // Erase button
                        _buildActionKey(
                          context,
                          icon: Icons.cancel_outlined,
                          label: 'BORRAR',
                          borderColor: AppColors.sosRed.withValues(alpha: 0.3),
                          textColor: AppColors.sosRed,
                          onTap: () {
                            authProvider.removePinDigit();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Emergency Call button
                OutlinedButton.icon(
                  onPressed: () {
                    _callEmergencyContact(
                      context,
                      authProvider.user?.contactoEmergenciaNombre,
                      authProvider.user?.contactoEmergenciaTelefono,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primaryBlue),
                  label: Text(
                    '¿Olvidó su clave? Llamar a ${authProvider.user?.contactoEmergenciaNombre ?? "María"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Traditional Login / Switch user button
                TextButton(
                  onPressed: () => _showLoginModal(context),
                  child: const Text(
                    'Ingresar con Correo y Contraseña',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberKey(context, n)).toList(),
    );
  }

  Widget _buildNumberKey(BuildContext context, String number) {
    return Container(
      width: 90,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            authProvider.appendPinDigit(number);
            if (authProvider.enteredPin.length == 4) {
              onPinSuccess();
            }
          },
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 90,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
