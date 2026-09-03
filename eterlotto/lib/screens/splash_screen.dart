import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eterlotto/screens/registro.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:eterlotto/screens/update_screen.dart';

import '../utils/secure_storage_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final storage = AppSecureStorage.instance;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _controller.forward();
    _checkAuth();

    // 🛡️ Temporizador de seguridad: Si por cualquier motivo tarda más de 3.5s, forzar navegación a /welcome
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        debugPrint('🛡️ Safety timeout activado en SplashScreen -> navegando a /welcome');
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    });
  }

  Future<void> _checkAuth() async {
    try {
      final splashDelay = Future.delayed(const Duration(milliseconds: 1500));

      // 🛑 1. CHECK DE VERSIÓN OBLIGATORIA
      final appConfig = await ApiService.getAppConfig();
      if (appConfig != null && appConfig['success'] == true) {
        final minBuildNumber = appConfig['min_build_number'] as int? ?? 0;
        final packageInfo = await PackageInfo.fromPlatform();
        final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

        if (currentBuildNumber < minBuildNumber) {
          debugPrint('⚠️ VERSIÓN OBSOLETA: $currentBuildNumber. Se requiere $minBuildNumber');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UpdateScreen(
                androidUrl: appConfig['store_url_android'],
                iosUrl: appConfig['store_url_ios'],
              ),
            ),
          );
          return; // Detenemos todo, no hace login ni va al Home
        }
      }

      final accessToken = await storage.read(key: "auth_token").timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      final refreshToken = await storage.read(key: "refresh_token").timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      // Si no existe ningún token guardado, el usuario nunca ha iniciado sesión o hizo logout explícito
      if (accessToken == null && refreshToken == null) {
        await splashDelay;
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      // Validar o refrescar la sesión si hay conexión (con timeout estricto para evitar bloqueos)
      final hasSession = await ApiService.ensureValidSession().timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => (accessToken != null || refreshToken != null),
      );

      await splashDelay;
      if (!mounted) return;

      // Si la sesión es válida O si tenemos tokens guardados (ej. modo offline o lag de servidor), mantenemos en /home
      final stayLoggedIn =
          hasSession || (accessToken != null || refreshToken != null);

      if (stayLoggedIn) {
        final paisId = await storage.read(key: "pais_id");
        if (!mounted) return;
        if (paisId == null || paisId.isEmpty || paisId == "null") {
          final userId = await storage.read(key: "user_id");
          final name = await storage.read(key: "name");
          final email = await storage.read(key: "email");
          final user = {
            'id': int.tryParse(userId ?? '0'),
            'name': name,
            'email': email,
          };
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegistroScreen(
                user: user,
                userId: int.tryParse(userId ?? '0'),
                isSocialOnboarding: true,
              ),
            ),
          );
          return;
        }

        // 🔥 Sincronizar token FCM en segundo plano
        unawaited(PushNotificationService.syncToken());
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }

    } catch (e) {
      debugPrint(
        '💥 Error en auth check (red/splash): $e. Manteniendo sesión local si existen tokens.',
      );
      if (!mounted) return;

      final hasToken = (await storage.read(key: "auth_token")) != null ||
          (await storage.read(key: "refresh_token")) != null;

      if (hasToken) {
        final paisId = await storage.read(key: "pais_id");
        if (!mounted) return;
        if (paisId == null || paisId.isEmpty || paisId == "null") {
          final userId = await storage.read(key: "user_id");
          final name = await storage.read(key: "name");
          final email = await storage.read(key: "email");
          final user = {
            'id': int.tryParse(userId ?? '0'),
            'name': name,
            'email': email,
          };
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegistroScreen(
                user: user,
                userId: int.tryParse(userId ?? '0'),
                isSocialOnboarding: true,
              ),
            ),
          );
          return;
        }
        if (!mounted) return;
        PushNotificationService.syncToken();
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
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
