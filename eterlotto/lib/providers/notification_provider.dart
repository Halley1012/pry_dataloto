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

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.leido).length;

  NotificationProvider() {
    _ensureUserContext();
    DataRefreshManager.instance.refreshNotifier.addListener(_onDataRefreshNotification);
  }

  String _cacheKey(String? userId) => 'notifications_cache_${userId ?? 'anon'}';

  /// Las notificaciones contienen estado privado (leída/eliminada), por eso la
  /// caché debe cambiar inmediatamente al cambiar de cuenta en el dispositivo.
  Future<void> _ensureUserContext() async {
    final userId = (await ApiService.getUserId())?.toString();
    if (_userContextInitialized && _activeUserId == userId) return;

    _userContextInitialized = true;
    _activeUserId = userId;
    _notifications = [];
    await _loadFromCache(userId);
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.home || module == 'all') {
      fetchNotifications();
    }
  }

  Future<void> _loadFromCache([String? userId]) async {
    final cached = await CacheService.getJson(_cacheKey(userId ?? _activeUserId));
    if (cached is List && _notifications.isEmpty) {
      try {
        _notifications = cached
            .map((item) => NotificationModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error leyendo caché de notificaciones: $e');
      }
    }
  }

  Future<void> _saveCache() {
    return CacheService.setJson(
      _cacheKey(_activeUserId),
      _notifications.map((notification) => notification.toJson()).toList(),
    );
  }

  Future<void> fetchNotifications({bool force = false}) async {
    await _ensureUserContext();
    if (_notifications.isEmpty || force) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final fresh = await NotificationService.getNotifications();
      _notifications = fresh;
      await _saveCache();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    await _ensureUserContext();
    final index = _notifications.indexWhere((notification) => notification.id == id);
    if (index == -1 || _notifications[index].leido) return;

    final previous = _notifications[index];
    _notifications[index] = previous.copyWith(leido: true);
    notifyListeners();
    await _saveCache();

    try {
      await NotificationService.markAsRead(id);
    } catch (e) {
      _notifications[index] = previous;
      notifyListeners();
      await _saveCache();
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    await _ensureUserContext();
    final unreadIds = _notifications
        .where((notification) => !notification.leido)
        .map((notification) => notification.id)
        .toList();
    if (unreadIds.isEmpty) return;

    final previous = List<NotificationModel>.from(_notifications);
    _notifications = _notifications
        .map((notification) => notification.leido
            ? notification
            : notification.copyWith(leido: true))
        .toList();
    notifyListeners();
    await _saveCache();

    final results = await Future.wait<bool>(
      unreadIds.map((id) async {
        try {
          await NotificationService.markAsRead(id);
          return true;
        } catch (e) {
          debugPrint('Error marking notification $id as read: $e');
          return false;
        }
      }),
    );
    if (results.every((success) => success)) return;

    // Recupera del servidor el estado que no se pudo sincronizar.
    _notifications = previous;
    notifyListeners();
    await _saveCache();
  }

  Future<bool> deleteNotification(int id) async {
    await _ensureUserContext();
    final index = _notifications.indexWhere((notification) => notification.id == id);
    if (index == -1) return false;

    final removed = _notifications.removeAt(index);
    notifyListeners();
    await _saveCache();

    try {
      await NotificationService.deleteNotification(id);
      return true;
    } catch (e) {
      _notifications.insert(index, removed);
      notifyListeners();
      await _saveCache();
      debugPrint('Error deleting notification from server: $e');
      return false;
    }
  }
}
