import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenSecurityHelper {
  static const MethodChannel _channel = MethodChannel('com.lumieter.eterlotto/security');

  /// 🛠️ Switch maestro para activar/desactivar la protección de capturas
  /// (Desactivado temporalmente para permitir visualización y capturas desde el PC)
  static bool isSecurityEnabled = false;

  /// 🔒 Bloquear capturas de pantalla y grabación de pantalla (FLAG_SECURE)
  static Future<void> enableSecureScreen() async {
    if (!isSecurityEnabled) {
      await disableSecureScreen();
      return;
    }
    try {
      final res = await _channel.invokeMethod('enableSecureScreen');
      debugPrint('🔒 Protección de pantalla ACTIVADA (FLAG_SECURE): $res');
    } catch (e) {
      debugPrint('❌ Error activando FLAG_SECURE: $e');
    }
  }

  /// 🔓 Desbloquear capturas de pantalla
  static Future<void> disableSecureScreen() async {
    try {
      final res = await _channel.invokeMethod('disableSecureScreen');
      debugPrint('🔓 Protección de pantalla DESACTIVADA: $res');
    } catch (e) {
      debugPrint('❌ Error desactivando FLAG_SECURE: $e');
    }
  }
}
