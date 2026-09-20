import 'package:flutter/material.dart';
import 'package:notifarma_app/core/services/notification_service.dart';
import 'package:notifarma_app/features/auth/presentation/screens/pin_access_screen.dart';
import 'package:notifarma_app/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:notifarma_app/features/health/presentation/screens/wellness_screen.dart';
import 'package:notifarma_app/features/medications/presentation/screens/medication_plan_screen.dart';
import 'package:notifarma_app/shared/widgets/floating_bottom_nav_bar.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 1; // Default to BOTICA / Medication plan

  @override
  void initState() {
    super.initState();
    // Initialize Local Notifications and Periodic Polling
    NotificationService().initialize();
    NotificationService().startPolling();
  }

  @override
  void dispose() {
    NotificationService().stopPolling();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      PinAccessScreen(onPinSuccess: () => _onTabTapped(1)),
      const MedicationPlanScreen(),
      HomeDashboardScreen(onNavigateTab: _onTabTapped),
      const WellnessScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          // Active Tab Body Screen
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),

          // iOS Style Floating Dock Bottom Navigation Bar (Image 4)
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
