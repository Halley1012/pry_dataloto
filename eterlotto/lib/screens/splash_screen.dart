import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:eterlotto/screens/registro.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../utils/secure_storage_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final storage = AppSecureStorage.instance;

  late final AnimationController _controller;

  // Evita que dos procesos async intenten navegar al mismo tiempo.
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _controller.forward();
    unawaited(_checkAuth());

    // El chequeo de Google Play ya no forma parte del camino crítico del
    // arranque. Puede tardar varios segundos sin retener al usuario en Splash.
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      unawaited(_checkForAppUpdateInBackground());
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

  Future<void> _checkAuth() async {
    try {
      // Sólo dependemos del estado LOCAL para decidir la primera pantalla.
      // ApiService ya renueva tokens de forma centralizada cuando una petición
      // autenticada lo necesita, así que no hay razón para esperar la red aquí.
      final values = await Future.wait([
        storage.read(key: 'auth_token'),
        storage.read(key: 'refresh_token'),
        storage.read(key: 'pais_id'),
      ]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String?>[null, null, null],
      );

      if (!mounted) return;

      final accessToken = values[0];
      final refreshToken = values[1];
      final paisId = values[2];
      final hasLocalSession = accessToken != null || refreshToken != null;

      if (!hasLocalSession) {
        _navigateToWelcome();
        return;
      }

      if (paisId == null || paisId.isEmpty || paisId == 'null') {
        await _navigateToRegistration();
        return;
      }

      // La sesión y FCM se verifican después, sin bloquear el primer frame del
      // Home. Si el access token expiró, ApiService intentará refresh silencioso.
      unawaited(ApiService.ensureValidSession());
      unawaited(PushNotificationService.syncToken());
      _navigateToHome();
    } catch (_) {
      if (!mounted) return;

      // Último fallback local. Un problema temporal leyendo/validando sesión no
      // debe forzar una espera de red ni expulsar a quien aún tiene tokens.
      final values = await Future.wait([
        storage.read(key: 'auth_token'),
        storage.read(key: 'refresh_token'),
        storage.read(key: 'pais_id'),
      ]);

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Image.asset(
                  'assets/images/logo_letras_.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Shimmer.fromColors(
              baseColor: Colors.transparent,
              highlightColor: Colors.white.withValues(alpha: 0.6),
              period: const Duration(seconds: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Image.asset(
                    'assets/images/logo_letras_.png',
                    fit: BoxFit.contain,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
