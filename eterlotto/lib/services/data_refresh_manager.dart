import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/services/cache_service.dart';

/// Tipos de módulos estándar en Eterlotto
class RefreshModules {
  static const String home = "home";
  static const String resultados = "resultados";
  static const String jugadas = "jugadas";
  static const String loterias = "loterias";
  static const String publicidad = "publicidad";
  static const String perfil = "perfil";
  static const String prediccion = "prediccion";
  static const String notificaciones = "notificaciones";
}

/// Gestor centralizado de ciclo de vida y coherencia de datos.
///
/// Estrategia:
/// - La app conserva caché local para abrir rápido.
/// - Cada 5 minutos consulta únicamente /metadata/data-version.
/// - Ese endpoint vive en memoria del backend y NO consulta Supabase.
/// - Si Airflow terminó un modelo, invalida la caché backend y cambia la
///   versión. Flutter detecta el cambio, borra sólo cachés dinámicas y emite
///   una única señal global.
/// - Como red de seguridad, el catálogo expira a los 15 minutos aunque la
///   invalidación remota no esté disponible.
class DataRefreshManager with WidgetsBindingObserver {
  DataRefreshManager._privateConstructor();
  static final DataRefreshManager instance =
      DataRefreshManager._privateConstructor();

  bool _isInitialized = false;
  bool _checkingServerVersion = false;
  Timer? _periodicTimer;

  final Map<String, DateTime> _lastUpdateTimestamps = {};

  final Map<String, Duration> _defaultTtls = {
    RefreshModules.home: const Duration(minutes: 15),
    RefreshModules.resultados: const Duration(minutes: 10),
    RefreshModules.jugadas: const Duration(minutes: 2),
    RefreshModules.loterias: const Duration(minutes: 15),
    RefreshModules.publicidad: const Duration(minutes: 10),
    RefreshModules.perfil: const Duration(minutes: 5),
    RefreshModules.prediccion: const Duration(minutes: 15),
    RefreshModules.notificaciones: const Duration(minutes: 2),
  };

  final ValueNotifier<String?> refreshNotifier = ValueNotifier<String?>(null);

  DateTime? _pausedTimestamp;

  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // Primera comprobación: si la app se actualizó y todavía tiene una caché
    // antigua, se limpia una sola vez sin bloquear el arranque.
    unawaited(_checkServerDataVersion());

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _checkServerDataVersion();

      // Fallback: si por algún motivo Airflow no pudo notificar al backend,
      // el catálogo nunca queda congelado durante horas.
      if (isExpired(RefreshModules.loterias)) {
        requestRefresh(RefreshModules.loterias);
      }
    });
  }

  void dispose() {
    if (!_isInitialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _isInitialized = false;
  }

  void markUpdated(String module) {
    _lastUpdateTimestamps[module] = DateTime.now();
  }

  bool isExpired(String module, {Duration? customTtl}) {
    final lastUpdate = _lastUpdateTimestamps[module];
    if (lastUpdate == null) return true;

    final ttl =
        customTtl ?? _defaultTtls[module] ?? const Duration(minutes: 5);
    return DateTime.now().difference(lastUpdate) >= ttl;
  }

  Duration? getElapsedTime(String module) {
    final lastUpdate = _lastUpdateTimestamps[module];
    if (lastUpdate == null) return null;
    return DateTime.now().difference(lastUpdate);
  }

  void requestRefresh(String module) {
    refreshNotifier.value = module;
    Future.microtask(() => refreshNotifier.value = null);
  }

  void requestRefreshAll() {
    requestRefresh('all');
  }

  Future<void> _checkServerDataVersion() async {
    if (_checkingServerVersion) return;
    _checkingServerVersion = true;

    try {
      final remoteVersion = await ApiService.getDataVersion();
      if (remoteVersion == null) return;

      final localVersion = await CacheService.getServerDataVersion();

      // Migración de instalaciones que todavía no conocían data-version:
      // limpiamos una sola vez para no heredar el catálogo de 12 horas.
      if (localVersion == null) {
        await CacheService.invalidateLotteryCatalogCaches();
        await CacheService.setServerDataVersion(remoteVersion);
        requestRefresh(RefreshModules.loterias);
        return;
      }

      if (remoteVersion != localVersion) {
        await CacheService.invalidateLotteryCatalogCaches();
        await CacheService.setServerDataVersion(remoteVersion);

        // Todas las pantallas activas reciben la misma señal. Las que no estén
        // montadas encontrarán la caché invalidada cuando se abran.
        requestRefresh(RefreshModules.loterias);
      }
    } finally {
      _checkingServerVersion = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedTimestamp = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final inBackgroundDuration = _pausedTimestamp != null
          ? now.difference(_pausedTimestamp!)
          : Duration.zero;

      if (inBackgroundDuration.inSeconds >= 10 || _pausedTimestamp == null) {
        unawaited(_checkServerDataVersion());
        _evaluateAndTriggerRefreshes();
      }
      _pausedTimestamp = null;
    }
  }

  void _evaluateAndTriggerRefreshes() {
    for (final entry in _defaultTtls.entries) {
      if (isExpired(entry.key, customTtl: entry.value)) {
        requestRefresh(entry.key);
      }
    }
  }
}
