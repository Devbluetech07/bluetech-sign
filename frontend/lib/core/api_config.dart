import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Local web-server (4100) does not proxy /api.
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return '${Uri.base.scheme}://$host:3001';
      }
      // Production (with reverse proxy) keeps same origin.
      return Uri.base.origin;
    }
    return 'http://localhost:3001';
  }
}
