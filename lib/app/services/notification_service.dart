import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  /// Same id as the meta-data value in AndroidManifest.xml.
  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High importance notifications',
    description: 'Shown while the app is in the foreground.',
    importance: Importance.high,
  );

  void Function(RemoteMessage message)? onMessage;

  Future<void> init() async {
    // iOS (and Android 13 via the local-notifications plugin below) shows a system dialog.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped. Payload: ${response.payload}');
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Android 13+ runtime permission. No-op on older Android.
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS: show the banner even when the app is open.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 1. App is open.
    FirebaseMessaging.onMessage.listen((message) {
      onMessage?.call(message);
      _showLocal(message);
    });

    // 2. App was in the background, user tapped the system banner.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Opened from background tap: ${message.data}');
      onMessage?.call(message);
    });

    // 3. App was killed, user tapped the banner, app cold-started.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('Opened from terminated tap: ${initial.data}');
      onMessage?.call(initial);
    }

    _messaging.onTokenRefresh.listen((token) {
      debugPrint('Token refreshed: $token');
    });
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    await _local.show(
      id: notification.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }
}