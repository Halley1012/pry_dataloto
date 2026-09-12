import 'dart:async';

import 'package:flutter/material.dart';
import 'package:eterlotto/models/notification_model.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/services/data_refresh_manager.dart';
import 'package:eterlotto/services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _activeUserId;
  bool _userContextInitialized = false;
  bool _hasCachedSnapshot = false;
  bool _showingStaleData = false;
  bool _lastFetchFailed = false;
  Set<String> _playedLotteryRoutes = <String>{};
  bool _playedRoutesResolved = false;
  Future<void>? _fetchFuture;
  String? _fetchUserId;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasCachedSnapshot => _hasCachedSnapshot;
  bool get showingStaleData => _showingStaleData;
  bool get lastFetchFailed => _lastFetchFailed;
  Set<String> get playedLotteryRoutes =>
      Set<String>.unmodifiable(_playedLotteryRoutes);
  bool get playedRoutesResolved => _playedRoutesResolved;
  int get unreadCount => _notifications.where((n) => !n.leido).length;

  NotificationProvider() {
    _ensureUserContext();
    DataRefreshManager.instance.refreshNotifier.addListener(
      _onDataRefreshNotification,
    );
  }

  String _cacheKey(String? userId) =>
      CacheService.notificacionesUsuarioKey(userId);

  /// Las notificaciones contienen estado privado (leída/eliminada), por eso la
  /// caché debe cambiar inmediatamente al cambiar de cuenta en el dispositivo.
  Future<void> _ensureUserContext() async {
    final userId = (await ApiService.getUserId())?.toString();
    if (_userContextInitialized && _activeUserId == userId) return;

    _userContextInitialized = true;
    _activeUserId = userId;
    _notifications = [];
    _hasCachedSnapshot = false;
    _showingStaleData = false;
    _lastFetchFailed = false;
    _playedLotteryRoutes = <String>{};
    _playedRoutesResolved = false;
    _isLoading = false;
    notifyListeners();
    // No existe un buzón privado para una sesión anónima. Evita que una
    // eventual entrada legacy `anon` aparezca antes del próximo login.
    if (userId == null) return;
    await Future.wait([
      _loadFromCache(userId),
      _loadPlayedRoutesFromCache(userId),
    ]);
  }

  Future<bool> _isCurrentUser(String? userId) async {
    if (_activeUserId != userId) return false;
    return (await ApiService.getUserId())?.toString() == userId;
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.home ||
        module == RefreshModules.notificaciones ||
        module == RefreshModules.jugadas ||
        module == 'all') {
      fetchNotifications();
    }
  }

  Set<String> _routesFromInfo(dynamic info) {
    if (info is! Map) return <String>{};
    final routes = <String>{};
    for (final entry in info.entries) {
      final value = entry.value;
      if (value is Map && value['route'] != null) {
        final route = value['route'].toString().trim().toLowerCase();
        if (route.isNotEmpty) routes.add(route);
        continue;
      }
      // Compatibilidad con el formato legacy {route: {...}}.
      final key = entry.key.toString().trim().toLowerCase();
      if (key.isNotEmpty && !key.startsWith('route:') && int.tryParse(key) == null) {
        routes.add(key);
      } else if (key.startsWith('route:')) {
        final route = key.substring('route:'.length);
        if (route.isNotEmpty) routes.add(route);
      }
    }
    return routes;
  }

  Future<void> _loadPlayedRoutesFromCache(String userId) async {
    final cached = await CacheService.getStaleJson(
      CacheService.infoMisJugadasKey(userId),
    );
    if (!await _isCurrentUser(userId)) return;
    _playedLotteryRoutes = _routesFromInfo(cached);
    _playedRoutesResolved = true;
    notifyListeners();
  }

  Future<void> _refreshPlayedRoutesForUser(String userId) async {
    try {
      final info = await ApiService.getLoteriasInfoJugadas();
      if (!await _isCurrentUser(userId)) return;

      // Las rutas anteriores sólo se sustituyen por una respuesta útil. Las
      // APIs legacy devuelven {} al no tener red, lo cual no debe ocultar las
      // internacionales que el usuario ya tenía guardadas.
      if (info.isNotEmpty) {
        _playedLotteryRoutes = _routesFromInfo(info);
        await CacheService.setJson(
          CacheService.infoMisJugadasKey(userId),
          info,
        );
      }
      _playedRoutesResolved = true;
      notifyListeners();
    } catch (_) {
      if (!await _isCurrentUser(userId)) return;
      _playedRoutesResolved = true;
      notifyListeners();
    }
  }

  Future<void> _loadFromCache([String? userId]) async {
    final cacheUserId = userId ?? _activeUserId;
    final fresh = await CacheService.getJson(_cacheKey(cacheUserId));
    final cached =
        fresh ?? await CacheService.getStaleJson(_cacheKey(cacheUserId));
    if (cached is List && await _isCurrentUser(cacheUserId)) {
      try {
        final loaded = cached
            .map(
              (item) => NotificationModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        // La clave se valida de nuevo después de parsear: la carga de la
        // cuenta anterior jamás puede reemplazar a la actual.
        if (!await _isCurrentUser(cacheUserId)) return;
        _notifications = loaded;
        _hasCachedSnapshot = true;
        _showingStaleData = fresh == null && loaded.isNotEmpty;
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> _saveCache(String? userId, List<NotificationModel> snapshot) {
    return CacheService.setJson(
      _cacheKey(userId),
      snapshot.map((notification) => notification.toJson()).toList(),
    );
  }

  Future<void> fetchNotifications({bool force = false}) async {
    await _ensureUserContext();
    final userId = _activeUserId;
    if (userId == null) return;

    final inFlight = _fetchFuture;
    if (inFlight != null && _fetchUserId == userId) return inFlight;

    final future = _fetchForUser(userId, force: force);
    _fetchFuture = future;
    _fetchUserId = userId;
    try {
      await future;
    } finally {
      if (identical(_fetchFuture, future)) {
        _fetchFuture = null;
        _fetchUserId = null;
      }
    }
  }

  Future<void> _fetchForUser(String userId, {required bool force}) async {
    if (!await _isCurrentUser(userId)) return;
    if (_notifications.isEmpty || force) {
      _isLoading = true;
      notifyListeners();
    }

    // La lista de loterías jugadas es privada, pero se actualiza aparte para
    // no retrasar la primera pintura de las notificaciones.
    unawaited(_refreshPlayedRoutesForUser(userId));

    try {
      final fresh = await NotificationService.getNotifications();
      if (!await _isCurrentUser(userId)) return;
      _notifications = fresh;
      _hasCachedSnapshot = true;
      _showingStaleData = false;
      _lastFetchFailed = false;
      await _saveCache(userId, fresh);
      DataRefreshManager.instance.markUpdated(RefreshModules.notificaciones);
    } catch (_) {
      if (!await _isCurrentUser(userId)) return;
      _lastFetchFailed = true;
      _showingStaleData = _hasCachedSnapshot && _notifications.isNotEmpty;
    } finally {
      if (await _isCurrentUser(userId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markAsRead(int id) async {
    await _ensureUserContext();
    final userId = _activeUserId;
    if (userId == null || !await _isCurrentUser(userId)) return;
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index == -1 || _notifications[index].leido) return;

    final previous = _notifications[index];
    _notifications[index] = previous.copyWith(leido: true);
    final optimistic = List<NotificationModel>.from(_notifications);
    notifyListeners();
    await _saveCache(userId, optimistic);

    try {
      await NotificationService.markAsRead(id);
    } catch (_) {
      if (!await _isCurrentUser(userId)) return;
      final currentIndex = _notifications.indexWhere(
        (notification) => notification.id == id,
      );
      if (currentIndex == -1) return;
      _notifications[currentIndex] = previous;
      notifyListeners();
      await _saveCache(userId, List<NotificationModel>.from(_notifications));
    }
  }

  Future<void> markAllAsRead() async {
    await _ensureUserContext();
    final userId = _activeUserId;
    if (userId == null || !await _isCurrentUser(userId)) return;
    final unreadIds = _notifications
        .where((notification) => !notification.leido)
        .map((notification) => notification.id)
        .toList();
    if (unreadIds.isEmpty) return;

    final previous = List<NotificationModel>.from(_notifications);
    _notifications = _notifications
        .map(
          (notification) => notification.leido
              ? notification
              : notification.copyWith(leido: true),
        )
        .toList();
    notifyListeners();
    await _saveCache(userId, List<NotificationModel>.from(_notifications));

    final results = await Future.wait<bool>(
      unreadIds.map((id) async {
        try {
          await NotificationService.markAsRead(id);
          return true;
        } catch (_) {
          return false;
        }
      }),
    );
    if (results.every((success) => success) || !await _isCurrentUser(userId)) {
      return;
    }

    // Revierte únicamente los avisos que fallaron. No se restaura un snapshot
    // completo, porque una actualización SWR podría haber llegado mientras
    // las peticiones estaban en curso.
    final previousById = {
      for (final notification in previous) notification.id: notification,
    };
    final failedIds = <int>{
      for (var index = 0; index < unreadIds.length; index++)
        if (!results[index]) unreadIds[index],
    };
    _notifications = _notifications
        .map(
          (notification) => failedIds.contains(notification.id)
              ? (previousById[notification.id] ?? notification)
              : notification,
        )
        .toList();
    notifyListeners();
    await _saveCache(userId, List<NotificationModel>.from(_notifications));
  }

  Future<bool> deleteNotification(int id) async {
    await _ensureUserContext();
    final userId = _activeUserId;
    if (userId == null || !await _isCurrentUser(userId)) return false;
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index == -1) return false;

    final removed = _notifications.removeAt(index);
    notifyListeners();
    await _saveCache(userId, List<NotificationModel>.from(_notifications));

    try {
      await NotificationService.deleteNotification(id);
      return true;
    } catch (_) {
      if (!await _isCurrentUser(userId)) return false;
      if (!_notifications.any((notification) => notification.id == id)) {
        _notifications.insert(
          index.clamp(0, _notifications.length).toInt(),
          removed,
        );
      }
      notifyListeners();
      await _saveCache(userId, List<NotificationModel>.from(_notifications));
      return false;
    }
  }
}
