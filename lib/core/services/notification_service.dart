import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../firebase_options.dart';
import '../router/app_router.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _currentToken;
  bool _initialized = false;

  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'lovelink_messages',
    'Messages',
    description: 'New messages from your partner',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('Notification permission granted');
    }

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _refreshAndStoreToken();

    _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      _storeToken(token);
    });

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _refreshAndStoreToken();
      }
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapData);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }
  }

  Future<void> _refreshAndStoreToken() async {
    _currentToken = await _messaging.getToken();
    await _storeToken(_currentToken);
  }

  Future<void> _storeToken(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .catchError((_) {});
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification?.title ?? data['title'] ?? 'New message',
      body: notification?.body ?? data['body'] ?? '',
      payload: data['conversationId'] ?? '',
    );
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: false,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final conversationId = response.payload;
    if (conversationId != null && conversationId.isNotEmpty) {
      _navigateToChat(conversationId);
    }
  }

  void _onNotificationTapData(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    if (conversationId != null && conversationId.isNotEmpty) {
      _navigateToChat(conversationId);
    }
  }

  void _navigateToChat(String conversationId) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).go('/chats/$conversationId');
    }
  }
}
