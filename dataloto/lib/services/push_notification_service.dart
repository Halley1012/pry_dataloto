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
      await Firebase.initializeApp().timeout(const Duration(seconds: 4));

      // Configurar handler en segundo plano
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

      // Escuchar notificaciones en primer plano (App abierta)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("📩 Notificación Push en primer plano recibida: ${message.notification?.title}");

        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null) {
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
        }
      });

      // Escuchar renovación de token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint("🔄 FCM Token renovado: $newToken");
        ApiService.updateFCMToken(newToken);
      });

      // Solicitar permisos y obtener token en segundo plano (sin bloquear el arranque)
      _setupPermissionsAndToken();
    } catch (e) {
      debugPrint("⚠️ Error configurando PushNotificationService: $e");
    }
  }

  static void _setupPermissionsAndToken() {
    Future.microtask(() async {
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        ).timeout(const Duration(seconds: 5));

        debugPrint("🔔 Permiso de Notificaciones: ${settings.authorizationStatus}");

        final token = await messaging.getToken().timeout(const Duration(seconds: 6));
        if (token != null) {
          debugPrint("🔥 FCM Token obtenido: $token");
          await ApiService.updateFCMToken(token).timeout(const Duration(seconds: 8));
        }
      } catch (e) {
        debugPrint("⚠️ Error en segundo plano de token/permisos FCM: $e");
      }
    });
  }

  /// 🔄 Sincronizar el token FCM actual con el backend para el usuario autenticado
  static Future<void> syncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
      if (token != null && token.isNotEmpty) {
        debugPrint("🔥 FCM Token obtenido en sync: $token");
        await ApiService.updateFCMToken(token).timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint("⚠️ Error sincronizando token FCM: $e");
    }
  }
}

