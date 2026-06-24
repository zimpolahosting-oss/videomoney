import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../firebase_options.dart';
import 'firestore_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'videomoney_general';
  static const String _channelName = 'VideoMoney Notifications';
  static const String _channelDescription =
      'General notifications and admin updates';
  static const int _dailyReminderId = 7001;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _activeUserId;
  String? _activeToken;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timezoneName);
      tz.setLocalLocation(location);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@android:drawable/ic_dialog_info');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(_showRemoteMessageAsLocalNotification);

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_handleAuthStateChange);
    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _showRemoteMessageAsLocalNotification(initialMessage);
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _handleAuthStateChange(currentUser);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }

  Future<void> _handleAuthStateChange(User? user) async {
    if (_activeUserId != null &&
        _activeToken != null &&
        (user == null || user.uid != _activeUserId)) {
      await _firestoreService.removeUserFcmToken(
        uid: _activeUserId!,
        token: _activeToken!,
      );
    }

    _activeUserId = user?.uid;
    if (user == null) {
      _activeToken = null;
      return;
    }

    await _requestPermissions();
    await syncUserState(user.uid);
  }

  Future<void> _handleTokenRefresh(String token) async {
    _activeToken = token;
    final uid = _activeUserId;
    if (uid == null) return;
    await _firestoreService.saveUserFcmToken(uid: uid, token: token);
  }

  Future<void> syncUserState(String uid) async {
    await _requestPermissions();
    final token = await _messaging.getToken();
    if (token != null) {
      _activeToken = token;
      await _firestoreService.saveUserFcmToken(uid: uid, token: token);
    }

    final settings = await _firestoreService.getUserSettings(uid);
    if (settings['notificationsEnabled'] ?? true) {
      if (settings['dailyReminderEnabled'] ?? true) {
        await scheduleDailyReminder();
      } else {
        await cancelDailyReminder();
      }
    } else {
      await cancelDailyReminder();
    }
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> updateNotificationPreferences({
    required String uid,
    required bool notificationsEnabled,
    required bool dailyReminderEnabled,
  }) async {
    await _firestoreService.updateUserSettings(
      uid: uid,
      notificationsEnabled: notificationsEnabled,
      dailyReminderEnabled: dailyReminderEnabled,
    );

    if (!notificationsEnabled || !dailyReminderEnabled) {
      await cancelDailyReminder();
      return;
    }

    await _requestPermissions();
    await scheduleDailyReminder();
  }

  Future<void> scheduleDailyReminder({
    int hour = 19,
    int minute = 0,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      _dailyReminderId,
      'VideoMoney',
      'Vergeet je daily bonus niet.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _localNotifications.cancel(_dailyReminderId);
  }

  Future<void> _showRemoteMessageAsLocalNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['message'] as String?;
    if ((title ?? '').trim().isEmpty && (body ?? '').trim().isEmpty) return;

    await _localNotifications.show(
      message.hashCode,
      title ?? 'VideoMoney',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
