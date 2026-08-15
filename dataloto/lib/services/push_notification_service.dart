import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dataloto/services/api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 Notificación Push en segundo plano recibida: ${message.notification?.title}");
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'Notificaciones DataLoto', // title
    description: 'Canal principal para notificaciones en tiempo real y alertas de lotería',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();

      // Configurar handler en segundo plano
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Solicitar permisos de notificación (Android 13+ / iOS)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint("🔔 Permiso de Notificaciones: ${settings.authorizationStatus}");

      // Configurar canal de notificaciones locales en Android
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Obtener y enviar el token FCM al backend
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint("🔥 FCM Token obtenido: $token");
        await ApiService.updateFCMToken(token);
      }

      // Escuchar renovación de token
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint("🔄 FCM Token renovado: $newToken");
        ApiService.updateFCMToken(newToken);
      });

      // Escuchar notificaciones en primer plano (App abierta)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("📩 Notificación Push en primer plano recibida: ${message.notification?.title}");

        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null) {
          // 1. Mostrar notificación de sistema (barra de estado)
          _localNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android?.smallIcon ?? '@mipmap/launcher_icon',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );

          // 2. Opcionalmente disparar un refresco de datos en la app
          // Podemos usar un stream o un callback si fuera necesario
        }
      });
    } catch (e) {
      debugPrint("⚠️ Error configurando PushNotificationService: $e");
    }
  }

  /// 🔄 Sincronizar el token FCM actual con el backend para el usuario autenticado
  static Future<void> syncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint("🔥 FCM Token obtenido en sync: $token");
        await ApiService.updateFCMToken(token);
      }
    } catch (e) {
      debugPrint("⚠️ Error sincronizando token FCM: $e");
    }
  }
}
