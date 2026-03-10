import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Nginx routes /api/ to backend.
      return Uri.base.origin; 
    }
    return 'http://localhost:4101';
  }
}
