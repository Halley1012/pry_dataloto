import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:eterlotto/config/navigation.dart';
import 'package:eterlotto/services/api_service.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}


class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones Eterlotto',
    description:
        'Canal principal para notificaciones en tiempo real y alertas de lotería',
    importance: Importance.max,
    playSound: true,
  );

  static void _log(String message) {
    debugPrint('[FCM] $message');
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 6));
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (_) => _openNotifications(),
      );

      final androidLocal = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidLocal?.createNotificationChannel(_channel);

      // Android 13+: asegura permiso también para las notificaciones locales
      // que mostramos cuando Eterlotto está en primer plano.
      await androidLocal?.requestNotificationsPermission();

      _foregroundSubscription ??=
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _openedSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen((_) {
        _openNotifications();
      });

      _tokenRefreshSubscription ??=
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _log('token refreshed');
        final synced = await ApiService.updateFCMToken(newToken);
        _log('refreshed token synced=$synced');
      });

      _initialized = true;
      _log('initialized');

      unawaited(_setupPermissionsAndToken());
      unawaited(_handleInitialMessage());
    } catch (e, stack) {
      _log('initialize failed: ${e.runtimeType}');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  static Future<void> _setupPermissionsAndToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
          .timeout(const Duration(seconds: 8));

      _log('permission=${settings.authorizationStatus.name}');

      final token = await messaging
          .getToken()
          .timeout(const Duration(seconds: 8));

      if (token == null || token.isEmpty) {
        _log('token unavailable');
        return;
      }

      _log('token obtained');
      final synced = await ApiService.updateFCMToken(token)
          .timeout(const Duration(seconds: 10));
      _log('token synced=$synced');
    } catch (e) {
      _log('permission/token setup failed: ${e.runtimeType}');
    }
  }

  static Future<void> syncToken() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log('sync skipped: permission denied');
        return;
      }

      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 8));

      if (token == null || token.isEmpty) {
        _log('sync skipped: token unavailable');
        return;
      }

      final synced = await ApiService.updateFCMToken(token)
          .timeout(const Duration(seconds: 10));
      _log('manual sync=$synced');
    } catch (e) {
      _log('manual sync failed: ${e.runtimeType}');
    }
  }

  static Future<void> unregisterToken() async {
    try {
      // Primero desvinculamos la cuenta actual del backend. No llamamos
      // deleteToken(): el mismo dispositivo puede iniciar otra cuenta y
      // Firebase puede reutilizar/renovar su token normalmente.
      final cleared = await ApiService.clearFCMToken()
          .timeout(const Duration(seconds: 8));
      _log('backend token cleared=$cleared');
    } catch (e) {
      _log('backend token clear failed: ${e.runtimeType}');
    }
  }

  static Future<void> _handleInitialMessage() async {
    try {
      final initial =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initial == null) return;

      // runApp ya fue ejecutado, pero damos un frame para que exista Navigator.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNotifications();
      });
    } catch (e) {
      _log('initial message failed: ${e.runtimeType}');
    }
  }

  static Future<void> _handleForegroundMessage(
    RemoteMessage message,
  ) async {
    _log('foreground message received');

    final notification = message.notification;
    if (notification == null) {
      _log('foreground message without notification payload');
      return;
    }

    try {
      await _localNotificationsPlugin.show(
        message.messageId?.hashCode ?? notification.hashCode,
        notification.title ?? 'Eterlotto',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/launcher_icon',
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
        payload: '/notifications',
      );
    } catch (e) {
      _log('foreground display failed: ${e.runtimeType}');
    }
  }

  static void _openNotifications() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        navigatorKey.currentState?.pushNamed('/notifications');
      });
      return;
    }
    navigator.pushNamed('/notifications');
  }
}
