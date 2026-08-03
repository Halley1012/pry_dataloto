import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _prefix = "cache_dataloto_";

  /// Guarda una respuesta JSON o Lista de JSONs en SharedPreferences local
  static Future<void> setJson(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(data);
      await prefs.setString('$_prefix$key', encoded);
    } catch (_) {
      // Ignorar errores de escritura de caché
    }
  }

  /// Recupera una respuesta JSON o Lista de JSONs de la caché local
  static Future<dynamic> getJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw);
      }
    } catch (_) {
      // Ignorar errores de lectura
    }
    return null;
  }
}
