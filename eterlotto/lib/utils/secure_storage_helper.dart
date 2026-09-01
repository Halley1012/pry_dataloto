import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Instancia centralizada de FlutterSecureStorage
class AppSecureStorage {
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
