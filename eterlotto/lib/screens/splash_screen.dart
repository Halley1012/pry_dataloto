import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shimmer/shimmer.dart';

import 'package:eterlotto/screens/registro.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/push_notification_service.dart';
import '../utils/secure_storage_helper.dart';
import 'package:eterlotto/services/ad_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = AppSecureStorage.instance;

  // El splash permanece el tiempo suficiente para que la animación se vea
  // fluida y para precalentar los datos más importantes del Home.
  static const Duration _minimumSplashDuration = Duration(milliseconds: 2800);

  // Nunca retenemos al usuario demasiado tiempo por una red lenta. Si los
  // servicios no responden dentro de este margen, Home continúa usando su
  // estrategia cache-first / stale-while-revalidate.
  static const Duration _startupWarmupTimeout = Duration(seconds: 5);

  bool _hasNavigated = false;
  late final DateTime _splashStartedAt;

  @override
  void initState() {
    super.initState();
    AdService.instance.setAppOpenEligibility(false);
    _splashStartedAt = DateTime.now();

    unawaited(_startApplication());

    // Google Play Update no forma parte del camino crítico del arranque.
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      unawaited(_checkForAppUpdateInBackground());
    }
  }

  Future<void> _startApplication() async {
    try {
      // Primero resolvemos únicamente el estado local de sesión. Esto es rápido
      // y nos permite saber qué datos vale la pena precalentar.
      final values = await Future.wait([
        storage.read(key: 'auth_token'),
        storage.read(key: 'refresh_token'),
        storage.read(key: 'pais_id'),
        storage.read(key: 'pais_nombre'),
        storage.read(key: 'user_id'),
      ]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String?>[null, null, null, null, null],
      );

      if (!mounted) return;

      final accessToken = values[0];
      final refreshToken = values[1];
      final paisId = values[2];
      final paisNombre = values[3];
      final userId = values[4];
      final hasLocalSession = accessToken != null || refreshToken != null;

      if (!hasLocalSession) {
        await _waitMinimumSplashTime();
        _navigateToWelcome();
        return;
      }

      if (paisId == null || paisId.isEmpty || paisId == 'null') {
        await _waitMinimumSplashTime();
        await _navigateToRegistration();
        return;
      }

      // Para una sesión existente hacemos el trabajo útil DURANTE el splash:
      // validar/renovar sesión, precalentar catálogo, loterías, publicidad,
      // posts, perfil y reglas del generador. Home encontrará esos datos en
      // caché y podrá pintar contenido real desde su primer frame.
      final warmupFuture = _preloadHomeData(
        userId: userId,
        paisId: paisId,
        paisNombre: paisNombre,
      ).timeout(
        _startupWarmupTimeout,
        onTimeout: () {},
      );

      // El tiempo mínimo y el precalentamiento ocurren en paralelo; por eso no
      // sumamos 2.8 s + 5 s. Normalmente el splash dura ~2.8 s y sólo se alarga
      // si la carga útil necesita un poco más, con un máximo razonable.
      await Future.wait([
        _waitMinimumSplashTime(),
        warmupFuture,
      ]);

      if (!mounted) return;

      // FCM no necesita bloquear la navegación una vez preparado el Home.
      unawaited(PushNotificationService.syncToken());
      _navigateToHome();
    } catch (_) {
      if (!mounted) return;

      // Fallback puramente local: un fallo temporal de red nunca debe dejar al
      // usuario atrapado en Splash ni expulsarlo de una sesión existente.
      final values = await Future.wait([
        storage.read(key: 'auth_token'),
        storage.read(key: 'refresh_token'),
        storage.read(key: 'pais_id'),
      ]);

      if (!mounted) return;

      await _waitMinimumSplashTime();
      if (!mounted) return;

      final hasToken = values[0] != null || values[1] != null;
      final paisId = values[2];

      if (!hasToken) {
        _navigateToWelcome();
        return;
      }

      if (paisId == null || paisId.isEmpty || paisId == 'null') {
        await _navigateToRegistration();
        return;
      }

      unawaited(ApiService.ensureValidSession());
      unawaited(PushNotificationService.syncToken());
      _navigateToHome();
    }
  }

  Future<void> _waitMinimumSplashTime() async {
    final elapsed = DateTime.now().difference(_splashStartedAt);
    final remaining = _minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _preloadHomeData({
    required String? userId,
    required String paisId,
    required String? paisNombre,
  }) async {
    // Intentamos renovar la sesión antes de las llamadas autenticadas. Si la
    // red está momentáneamente lenta, cada tarea se protege de forma aislada.
    await _ignoreFailure(
      ApiService.ensureValidSession().timeout(const Duration(seconds: 3)),
    );

    String? resolvedUserId = userId?.trim();
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      final id = await _valueOrNull(
        ApiService.getUserId().timeout(const Duration(seconds: 2)),
      );
      resolvedUserId = id?.toString();
    }

    final cleanPaisId = paisId.trim();
    final paisIdInt = int.tryParse(cleanPaisId);
    final cacheKeySuffix = cleanPaisId.isEmpty ? 'global' : cleanPaisId;

    // Estas llamadas se disparan juntas para aprovechar el tiempo visual del
    // splash. Cada una guarda el resultado en las mismas claves que consume
    // HomeScreen, evitando el skeleton cuando existe respuesta o caché válida.
    final postsFuture = _valueOrNull(ApiService.getPosts());
    final anunciosFuture = _valueOrNull(
      ApiService.getPublicidades(paisId: paisIdInt),
    );
    final loteriasFuture = _valueOrNull(
      cleanPaisId.isNotEmpty
          ? ApiService.getLoteriasPorPais(cleanPaisId)
          : ApiService.getAllLoterias(),
    );
    final globalFuture = cleanPaisId.isNotEmpty
        ? _valueOrNull(ApiService.getAllLoterias())
        : Future<List<dynamic>?>.value(null);
    final paisesFuture = _valueOrNull(ApiService.getPaises());
    final reglasFuture = _ignoreFailure(ApiService.getCombinationLotteries());
    final profileFuture = _fetchProfile(resolvedUserId);

    final results = await Future.wait<dynamic>([
      postsFuture,
      anunciosFuture,
      loteriasFuture,
      globalFuture,
      paisesFuture,
      profileFuture,
      reglasFuture,
    ]);

    final posts = results[0];
    final anuncios = results[1];
    final loterias = results[2];
    final globales = results[3];
    final profile = results[5];

    final writes = <Future<void>>[];

    if (posts != null) {
      writes.add(
        CacheService.setJson(
          CacheService.homePostsKey,
          posts.map((post) => post.toJson()).toList(),
        ),
      );
    }

    if (anuncios != null) {
      writes.add(
        CacheService.setJson(
          'home_anuncios_$cacheKeySuffix',
          anuncios,
        ),
      );
    }

    if (loterias != null) {
      writes.add(
        CacheService.setJson(
          'home_loterias_$cacheKeySuffix',
          loterias,
        ),
      );

      if (cleanPaisId.isEmpty) {
        writes.add(
          CacheService.setJson('home_loterias_globales', loterias),
        );
      }
    }

    if (globales != null) {
      writes.add(
        CacheService.setJson('home_loterias_globales', globales),
      );
    }

    if (profile != null && resolvedUserId?.isNotEmpty == true) {
      writes.add(
        CacheService.setJson(
          CacheService.perfilUsuarioKey(resolvedUserId),
          CacheService.sanitizeProfileCacheData(profile),
        ),
      );
    }

    // Conservamos nombre/ID de país tal como ya los maneja la sesión. No
    // inventamos ni reasignamos países durante el precalentamiento.
    if (paisNombre != null && paisNombre.trim().isNotEmpty) {
      unawaited(
        storage.write(key: 'pais_nombre', value: paisNombre.trim()),
      );
    }

    if (writes.isNotEmpty) {
      await Future.wait(writes.map(_ignoreFailure));
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile(String? userId) async {
    if (userId == null || userId.trim().isEmpty) return null;

    try {
      final response = await ApiService.get('/users/${userId.trim()}').timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<T?> _valueOrNull<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ignoreFailure(Future<dynamic> future) async {
    try {
      await future;
    } catch (_) {
      // El precalentamiento es una optimización, nunca un bloqueo de arranque.
    }
  }

  Future<void> _checkForAppUpdateInBackground() async {
    try {
      final info = await InAppUpdate.checkForUpdate().timeout(
        const Duration(seconds: 3),
      );

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        InAppUpdate.installUpdateListener.listen((state) async {
          if (state == InstallStatus.downloaded) {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (_) {}
          }
        });

        try {
          await InAppUpdate.startFlexibleUpdate();
        } catch (_) {}
      }
    } on TimeoutException {
      // Play Store lento: no afecta la entrada a Eterlotto.
    } catch (_) {
      // Un fallo de Play Store tampoco afecta la sesión.
    }
  }

  Future<void> _navigateToRegistration() async {
    if (!mounted || _hasNavigated) return;

    final values = await Future.wait([
      storage.read(key: 'user_id'),
      storage.read(key: 'name'),
      storage.read(key: 'email'),
    ]);

    if (!mounted || _hasNavigated) return;

    final userId = values[0];
    final name = values[1];
    final email = values[2];
    final parsedUserId = int.tryParse(userId ?? '0');

    final user = {
      'id': parsedUserId,
      'name': name,
      'email': email,
    };

    _hasNavigated = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RegistroScreen(
          user: user,
          userId: parsedUserId,
          isSocialOnboarding: true,
        ),
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _navigateToWelcome() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.96, end: 1.0),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Image.asset(
                      'assets/images/logo_letras_.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                // Un ciclo algo más rápido que el splash anterior evita la
                // sensación de destello detenido. En ~2.8 s se alcanzan a ver
                // casi dos barridos completos y fluidos.
                Shimmer.fromColors(
                  baseColor: Colors.transparent,
                  highlightColor: Colors.white.withValues(alpha: 0.72),
                  period: const Duration(milliseconds: 1450),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Image.asset(
                        'assets/images/logo_letras_.png',
                        fit: BoxFit.contain,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
