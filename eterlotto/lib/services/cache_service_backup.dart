import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/secure_storage_helper.dart';

class CacheService {
  static const String _prefix = "cache_dataloto_";

  /// 🔔 Notificador global para reactividad en tiempo real entre pestañas (IndexedStack)
  static final ValueNotifier<int> jugadasChangeNotifier = ValueNotifier<int>(0);

  /// Emite una señal para que todas las pantallas vivas en memoria recarguen sus datos
  static void notificarCambioJugadas() {
    jugadasChangeNotifier.value++;
  }

  /// Guarda una respuesta JSON o Lista de JSONs en SharedPreferences local con timestamp
  static Future<void> setJson(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = {
        '__ts': DateTime.now().millisecondsSinceEpoch,
        'payload': data,
      };
      final encoded = jsonEncode(envelope);
      await prefs.setString('$_prefix$key', encoded);
    } catch (_) {
      // Ignorar errores de escritura de caché
    }
  }

  /// Recupera una respuesta JSON o Lista de JSONs de la caché local.
  /// Si se especifica [maxAge], retorna `null` si el caché ha expirado.
  static Future<dynamic> getJson(String key, {Duration? maxAge}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('__ts') && decoded.containsKey('payload')) {
          if (maxAge != null) {
            final int ts = decoded['__ts'] as int;
            final savedAt = DateTime.fromMillisecondsSinceEpoch(ts);
            if (DateTime.now().difference(savedAt) >= maxAge) {
              return null; // Expirado
            }
          }
          return decoded['payload'];
        }
        // Compatibilidad con registros legacy sin envelope
        return decoded;
      }
    } catch (_) {
      // Ignorar errores de lectura
    }
    return null;
  }

  /// Obtiene la fecha y hora en que se guardó la caché para una clave dada
  static Future<DateTime?> getCacheTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded.containsKey('__ts')) {
          final int ts = decoded['__ts'] as int;
          return DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Comprueba si una clave de caché ha expirado según el [maxAge] indicado
  static Future<bool> isKeyExpired(String key, Duration maxAge) async {
    final timestamp = await getCacheTimestamp(key);
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) >= maxAge;
  }

  /// Elimina una clave específica de la caché local
  static Future<void> deleteKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }

  /// ⚡ Invalida activamente todos los caches de selectores (Resultados, Mis Jugadas, Info)
  /// y notifica inmediatamente a todas las pantallas activas para que se auto-sincronicen sin pull-to-refresh.
  static Future<void> invalidarCachesDeJugadas({String? specificRoute}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) {
        final rawKey = k.replaceFirst(_prefix, '');
        return rawKey.startsWith('mis_jugadas_selector') ||
               rawKey.startsWith('resultados_selector') ||
               rawKey.startsWith('mis_jugadas_info') ||
               rawKey.startsWith('user_jugadas_') ||
               (specificRoute != null && rawKey.contains(specificRoute.toLowerCase()));
      }).toList();

      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint("⚠️ Error invalidando caches de jugadas: $e");
    } finally {
      notificarCambioJugadas();
    }
  }

  /// ⚡ Registra de forma optimista e instantánea (0ms) una lotería con jugada en el caché del selector
  static Future<void> registrarJugadaOptimista(String route) async {
    try {
      final storage = AppSecureStorage.instance;
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
    } finally {
      notificarCambioJugadas();
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
