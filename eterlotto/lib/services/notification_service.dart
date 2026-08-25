import 'dart:convert';
import 'package:eterlotto/models/notification_model.dart';
import 'package:eterlotto/services/api_service.dart';

class NotificationService {
  static Future<List<NotificationModel>> getNotifications() async {
    final response = await ApiService.get("/notifications/");
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => NotificationModel.fromJson(json)).toList();
    } else {
      throw Exception("Error al obtener notificaciones: ${response.statusCode}");
    }
  }

  static Future<void> markAsRead(int id) async {
    final response = await ApiService.post("/notifications/$id/read", {});
    if (response.statusCode != 200) {
      throw Exception("Error al marcar como leída");
    }
  }

  static Future<void> deleteNotification(int id) async {
    final response = await ApiService.delete("/notifications/$id");
    if (response.statusCode != 200) {
      throw Exception("Error al eliminar notificación");
    }
  }
}

