import 'dart:async';
import 'package:flutter/foundation.dart';
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
///   versión. Flutter detecta el cambio, CONSERVA el último dato local visible
///   y emite una señal para revalidar en segundo plano.
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

  void _devLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // Las marcas sobreviven a un cierre completo del proceso. Sin esto, cada
    // cold start hacía que todos los módulos parecieran vencidos.
    final persisted = await CacheService.getModuleLastUpdates(
      _defaultTtls.keys,
    );
    _lastUpdateTimestamps.addAll(persisted);

    // data-version sólo dispara revalidación. Nunca elimina primero el último
    // dato conocido, porque eso convertiría un refresh de fondo en skeleton.
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
    final now = DateTime.now();
    _lastUpdateTimestamps[module] = now;
    unawaited(CacheService.setModuleLastUpdate(module, now));
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
      _devLog('[DATA VERSION] comprobando servidor...');

      final remoteVersion = await ApiService.getDataVersion();
      if (remoteVersion == null) {
        _devLog('[DATA VERSION] remote=null -> no se refresca');
        return;
      }

      final localVersion = await CacheService.getServerDataVersion();

      _devLog('[DATA VERSION] local=$localVersion');
      _devLog('[DATA VERSION] remote=$remoteVersion');

      // Primera instalación con data-version: registramos la versión sin
      // destruir una caché que todavía puede pintar la interfaz al instante.
      if (localVersion == null) {
        await CacheService.setServerDataVersion(remoteVersion);
        _devLog('[CACHE] version local inicializada=$remoteVersion');
        requestRefresh(RefreshModules.loterias);
        return;
      }

      if (remoteVersion != localVersion) {
        _devLog('[CACHE] CAMBIO DETECTADO $localVersion -> $remoteVersion');
        await CacheService.setServerDataVersion(remoteVersion);

        // Stale-while-revalidate real: el contenido anterior permanece visible
        // hasta que cada pantalla haya descargado y guardado el reemplazo.
        _devLog('[CACHE] conservando stale y revalidando loterias');
        requestRefresh(RefreshModules.loterias);
      } else {
        _devLog('[DATA VERSION] sin cambios');
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
