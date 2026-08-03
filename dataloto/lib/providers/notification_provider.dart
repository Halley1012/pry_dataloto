import 'package:flutter/material.dart';
import 'package:dataloto/models/notification_model.dart';
import 'package:dataloto/services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.leido).length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await NotificationService.getNotifications();
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
        // Creamos una nueva instancia con leido=true para actualizar el UI
        final old = _notifications[index];
        _notifications[index] = NotificationModel(
          id: old.id,
          loteriaId: old.loteriaId,
          fechaSorteo: old.fechaSorteo,
          mensaje: old.mensaje,
          tipo: old.tipo,
          leido: true,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }
}
