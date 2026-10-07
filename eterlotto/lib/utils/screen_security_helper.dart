import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Politica global: solamente Inicio (pestana 0) y Perfil permiten capturas.
/// En Android activa FLAG_SECURE para las demas pantallas y los dialogos.
/// En iOS el sistema no proporciona un bloqueo equivalente garantizado.
class ScreenSecurityHelper {
  ScreenSecurityHelper._();

  static const MethodChannel _channel =
      MethodChannel('com.lumieter.eterlotto/security');

  static final NavigatorObserver navigatorObserver = _CaptureRouteObserver();

  static Route<dynamic>? _topRoute;
  static bool _isHomeTab = true;
  static bool? _lastRequestedSecurity;
  static bool? _lastAppliedSecurity;
  static Future<void> _pendingOperation = Future<void>.value();

  static bool _isPublicRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == '/profile' || (name == '/home' && _isHomeTab);
  }

  static void onHomeTabChanged(int index) {
    _isHomeTab = index == 0;
    _requestSecuritySync();
  }

  static void _onTopRouteChanged(Route<dynamic>? route) {
    _topRoute = route;
    _requestSecuritySync();
  }

  static void _requestSecuritySync() {
    // Valor por defecto SEGURO; se desactiva solamente en Home o Perfil.
    // En compilaciones debug, permitir capturas para pruebas y ajustes.
    // En profile/release se mantiene la regla: solo Home y Perfil.
    final protect = !kDebugMode && !_isPublicRoute(_topRoute);
    if (_lastRequestedSecurity == protect) return;
    _lastRequestedSecurity = protect;

    // Serializar mensajes al nativo evita carreras al navegar rapidamente.
    _pendingOperation = _pendingOperation.then((_) async {
      final latest = _lastRequestedSecurity ?? true;
      if (_lastAppliedSecurity == latest) return;
      if (kIsWeb || !Platform.isAndroid) return;

      try {
        await _channel.invokeMethod<void>(
          latest ? 'enableSecureScreen' : 'disableSecureScreen',
        );
        _lastAppliedSecurity = latest;
      } on MissingPluginException {
        // Solo Android proporciona el canal nativo en esta implementacion.
      } on PlatformException catch (error) {
        debugPrint('[SECURITY] No se pudo actualizar FLAG_SECURE: $error');
      }
    });
  }

  // Compatibilidad con invocaciones antiguas: la politica centralizada debe
  // ser la unica fuente de verdad; el observador controla las nuevas pantallas.
  @Deprecated('Usar ScreenSecurityHelper.navigatorObserver')
  static Future<void> enableSecureScreen() async {
    _requestSecuritySync();
    await _pendingOperation;
  }

  @Deprecated('Usar ScreenSecurityHelper.navigatorObserver')
  static Future<void> disableSecureScreen() async {
    _requestSecuritySync();
    await _pendingOperation;
  }
}

class _CaptureRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  void _synchronize() {
    ScreenSecurityHelper._onTopRouteChanged(
      _routes.isNotEmpty ? _routes.last : null,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _routes.add(route);

    // No liberar la captura hasta que la pantalla publica termine de entrar;
    // durante la transicion aun puede verse una pantalla protegida detras.
    if (ScreenSecurityHelper._isPublicRoute(route) &&
        !ScreenSecurityHelper._isPublicRoute(previousRoute) &&
        route is TransitionRoute<dynamic>) {
      final animation = route.animation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        ScreenSecurityHelper._onTopRouteChanged(null);
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.completed ||
              status == AnimationStatus.dismissed) {
            animation.removeStatusListener(onStatus);
            _synchronize();
          }
        }
        animation.addStatusListener(onStatus);
        return;
      }
    }
    _synchronize();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    final next = _routes.isEmpty ? null : _routes.last;

    // Si una ruta protegida se cierra hacia Home/Perfil, la captura se habilita
    // solo cuando termine la animacion de salida de la ruta protegida.
    if (!ScreenSecurityHelper._isPublicRoute(route) &&
        ScreenSecurityHelper._isPublicRoute(next)) {
      ScreenSecurityHelper._onTopRouteChanged(null);
      if (route is TransitionRoute<dynamic>) {
        unawaited(route.completed.then((_) => _synchronize()));
      } else {
        _synchronize();
      }
    } else {
      _synchronize();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _synchronize();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final position = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (position >= 0) {
      _routes.removeAt(position);
      if (newRoute != null) _routes.insert(position, newRoute);
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _synchronize();
  }
}
