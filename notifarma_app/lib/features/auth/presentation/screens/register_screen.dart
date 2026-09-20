import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/shared/widgets/theme_toggle_switch.dart';
import 'package:notifarma_app/shared/widgets/uiverse_loader.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _edadController = TextEditingController();
  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();

  String _selectedRole = 'paciente'; // 'paciente' or 'cuidador'
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nombresController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _edadController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final edad = int.tryParse(_edadController.text.trim());

    final success = await authProvider.register(
      nombres: _nombresController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      rol: _selectedRole,
      edad: _selectedRole == 'paciente' ? edad : null,
      contactoEmergenciaNombre: _selectedRole == 'paciente' ? _contactoNombreController.text.trim() : null,
      contactoEmergenciaTelefono: _selectedRole == 'paciente' ? _contactoTelefonoController.text.trim() : null,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context); // Return to main flow which will show RoleHomeScreen
    } else if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage!,
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
          ),
          backgroundColor: AppColors.sosRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isLoading = authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ThemeToggleSwitch(
              isDark: isDark,
              onChanged: (val) => themeProvider.toggleTheme(val),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crear Cuenta',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Seleccione su perfil y complete la información',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                // Role Selection Pills
                Text(
                  '¿Cuál es su rol en Notifarma?',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        role: 'paciente',
                        label: 'Adulto Mayor\n(Paciente)',
                        icon: Icons.person_rounded,
                        isSelected: _selectedRole == 'paciente',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildRoleCard(
                        role: 'cuidador',
                        label: 'Cuidador\nFamiliar',
                        icon: Icons.volunteer_activism_rounded,
                        isSelected: _selectedRole == 'cuidador',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Registration Form Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombres Completos',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nombresController,
                          style: GoogleFonts.outfit(fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'Ej. Juan Pérez',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingrese sus nombres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Correo Electrónico',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.outfit(fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'juan@correo.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingrese su correo';
                            }
                            if (!value.contains('@')) {
                              return 'Correo inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'Contraseña',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.outfit(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),

                        // Fields shown only if role is 'paciente'
                        if (_selectedRole == 'paciente') ...[
                          const SizedBox(height: 14),
                          Text(
                            'Edad (Años)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _edadController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.outfit(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Ej. 72',
                              prefixIcon: Icon(Icons.cake_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Nombre de Contacto de Emergencia',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _contactoNombreController,
                            style: GoogleFonts.outfit(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Ej. María Pérez (Hija)',
                              prefixIcon: Icon(Icons.contact_phone_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Teléfono de Emergencia',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _contactoTelefonoController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.outfit(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Ej. 3001234567',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Register Action / UIverse Loader
                ElevatedButton(
                  onPressed: isLoading ? null : _handleRegister,
                  child: isLoading
                      ? const UiverseLoader(
                          text: 'Registrando...',
                          textColor: Colors.white,
                        )
                      : Text(
                          'REGISTRARSE',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primaryBlue)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
