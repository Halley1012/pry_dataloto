import 'package:flutter/material.dart';
import 'package:dataloto/models/notification_model.dart';
import 'package:dataloto/services/notification_service.dart';
import 'package:dataloto/services/cache_service.dart';

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

  Future<void> fetchNotifications() async {
    if (_notifications.isEmpty) {
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
        final old = _notifications[index];
        _notifications[index] = NotificationModel(
          id: old.id,
          loteriaId: old.loteriaId,
          paisId: old.paisId,
          fechaSorteo: old.fechaSorteo,
          mensaje: old.mensaje,
          tipo: old.tipo,
          leido: true,
          createdAt: old.createdAt,
        );
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
        final old = _notifications[i];
        _notifications[i] = NotificationModel(
          id: old.id,
          loteriaId: old.loteriaId,
          paisId: old.paisId,
          fechaSorteo: old.fechaSorteo,
          mensaje: old.mensaje,
          tipo: old.tipo,
          leido: true,
          createdAt: old.createdAt,
        );
        NotificationService.markAsRead(old.id).catchError((e) {
          debugPrint("Error marking notification $old.id as read: $e");
        });
      }
    }
    if (changed) {
      notifyListeners();
      final rawList = _notifications.map((n) => n.toJson()).toList();
      CacheService.setJson('notifications_cache', rawList);
    }
  }
}
