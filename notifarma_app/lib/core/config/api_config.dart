import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  // Base URL pointing strictly to API Gateway (Port 8001)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8001';
    } else if (Platform.isAndroid) {
      // Usamos localhost gracias al adb forward por USB
      return 'http://localhost:8001';
    } else {
      return 'http://localhost:8001';
    }
  }

  // Timeout duration for HTTP requests
  static const Duration connectTimeout = Duration(seconds: 15);
}
