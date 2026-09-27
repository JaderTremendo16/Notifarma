import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/features/auth/presentation/screens/login_screen.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/dashboard/presentation/screens/role_home_screen.dart';
import 'package:notifarma_app/features/health/providers/health_provider.dart';
import 'package:notifarma_app/features/medications/providers/medication_provider.dart';
import 'package:notifarma_app/shared/widgets/top_notification_banner.dart';
import 'package:notifarma_app/shared/widgets/uiverse_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotiFarmaApp());
}

class NotiFarmaApp extends StatelessWidget {
  const NotiFarmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'NotiFarma',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeAnimationDuration: const Duration(milliseconds: 450),
            themeAnimationCurve: Curves.easeInOutCubic,
            builder: (context, child) => TopNotificationBannerOverlay(child: child ?? const SizedBox.shrink()),
            home: const RootNavigationRouter(),
          );
        },
      ),
    );
  }
}

class RootNavigationRouter extends StatelessWidget {
  const RootNavigationRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Initial check or loading state
    if (authProvider.status == AuthStatus.authenticating && authProvider.user == null) {
      return const Scaffold(
        body: Center(
          child: UiverseLoader(text: 'Iniciando Notifarma...'),
        ),
      );
    }

    // Authenticated state -> Direct to Role Screen
    if (authProvider.status == AuthStatus.authenticated) {
      return const RoleHomeScreen();
    }

    // Unauthenticated -> Login Screen
    return const LoginScreen();
  }
}
