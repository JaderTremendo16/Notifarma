import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notifarma_app/core/providers/theme_provider.dart';
import 'package:notifarma_app/core/utils/date_formatter.dart';
import 'package:notifarma_app/features/auth/providers/auth_provider.dart';
import 'package:notifarma_app/shared/widgets/theme_toggle_switch.dart';

class SeniorHeader extends StatefulWidget {
  final String subtitle;

  const SeniorHeader({super.key, required this.subtitle});

  @override
  State<SeniorHeader> createState() => _SeniorHeaderState();
}

class _SeniorHeaderState extends State<SeniorHeader> {
  Timer? _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Live update every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userName = authProvider.user?.nombres ?? 'Don Carlos';
    final initials = authProvider.userInitials;
    final isDark = themeProvider.isDarkMode;
    final nowStr = DateFormatter.formatHeaderDateTime(_currentTime);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], // Soft ocean gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF1D4ED8)).withValues(alpha: isDark ? 0.35 : 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top line: Live Date/time and Smooth Theme Toggle Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    nowStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
          const SizedBox(height: 18),

          // Main Greeting & Circle Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola,\n$userName!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
