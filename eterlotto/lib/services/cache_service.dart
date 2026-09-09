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

  /// Invalida únicamente las cachés privadas del usuario afectado por una
  /// modificación de jugadas. Los resultados y catálogos públicos no se tocan.
  static Future<void> invalidarCachesDeJugadas({
    String? specificRoute,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storage = AppSecureStorage.instance;
      final activeUserId = userId?.trim().isNotEmpty == true
          ? userId!.trim()
          : (await storage.read(key: 'user_id'))?.trim() ?? 'anon';
      final route = specificRoute?.trim().toLowerCase();

      bool isRouteCacheForUser(String rawKey, String prefix) {
        if (route != null && route.isNotEmpty) {
          final routePrefix = '$prefix${route}_';
          // Algunas vistas privadas incluyen además una fecha o variante entre
          // la ruta y el usuario. Todas deben invalidarse al modificar una
          // jugada de esa misma lotería.
          return rawKey == '${prefix}${route}_${activeUserId}' ||
              (rawKey.startsWith(routePrefix) &&
                  rawKey.endsWith('_$activeUserId'));
        }
        return rawKey.startsWith(prefix) && rawKey.endsWith('_$activeUserId');
      }

      final keys = prefs.getKeys().where((k) {
        final rawKey = k.replaceFirst(_prefix, '');
        return rawKey == 'mis_jugadas_selector_v5_$activeUserId' ||
            rawKey == 'mis_jugadas_selector_$activeUserId' ||
            rawKey == 'mis_jugadas_info_cache_v2_$activeUserId' ||
            // Se limpia la única clave privada legacy, que no tenía usuario.
            rawKey == 'mis_jugadas_info_cache' ||
            isRouteCacheForUser(rawKey, 'user_jugadas_') ||
            isRouteCacheForUser(rawKey, 'jugadas_list_') ||
            isRouteCacheForUser(rawKey, 'resultados_dashboard_cache_v9_') ||
            isRouteCacheForUser(rawKey, 'resultados_dashboard_cache_v10_');
      }).toList();

      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {
      // La invalidación de caché no debe interrumpir el flujo de la aplicación.
    } finally {
      notificarCambioJugadas();
    }
  }

  /// ⚡ Registra de forma optimista e instantánea (0ms) una lotería con jugada en el caché del selector
  static Future<void> registrarJugadaOptimista(String route) async {
    try {
      final storage = AppSecureStorage.instance;
      final uId = await storage.read(key: 'user_id');
      final cacheKey = 'mis_jugadas_selector_v5_${uId ?? "anon"}';

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
    } catch (_) {
      // El registro optimista es una mejora de UX; el backend sigue siendo la fuente de verdad.
    } finally {
      notificarCambioJugadas();
    }
  }

  static String _getRouteFromName(String nombre) {
    final clean = nombre
        .trim()
        .toLowerCase()
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
