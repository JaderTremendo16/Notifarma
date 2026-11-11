import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/config/app_theme.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/services/notification_service.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/features/auth/presentation/screens/family_link_screen.dart';
import 'package:notifarma_app/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:notifarma_app/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:notifarma_app/features/health/presentation/screens/wellness_screen.dart';
import 'package:notifarma_app/features/health/providers/health_provider.dart';
import 'package:notifarma_app/features/medications/providers/medication_provider.dart';
import 'package:notifarma_app/shared/widgets/floating_bottom_nav_bar.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0; // Default to INICIO (Unified Dashboard)
  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize Local Notifications and Periodic Polling
    NotificationService().initialize();
    NotificationService().startPolling();
    _startSyncTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLinkedData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    NotificationService().stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSyncTimer();
      _refreshLinkedData();
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshLinkedData(),
    );
  }

  Future<void> _refreshLinkedData() async {
    if (!mounted || _isSyncing) return;
    final auth = context.read<AuthProvider>();
    if (auth.status != AuthStatus.authenticated) return;

    _isSyncing = true;
    try {
      await auth.refreshProfile();
      if (!mounted || auth.user?.rol.toLowerCase() != 'paciente') return;
      await Future.wait([
        context.read<MedicationProvider>().fetchMedicationsData(silent: true),
        context.read<HealthProvider>().fetchHealthData(silent: true),
      ]);
    } finally {
      _isSyncing = false;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      UnifiedHomeDashboardScreen(
        onNavigateTab: _onTabTapped,
      ), // Tab 0: INICIO & BOTICA
      const WellnessScreen(), // Tab 1: SALUD & BIENESTAR
      const FamilyLinkScreen(), // Tab 2: VINCULACIÓN FAMILIAR (Código NF-4829)
      const ProfileScreen(), // Tab 3: PERFIL, AUDITORÍA & REPORTES PDF
    ];

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Active Tab Body Screen
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),

          // Floating Dock Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}
