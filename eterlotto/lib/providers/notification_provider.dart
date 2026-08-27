import 'package:flutter/material.dart';
import 'package:eterlotto/models/notification_model.dart';
import 'package:eterlotto/services/notification_service.dart';
import 'package:eterlotto/services/cache_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.leido).length;

  NotificationProvider() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final cached = await CacheService.getJson('notifications_cache');
    if (cached != null && cached is List && _notifications.isEmpty) {
      _notifications = cached.map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item))).toList();
      notifyListeners();
    }
  }

  Future<void> fetchNotifications({bool force = false}) async {
    if (_notifications.isEmpty || force) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final fresh = await NotificationService.getNotifications();
      _notifications = fresh;
      final rawList = fresh.map((n) => n.toJson()).toList();
      CacheService.setJson('notifications_cache', rawList);
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await NotificationService.markAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(leido: true);
        notifyListeners();
        final rawList = _notifications.map((n) => n.toJson()).toList();
        CacheService.setJson('notifications_cache', rawList);
      }
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].leido) {
        changed = true;
        final notifId = _notifications[i].id;
        _notifications[i] = _notifications[i].copyWith(leido: true);
        NotificationService.markAsRead(notifId).catchError((e) {
          debugPrint("Error marking notification $notifId as read: $e");
        });
      }
    }
    if (changed) {
      notifyListeners();
      final rawList = _notifications.map((n) => n.toJson()).toList();
      CacheService.setJson('notifications_cache', rawList);
    }
  }

  Future<void> deleteNotification(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications.removeAt(index);
      notifyListeners();

      final rawList = _notifications.map((n) => n.toJson()).toList();
      CacheService.setJson('notifications_cache', rawList);

      try {
        await NotificationService.deleteNotification(id);
      } catch (e) {
        debugPrint("Error deleting notification from server: $e");
        // No reinsertamos para evitar parpadeos molestos en UI si fue eliminada localmente
      }
    }
  }
}

