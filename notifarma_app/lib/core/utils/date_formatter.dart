import 'package:intl/intl.dart';

class DateFormatter {
  static const _colombiaOffset = Duration(hours: 5);

  static DateTime nowColombia() {
    final now = DateTime.now().toUtc().subtract(_colombiaOffset);
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  static DateTime? tryParseColombiaDateTime(String value) {
    try {
      final parsed = DateTime.parse(value);
      final hasTimezone =
          value.trim().toUpperCase().endsWith('Z') ||
          RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value.trim());
      final wallTime = hasTimezone
          ? parsed.toUtc().subtract(_colombiaOffset)
          : parsed;
      return DateTime.utc(
        wallTime.year,
        wallTime.month,
        wallTime.day,
        wallTime.hour,
        wallTime.minute,
        wallTime.second,
        wallTime.millisecond,
        wallTime.microsecond,
      );
    } on FormatException {
      return null;
    }
  }

  static String toColombiaIsoString(DateTime colombiaWallTime) {
    return DateTime.utc(
      colombiaWallTime.year,
      colombiaWallTime.month,
      colombiaWallTime.day,
      colombiaWallTime.hour,
      colombiaWallTime.minute,
      colombiaWallTime.second,
      colombiaWallTime.millisecond,
      colombiaWallTime.microsecond,
    ).add(_colombiaOffset).toIso8601String();
  }

  static String formatColombiaDateTime(DateTime colombiaWallTime) {
    return DateFormat('dd/MM/yyyy • hh:mm a').format(colombiaWallTime);
  }

  static String formatColombiaTime(DateTime colombiaWallTime) {
    return DateFormat('h:mm a').format(colombiaWallTime);
  }

  /// Parses a UTC ISO string from the backend and converts to local DateTime
  static DateTime parseUtcToLocal(String isoString) {
    try {
      DateTime dt = DateTime.parse(isoString);
      return dt.toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Formats date and time for the top header bar (e.g. "Lunes, 19 Ago • 08:30 AM")
  static String formatHeaderDateTime(DateTime localDateTime) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    String dayName = days[localDateTime.weekday - 1];
    String dayNumber = localDateTime.day.toString();
    String monthName = months[localDateTime.month - 1];
    String timeStr = DateFormat('hh:mm a').format(localDateTime);

    return '$dayName, $dayNumber $monthName • $timeStr';
  }

  /// Formats a time string ("08:00:00" or "08:00") into 12-hour format ("08:00 AM")
  static String formatTimeString(String timeStr) {
    try {
      final clean = timeStr.trim();
      if (clean.contains('T') || clean.contains('-')) {
        final dt = parseUtcToLocal(clean);
        return DateFormat('hh:mm a').format(dt);
      }
      final parts = clean.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  /// Formats DateTime to 12-hour time string ("08:00 AM")
  static String formatTimeOnly(DateTime dt) {
    return DateFormat('hh:mm a').format(dt.toLocal());
  }
}
