import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notifarma_app/core/config/app_theme.dart';

enum TopNotificationType {
  medicationReminder,
  stockAlert,
  familyLink,
  sosAlert,
  info,
}

class TopNotificationItem {
  final String id;
  final String title;
  final String message;
  final TopNotificationType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  TopNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type = TopNotificationType.medicationReminder,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 5),
  });
}

class InAppNotificationService extends ChangeNotifier {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  TopNotificationItem? _currentNotification;
  Timer? _dismissTimer;

  TopNotificationItem? get currentNotification => _currentNotification;

  void show({
    required String title,
    required String message,
    TopNotificationType type = TopNotificationType.medicationReminder,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    _dismissTimer?.cancel();
    _currentNotification = TopNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
    notifyListeners();

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    if (_currentNotification != null) {
      _currentNotification = null;
      notifyListeners();
    }
  }
}

class TopNotificationBannerOverlay extends StatelessWidget {
  final Widget child;

  const TopNotificationBannerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InAppNotificationService(),
      builder: (context, _) {
        final current = InAppNotificationService().currentNotification;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          children: [
            child,
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              top: current != null ? MediaQuery.of(context).padding.top + 10 : -140,
              left: 16,
              right: 16,
              child: Material(
                type: MaterialType.transparency,
                child: current != null
                    ? _buildBannerContent(context, current, isDark)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBannerContent(BuildContext context, TopNotificationItem item, bool isDark) {
    Color iconBg;
    Color borderColor;
    IconData icon;

    switch (item.type) {
      case TopNotificationType.medicationReminder:
        iconBg = AppColors.primaryBlue;
        borderColor = AppColors.primaryBlue.withValues(alpha: 0.6);
        icon = Icons.alarm_on_rounded;
        break;
      case TopNotificationType.stockAlert:
        iconBg = AppColors.afternoonOrange;
        borderColor = AppColors.afternoonOrange.withValues(alpha: 0.6);
        icon = Icons.inventory_2_rounded;
        break;
      case TopNotificationType.sosAlert:
        iconBg = AppColors.sosRed;
        borderColor = AppColors.sosRed.withValues(alpha: 0.8);
        icon = Icons.emergency_rounded;
        break;
      case TopNotificationType.familyLink:
        iconBg = const Color(0xFF8B5CF6);
        borderColor = const Color(0xFF8B5CF6).withValues(alpha: 0.6);
        icon = Icons.group_rounded;
        break;
      case TopNotificationType.info:
        iconBg = AppColors.successGreen;
        borderColor = AppColors.successGreen.withValues(alpha: 0.6);
        icon = Icons.notifications_active_rounded;
        break;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.up,
      onDismissed: (_) {
        InAppNotificationService().dismiss();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            if (item.actionLabel != null && item.onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  InAppNotificationService().dismiss();
                  item.onAction!();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: iconBg.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  item.actionLabel!,
                  style: TextStyle(
                    color: iconBg,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              onPressed: () => InAppNotificationService().dismiss(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
