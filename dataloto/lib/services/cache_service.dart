import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  /// ⚡ Registra de forma optimista e instantánea (0ms) una lotería con jugada en el caché del selector
  static Future<void> registrarJugadaOptimista(String route) async {
    try {
      const storage = FlutterSecureStorage();
      final uId = await storage.read(key: 'user_id');
      final cacheKey = 'mis_jugadas_selector_${uId ?? "anon"}';

      final cached = await getJson(cacheKey);
      final cachedAll = await getJson('loterias_mapeadas_all');

      List<Map<String, dynamic>> list = cached != null ? List<Map<String, dynamic>>.from(cached) : [];
      List<Map<String, dynamic>> todas = cachedAll != null ? List<Map<String, dynamic>>.from(cachedAll) : [];

      final yaExiste = list.any((item) {
        final r = (item['route']?.toString().isNotEmpty == true)
            ? item['route'].toString().trim().toLowerCase()
            : _getRouteFromName((item['nombre'] ?? '').toString());
        return r == route.trim().toLowerCase();
      });

      if (!yaExiste && todas.isNotEmpty) {
        final loteriaEncontrada = todas.firstWhere(
          (item) {
            final r = (item['route']?.toString().isNotEmpty == true)
                ? item['route'].toString().trim().toLowerCase()
                : _getRouteFromName((item['nombre'] ?? '').toString());
            return r == route.trim().toLowerCase();
          },
          orElse: () => <String, dynamic>{},
        );

        if (loteriaEncontrada.isNotEmpty) {
          list.add(loteriaEncontrada);
          await setJson(cacheKey, list);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error al registrar jugada optimista: $e");
    }
  }

  static String _getRouteFromName(String nombre) {
    String clean = nombre.trim().toLowerCase();
    if (clean.contains("baloto") || clean == "bloto") return "bloto";
    if (clean.contains("miloto") || clean == "mloto") return "mloto";
    if (clean.contains("colorloto") || clean.contains("color_loto") || clean == "cloto") return "colorloto";

    clean = clean
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');

    return clean
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s_]+'), '_');
  }
}
