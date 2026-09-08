import 'dart:async';

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

    // IMPORTANTE:
    // No existe un Future.delayed que fuerce la navegación a /welcome.
    // La navegación queda bajo el control exclusivo de _checkAuth().
  }

  Future<void> _checkAuth() async {
    try {
      final splashDelay = Future.delayed(
        const Duration(milliseconds: 1500),
      );

      // 1. CHECK DE VERSIÓN VÍA GOOGLE PLAY (In-App Updates)
      //
      // Este chequeo no debe bloquear indefinidamente el arranque.
      // Si Google Play no responde rápidamente, continuamos normalmente.
      try {
        if (Theme.of(context).platform == TargetPlatform.android) {
          final info = await InAppUpdate.checkForUpdate().timeout(
            const Duration(seconds: 3),
          );

          if (info.updateAvailability == UpdateAvailability.updateAvailable) {
            // Actualización crítica e inmediata.
            if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
              await InAppUpdate.performImmediateUpdate();
            } else if (info.flexibleUpdateAllowed) {
              InAppUpdate.installUpdateListener.listen((state) async {
                if (state == InstallStatus.downloaded) {
                  try {
                    await InAppUpdate.completeFlexibleUpdate();
                  } catch (e) {
                    debugPrint(
                      'Error completando actualización flexible: $e',
                    );
                  }
                }
              });

              try {
                await InAppUpdate.startFlexibleUpdate();
              } catch (e) {
                debugPrint(
                  'Error iniciando actualización flexible: $e',
                );
              }
            }
          }
        }
      } on TimeoutException {
        debugPrint(
          'In-App Update tardó demasiado. Continuando con el arranque normal.',
        );
      } catch (e) {
        debugPrint('Error en InAppUpdate: $e');
      }

      // 2. Recuperar tokens locales.
      final accessToken = await storage.read(key: "auth_token").timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      final refreshToken = await storage.read(key: "refresh_token").timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      // No hay sesión local: ir a Welcome.
      if (accessToken == null && refreshToken == null) {
        await splashDelay;

        if (!mounted) return;
        _navigateToWelcome();
        return;
      }

      // 3. Validar/refrescar sesión.
      //
      // El timeout evita que Splash quede esperando indefinidamente
      // al backend. Si ya existen tokens locales, se conserva la sesión
      // como fallback para permitir el funcionamiento offline/lag.
      final hasSession = await ApiService.ensureValidSession().timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => (accessToken != null || refreshToken != null),
      );

      await splashDelay;

      if (!mounted) return;

      final stayLoggedIn =
          hasSession || accessToken != null || refreshToken != null;

      if (stayLoggedIn) {
        final paisId = await storage.read(key: "pais_id");

        if (!mounted) return;

        if (paisId == null || paisId.isEmpty || paisId == "null") {
          await _navigateToRegistration();
          return;
        }

        // Sincronizar FCM en segundo plano.
        unawaited(PushNotificationService.syncToken());

        _navigateToHome();
        return;
      }

      _navigateToWelcome();
    } catch (e) {
      debugPrint(
        '💥 Error en auth check (red/splash): $e. '
        'Manteniendo sesión local si existen tokens.',
      );

      if (!mounted) return;

      // Fallback: si existen tokens locales, no expulsamos al usuario
      // por un problema temporal de red/backend.
      final accessToken = await storage.read(key: "auth_token");
      final refreshToken = await storage.read(key: "refresh_token");

      final hasToken = accessToken != null || refreshToken != null;

      if (hasToken) {
        final paisId = await storage.read(key: "pais_id");

        if (!mounted) return;

        if (paisId == null || paisId.isEmpty || paisId == "null") {
          await _navigateToRegistration();
          return;
        }

        unawaited(PushNotificationService.syncToken());
        _navigateToHome();
        return;
      }

      _navigateToWelcome();
    }
  }

  Future<void> _navigateToRegistration() async {
    if (!mounted || _hasNavigated) return;

    final userId = await storage.read(key: "user_id");
    final name = await storage.read(key: "name");
    final email = await storage.read(key: "email");

    if (!mounted || _hasNavigated) return;

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
                  "assets/images/logo_letras_.png",
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
                    "assets/images/logo_letras_.png",
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
