import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/secure_storage_helper.dart';

class CacheService {
  static const String _prefix = "cache_dataloto_";

  /// Catálogo público y universal de loterías. No depende del usuario.
  static const String catalogoLoteriasKey = 'loterias_mapeadas_all';

  /// Reglas públicas que usa el generador de combinaciones.
  static const String reglasCombinacionesKey = 'combination_lotteries_rules_v3';

  /// Feed público de la comunidad. No contiene estado personal (likes,
  /// favoritos, permisos, etc.), por lo que puede compartirse entre cuentas.
  static const String homePostsKey = 'home_posts_v1';

  /// Comentarios públicos de un post concreto. La cuenta actual sólo afecta
  /// las acciones permitidas sobre ellos, nunca la entrada de caché.
  static String comentariosPostKey(int postId) => 'post_comments_$postId';

  static String jugadasUsuarioKey(
    String route,
    String? userId, {
    int? loteriaId,
  }) {
    final normalizedRoute = route.trim().toLowerCase();
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    final identity = loteriaId != null
        ? 'id_${loteriaId}_$normalizedRoute'
        : 'route_$normalizedRoute';
    return 'user_jugadas_${identity}_$normalizedUser';
  }

  static String selectorMisJugadasKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    return 'mis_jugadas_selector_v6_$normalizedUser';
  }

  static String infoMisJugadasKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    return 'mis_jugadas_info_cache_v3_$normalizedUser';
  }

  /// Perfil privado. Nunca compartir una clave entre cuentas del dispositivo.
  static String perfilUsuarioKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    return 'profile_$normalizedUser';
  }

  /// Lista blanca estricta para cualquier dato de perfil que termine en
  /// SharedPreferences. Tokens y credenciales nunca deben entrar en esta caché.
  static const Set<String> _profileCacheAllowedKeys = {
    'id',
    'user_id',
    'name',
    'email',
    'pais_id',
    'pais_nombre',
    'departamento_id',
    'departamento_nombre',
    'avatar_url',
    'auth_provider',
    'telefono',
    'idioma',
    'is_premium',
  };

  /// Sanitiza un perfil antes de persistirlo en almacenamiento no cifrado.
  /// Si el backend devuelve {"user": {...}}, toma únicamente ese objeto.
  static Map<String, dynamic> sanitizeProfileCacheData(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};

    final source = Map<String, dynamic>.from(raw);
    final nested = source['user'];
    final profile = nested is Map
        ? Map<String, dynamic>.from(nested)
        : source;

    final safe = <String, dynamic>{};
    for (final key in _profileCacheAllowedKeys) {
      if (profile.containsKey(key)) {
        safe[key] = profile[key];
      }
    }
    return safe;
  }

  /// Último estado visual conocido de la suscripción, aislado por cuenta.
  /// El backend sigue validándolo al iniciar y al volver a primer plano.
  static String subscriptionStatusKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    return 'subscription_status_$normalizedUser';
  }

  /// Notificaciones privadas, incluyendo su estado leído/eliminado.
  static String notificacionesUsuarioKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    // Se conserva el prefijo existente para reutilizar las entradas ya
    // guardadas en dispositivos instalados.
    return 'notifications_cache_$normalizedUser';
  }

  /// Catálogo público de anuncios. Los filtros, no la cuenta, definen la
  /// entrada. Los favoritos se almacenan por separado y por usuario.
  static String directorioAnunciosKey({
    int? paisId,
    int? departamentoId,
    int? ciudadId,
    int? categoriaId,
    String? titulo,
  }) {
    final normalizedTitle = (titulo ?? '').trim().toLowerCase();
    return 'directorio_anuncios_${paisId ?? 'all'}_${departamentoId ?? 'all'}_${ciudadId ?? 'all'}_${categoriaId ?? 'all'}_$normalizedTitle';
  }

  static String favoritosPublicidadKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    return 'favorite_ads_$normalizedUser';
  }

  static String misAnunciosKey(String? userId) {
    final normalizedUser = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : 'anon';
    return 'mis_anuncios_$normalizedUser';
  }

  // Política única de caducidad. Las pantallas no deben decidir TTL por ruta
  // ni por lotería: la naturaleza del dato define cuánto tiempo es válido.
  static const Duration catalogoTtl = Duration(hours: 12);
  static const Duration reglasTtl = Duration(hours: 12);
  static const Duration resultadosRecientesTtl = Duration(minutes: 3);
  static const Duration prediccionTtl = Duration(minutes: 15);
  static const Duration historicoTtl = Duration(minutes: 45);
  static const Duration jugadasUsuarioTtl = Duration(minutes: 2);
  static const Duration selectorJugadasTtl = Duration(minutes: 2);
  static const Duration perfilTtl = Duration(minutes: 5);
  static const Duration subscriptionStatusTtl = Duration(minutes: 5);
  static const Duration notificacionesTtl = Duration(minutes: 2);
  static const Duration postsTtl = Duration(minutes: 5);
  static const Duration comentariosTtl = Duration(minutes: 5);
  static const Duration publicidadTtl = Duration(minutes: 10);
  static const Duration paisesCategoriasTtl = Duration(hours: 24);
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Resuelve la duración máxima según el tipo de información almacenada.
  /// La coincidencia se hace por familia de clave, por lo que funciona para
  /// cualquier lotería, país o usuario sin listas de rutas hardcodeadas.
  static Duration ttlForKey(String key) {
    final normalized = key.trim().toLowerCase();

    if (normalized.contains('historico') || normalized.contains('historial')) {
      return historicoTtl;
    }
    if (normalized.contains('prediccion')) return prediccionTtl;
    if (normalized.contains('ultimos') ||
        normalized.startsWith('resultados_dashboard_cache') ||
        normalized.startsWith('resultados_selector')) {
      return resultadosRecientesTtl;
    }
    if (normalized.startsWith('user_jugadas_') ||
        normalized.startsWith('jugadas_list_') ||
        normalized.startsWith('mis_jugadas_info_')) {
      return jugadasUsuarioTtl;
    }
    if (normalized.startsWith('mis_jugadas_selector_')) {
      return selectorJugadasTtl;
    }
    if (normalized.startsWith('notifications_cache_')) {
      return notificacionesTtl;
    }
    if (normalized == homePostsKey) return postsTtl;
    if (normalized.startsWith('post_comments_')) return comentariosTtl;
    if (normalized.startsWith('mis_anuncios_')) {
      return publicidadTtl;
    }
    if (normalized.contains('perfil') || normalized.contains('profile')) {
      return perfilTtl;
    }
    if (normalized.startsWith('subscription_status_')) {
      return subscriptionStatusTtl;
    }
    if (normalized.contains('anuncio') ||
        normalized.contains('publicidad') ||
        normalized.contains('director')) {
      return publicidadTtl;
    }
    if (normalized.startsWith('paises_') ||
        normalized.startsWith('categorias_') ||
        normalized.startsWith('departamentos_') ||
        normalized.startsWith('ciudades_')) {
      return paisesCategoriasTtl;
    }
    if (normalized == catalogoLoteriasKey ||
        normalized == 'home_loterias_globales' ||
        normalized.startsWith('home_loterias_') ||
        normalized.startsWith('loterias_mapeadas_') ||
        normalized.startsWith('explorar_loterias_')) {
      return catalogoTtl;
    }
    if (normalized == reglasCombinacionesKey ||
        normalized.contains('reglas') ||
        normalized.contains('rules') ||
        normalized.contains('combinaciones') ||
        normalized.contains('combination_')) {
      return reglasTtl;
    }
    return defaultTtl;
  }

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

      // Defensa en profundidad: cualquier caller que intente guardar un perfil
      // pasa por lista blanca antes de escribir en SharedPreferences.
      final payload = key.trim().toLowerCase().startsWith('profile_')
          ? sanitizeProfileCacheData(data)
          : data;

      final envelope = {
        '__ts': DateTime.now().millisecondsSinceEpoch,
        'payload': payload,
      };
      final encoded = jsonEncode(envelope);
      await prefs.setString('$_prefix$key', encoded);
    } catch (_) {
      // Ignorar errores de escritura de caché
    }
  }

  /// Recupera una respuesta JSON o Lista de JSONs de la caché local.
  ///
  /// Si no se indica [maxAge], usa la política central de [ttlForKey]. Una
  /// entrada vencida no se borra: queda disponible mediante [getStaleJson]
  /// para que la pantalla pueda aplicar stale-while-revalidate.
  static Future<dynamic> getJson(String key, {Duration? maxAge}) async {
    return _readJson(key, maxAge: maxAge ?? ttlForKey(key));
  }

  /// Elimina una entrada concreta sin afectar cachés de otras cuentas ni
  /// catálogos públicos.
  static Future<void> removeJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {
      // Ignorar errores de invalidación de caché.
    }
  }

  /// Devuelve el último valor conocido aunque esté vencido. Úsalo únicamente
  /// como primer render mientras se solicita el dato fresco en segundo plano.
  static Future<dynamic> getStaleJson(String key) async {
    return _readJson(key);
  }

  static Future<dynamic> _readJson(String key, {Duration? maxAge}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('__ts') &&
            decoded.containsKey('payload')) {
          if (maxAge != null) {
            final ts = decoded['__ts'];
            final int? timestamp = ts is int
                ? ts
                : int.tryParse(ts?.toString() ?? '');
            if (timestamp == null) return null;
            final savedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
            if (DateTime.now().difference(savedAt) >= maxAge) {
              return null; // Expirado
            }
          }
          return decoded['payload'];
        }
        // Un registro legacy no tiene fecha verificable. Se devuelve sólo por
        // getStaleJson; una lectura normal fuerza su renovación segura.
        return maxAge == null ? decoded : null;
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
    int? specificLotteryId,
    String? userId,
    bool preserveRouteJugadas = false,
    bool preserveSelector = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storage = AppSecureStorage.instance;
      final activeUserId = userId?.trim().isNotEmpty == true
          ? userId!.trim()
          : (await storage.read(key: 'user_id'))?.trim() ?? 'anon';
      final route = specificRoute?.trim().toLowerCase();

      bool isRouteCacheForUser(String rawKey, String prefix) {
        if (!rawKey.endsWith('_$activeUserId')) return false;

        if ((prefix == 'user_jugadas_' ||
                prefix == 'resultados_dashboard_cache_v11_') &&
            specificLotteryId != null) {
          final exactPrefix = '${prefix}id_${specificLotteryId}_';
          // También limpiamos la clave legacy por route para que una versión
          // anterior de la app no reaparezca con datos mezclados.
          final legacyRoutePrefix = route != null && route.isNotEmpty
              ? '${prefix}route_${route}_'
              : null;
          return rawKey.startsWith(exactPrefix) ||
              (legacyRoutePrefix != null && rawKey.startsWith(legacyRoutePrefix));
        }

        if (route != null && route.isNotEmpty) {
          return rawKey.startsWith('${prefix}${route}_') ||
              rawKey.startsWith('${prefix}route_${route}_');
        }
        return rawKey.startsWith(prefix);
      }

      final keys = prefs.getKeys().where((k) {
        final rawKey = k.replaceFirst(_prefix, '');
        return (!preserveSelector &&
                (rawKey == selectorMisJugadasKey(activeUserId) ||
                    rawKey == 'mis_jugadas_selector_$activeUserId')) ||
            rawKey == infoMisJugadasKey(activeUserId) ||
            // La clave legacy no incluye usuario; ya no se lee ni se borra
            // para evitar tocar un posible respaldo de otra sesión.
            (!preserveRouteJugadas &&
                isRouteCacheForUser(rawKey, 'user_jugadas_')) ||
            isRouteCacheForUser(rawKey, 'jugadas_list_') ||
            isRouteCacheForUser(rawKey, 'resultados_dashboard_cache_v9_') ||
            isRouteCacheForUser(rawKey, 'resultados_dashboard_cache_v10_') ||
            isRouteCacheForUser(rawKey, 'resultados_dashboard_cache_v11_');
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

  /// Los anuncios públicos pueden aparecer en múltiples filtros y en Home.
  /// Se invalidan sólo esas entradas compartidas y la lista privada del dueño;
  /// los favoritos de otras cuentas permanecen intactos.
  static Future<void> invalidarCachesPublicidad({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storage = AppSecureStorage.instance;
      final activeUserId = userId?.trim().isNotEmpty == true
          ? userId!.trim()
          : (await storage.read(key: 'user_id'))?.trim();
      final keys = prefs.getKeys().where((key) {
        final rawKey = key.replaceFirst(_prefix, '');
        return rawKey.startsWith('directorio_anuncios_') ||
            rawKey.startsWith('home_anuncios_') ||
            (activeUserId != null && rawKey == misAnunciosKey(activeUserId));
      }).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // No bloquear un CRUD exitoso por una limpieza local fallida.
    }
  }

  /// ⚡ Registra de forma optimista e instantánea (0ms) una lotería con jugada en el caché del selector
  static Future<void> registrarJugadaOptimista(
    String route, {
    String? userId,
    int? loteriaId,
  }) async {
    try {
      final storage = AppSecureStorage.instance;
      final uId = userId ?? await storage.read(key: 'user_id');
      final cacheKey = selectorMisJugadasKey(uId);

      // Registrar una jugada necesita el último catálogo disponible aun si
      // ya venció; la petición posterior actualizará la fuente de verdad.
      final cached = await getStaleJson(cacheKey);
      final cachedAll = await getStaleJson(catalogoLoteriasKey);

      List<Map<String, dynamic>> list = cached != null
          ? List<Map<String, dynamic>>.from(cached)
          : [];
      List<Map<String, dynamic>> todas = cachedAll != null
          ? List<Map<String, dynamic>>.from(cachedAll)
          : [];

      bool matchesIdentity(Map<String, dynamic> item) {
        if (loteriaId != null) {
          return item['id']?.toString() == loteriaId.toString();
        }
        final r = (item['route']?.toString().isNotEmpty == true)
            ? item['route'].toString().trim().toLowerCase()
            : _getRouteFromName((item['nombre'] ?? '').toString());
        return r == route.trim().toLowerCase();
      }

      final yaExiste = list.any(matchesIdentity);

      if (!yaExiste && todas.isNotEmpty) {
        final loteriaEncontrada = todas.firstWhere(
          matchesIdentity,
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
