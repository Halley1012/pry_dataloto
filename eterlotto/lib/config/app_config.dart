import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Permite forzar el ambiente con --dart-define=ENV=dev|prd.
  /// Si no se especifica:
  /// - release => PRD
  /// - debug/profile => DEV
  static const String _environmentOverride = String.fromEnvironment(
    'ENV',
    defaultValue: '',
  );

  static const String _devApiUrl =
      'https://pry-dataloto.onrender.com';

  static const String _prdApiUrl =
      'https://eterlotto-api-prd.onrender.com';

  static String get environment {
    final override = _environmentOverride.trim().toLowerCase();
    if (override.isNotEmpty) {
      return override;
    }
    return kReleaseMode ? 'prd' : 'dev';
  }

  static bool get isProduction {
    final env = environment;
    return env == 'prd' || env == 'prod' || env == 'production';
  }

  static bool get isDevelopment => !isProduction;

  static String get baseUrl => isProduction ? _prdApiUrl : _devApiUrl;
}
