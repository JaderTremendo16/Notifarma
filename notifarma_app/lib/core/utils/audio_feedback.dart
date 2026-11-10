import 'package:flutter/services.dart';

class AudioFeedback {
  /// Reproduce un sonido táctil breve del sistema acompañado de vibración sutil
  static void playSuccess() {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Feedback para confirmación de toma o acción importante
  static void playConfirmation() {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}

