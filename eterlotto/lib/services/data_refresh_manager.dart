import 'dart:async';
import 'package:flutter/widgets.dart';

/// Tipos de módulos estándar en Eterlotto
class RefreshModules {
  static const String home = "home";
  static const String resultados = "resultados";
  static const String jugadas = "jugadas";
  static const String loterias = "loterias";
  static const String publicidad = "publicidad";
  static const String perfil = "perfil";
  static const String prediccion = "prediccion";
}

/// Gestor centralizado de ciclo de vida de Flutter y refresco inteligente con TTL.
///
/// Evita sobrecargar el backend con peticiones duplicadas y garantiza que
/// cuando la app regrese de segundo plano (resumed), solo se actualicen
/// los módulos cuyos datos realmente hayan expirado.
class DataRefreshManager with WidgetsBindingObserver {
  DataRefreshManager._privateConstructor();
  static final DataRefreshManager instance = DataRefreshManager._privateConstructor();

  bool _isInitialized = false;

  /// Registro de timestamps de última actualización por módulo/clave
  final Map<String, DateTime> _lastUpdateTimestamps = {};

  /// Tiempos de vida por defecto (TTL)
  final Map<String, Duration> _defaultTtls = {
    RefreshModules.home: const Duration(minutes: 5),
    RefreshModules.resultados: const Duration(minutes: 3),
    RefreshModules.jugadas: const Duration(minutes: 2),
    RefreshModules.loterias: const Duration(hours: 12),
    RefreshModules.publicidad: const Duration(minutes: 10),
    RefreshModules.perfil: const Duration(minutes: 5),
    RefreshModules.prediccion: const Duration(minutes: 15),
  };

  /// Notificador reactivo para emitir señales de actualización
  /// Emite el nombre del módulo que necesita refrescarse, o 'all'
  final ValueNotifier<String?> refreshNotifier = ValueNotifier<String?>(null);

  /// Timestamp del momento en que la app pasó a background (paused / inactive)
  DateTime? _pausedTimestamp;

  /// Inicializa el observador del ciclo de vida de Flutter
  void initialize() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    debugPrint("🔄 [DataRefreshManager] Inicializado y observando ciclo de vida.");
  }

  /// Libera el observador si es necesario
  void dispose() {
    if (!_isInitialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  /// Registra que un módulo se acaba de actualizar con éxito
  void markUpdated(String module) {
    _lastUpdateTimestamps[module] = DateTime.now();
    debugPrint("🕒 [DataRefreshManager] Módulo '$module' actualizado: ${_lastUpdateTimestamps[module]}");
  }

  /// Verifica si un módulo ha expirado según su TTL
  bool isExpired(String module, {Duration? customTtl}) {
    final lastUpdate = _lastUpdateTimestamps[module];
    if (lastUpdate == null) return true; // Nunca se ha cargado

    final ttl = customTtl ?? _defaultTtls[module] ?? const Duration(minutes: 5);
    final elapsed = DateTime.now().difference(lastUpdate);
    return elapsed >= ttl;
  }

  /// Obtiene el tiempo transcurrido desde la última actualización de un módulo
  Duration? getElapsedTime(String module) {
    final lastUpdate = _lastUpdateTimestamps[module];
    if (lastUpdate == null) return null;
    return DateTime.now().difference(lastUpdate);
  }

  /// Dispara una señal manual para refrescar un módulo específico
  void requestRefresh(String module) {
    refreshNotifier.value = module;
    // Reseteamos a null tras un tick para permitir re-notificaciones del mismo módulo
    Future.microtask(() => refreshNotifier.value = null);
  }

  /// Dispara una señal para refrescar toda la aplicación
  void requestRefreshAll() {
    requestRefresh('all');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedTimestamp = DateTime.now();
      debugPrint("⏸️ [DataRefreshManager] App en background a las $_pausedTimestamp");
    } else if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final inBackgroundDuration = _pausedTimestamp != null
          ? now.difference(_pausedTimestamp!)
          : Duration.zero;

      debugPrint("▶️ [DataRefreshManager] App resumed. Estuvo en background: ${inBackgroundDuration.inSeconds}s");

      // Solo evaluamos refresco si estuvo en background al menos 10 segundos
      if (inBackgroundDuration.inSeconds >= 10 || _pausedTimestamp == null) {
        _evaluateAndTriggerRefreshes();
      }
      _pausedTimestamp = null;
    }
  }

  /// Evalúa cuáles módulos han expirado y emite la notificación correspondiente
  void _evaluateAndTriggerRefreshes() {
    final expiredModules = <String>[];

    for (final entry in _defaultTtls.entries) {
      final module = entry.key;
      final ttl = entry.value;
      if (isExpired(module, customTtl: ttl)) {
        expiredModules.add(module);
      }
    }

    if (expiredModules.isNotEmpty) {
      debugPrint("⚡ [DataRefreshManager] Módulos expirados tras resume: $expiredModules");
      // Notificar a los listeners activos
      for (final mod in expiredModules) {
        requestRefresh(mod);
      }
    } else {
      debugPrint("✅ [DataRefreshManager] Todos los módulos están vigentes dentro de su TTL. No se requiere refresco.");
    }
  }
}
