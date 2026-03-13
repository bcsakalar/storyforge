import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  final ApiService _api;
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _currentToken;

  PushNotificationService(this._api);

  Future<void> init() async {
    // Skip push notifications on web — requires separate Firebase web config
    if (kIsWeb) return;

    try {
      _messaging = FirebaseMessaging.instance;
    } catch (_) {
      return;
    }

    // Request permission
    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Setup local notifications for foreground
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create Android notification channel
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        'storyforge_default',
        'StoryForge Bildirimleri',
        description: 'StoryForge uygulama bildirimleri',
        importance: Importance.high,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Get and register token
    await _registerToken();

    // Listen for token refresh
    _messaging!.onTokenRefresh.listen((token) => _registerTokenValue(token));
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        await _registerTokenValue(token);
      }
    } catch (_) {}
  }

  Future<void> _registerTokenValue(String token) async {
    _currentToken = token;
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await _api.post('/device-token', data: {'token': token, 'platform': platform});
    } catch (_) {}
  }

  Future<void> removeToken() async {
    if (_currentToken != null) {
      try {
        await _api.delete('/device-token', data: {'token': _currentToken});
      } catch (_) {}
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'storyforge_default',
          'StoryForge Bildirimleri',
          channelDescription: 'StoryForge uygulama bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
