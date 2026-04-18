import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/schedule_model.dart';
import '../../firebase_options.dart';
import 'notification_web_helper_stub.dart'
    if (dart.library.html) 'notification_web_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _localPlugin;

  static const int _diaryNotificationId = 9999;
  static const String _scheduleChannelId = 'schedule_channel';
  static const String _diaryChannelId = 'diary_channel';

  final Map<String, Timer> _webTimers = {};

  // ────────────────────────────────────────
  // 初期化
  // ────────────────────────────────────────

  Future<void> initialize() async {
    if (kIsWeb) {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      return;
    }

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _localPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localPlugin!.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android 通知チャンネル
    await _localPlugin!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _scheduleChannelId,
          'スケジュール通知',
          description: '予定のリマインダー',
          importance: Importance.high,
        ));
    await _localPlugin!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _diaryChannelId,
          '日記通知',
          description: 'キャラクターの日記通知',
          importance: Importance.defaultImportance,
        ));

    // 古いローカル日記通知を削除（FCMへ移行）
    await _localPlugin!.cancel(_diaryNotificationId);

    // iOS: フォアグラウンド時もバナー表示
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  // ────────────────────────────────────────
  // FCM トークン管理
  // ────────────────────────────────────────

  /// ログイン後にFCMトークンをFirestoreへ保存
  Future<void> saveFcmToken(String userId) async {
    if (kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});

      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': newToken}).catchError((_) {});
      });
    } catch (e) {
      debugPrint('NotificationService: saveFcmToken failed: $e');
    }
  }

  /// 日記通知の有効/無効をFirestoreへ保存（Cloud Functionsが参照）
  Future<void> setDiaryNotificationsEnabled(String userId, bool enabled) async {
    if (kIsWeb) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'diaryNotificationsEnabled': enabled});
    } catch (e) {
      debugPrint('NotificationService: setDiaryNotificationsEnabled failed: $e');
    }
  }

  // ────────────────────────────────────────
  // 通知許可
  // ────────────────────────────────────────

  Future<AuthorizationStatus> getPermissionStatus() async {
    if (kIsWeb) {
      return isWebNotificationGranted
          ? AuthorizationStatus.authorized
          : AuthorizationStatus.notDetermined;
    }
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return await requestWebNotificationPermission();
    }

    final iosPlugin = _localPlugin
        ?.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin = _localPlugin
        ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    return iosGranted ?? true;
  }

  // ────────────────────────────────────────
  // 予定通知（ローカル）
  // ────────────────────────────────────────

  Future<void> scheduleForSchedule(ScheduleModel schedule) async {
    if (schedule.remindValue <= 0 || schedule.remindUnit.isEmpty) return;

    final notifyAt = _calcNotifyTime(schedule);
    if (notifyAt == null || notifyAt.isBefore(DateTime.now())) return;

    final title = '予定: ${schedule.title}';
    final body = _remindLabel(schedule.remindValue, schedule.remindUnit);

    if (kIsWeb) {
      _cancelWebTimer(schedule.id);
      final delay = notifyAt.difference(DateTime.now());
      _webTimers[schedule.id] = Timer(delay, () {
        showWebNotification(title, body: body);
      });
      return;
    }

    await _localPlugin?.cancel(schedule.id.hashCode);
    await _localPlugin?.zonedSchedule(
      schedule.id.hashCode,
      title,
      body,
      tz.TZDateTime.from(notifyAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _scheduleChannelId,
          'スケジュール通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelScheduleNotification(String scheduleId) async {
    if (kIsWeb) {
      _cancelWebTimer(scheduleId);
      return;
    }
    await _localPlugin?.cancel(scheduleId.hashCode);
  }

  // ────────────────────────────────────────
  // 日記通知（FCMベース。ローカル通知はキャンセルのみ残す）
  // ────────────────────────────────────────

  /// 古いローカル日記通知をキャンセル（FCMへ移行済みのため登録は不要）
  Future<void> cancelDailyDiaryNotification() async {
    await _localPlugin?.cancel(_diaryNotificationId);
  }

  // ────────────────────────────────────────
  // FCM トピック購読
  // ────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('NotificationService: subscribeToTopic failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('NotificationService: unsubscribeFromTopic failed: $e');
    }
  }

  // ────────────────────────────────────────
  // プライベートヘルパー
  // ────────────────────────────────────────

  DateTime? _calcNotifyTime(ScheduleModel schedule) {
    switch (schedule.remindUnit) {
      case 'minutes':
        return schedule.startDate
            .subtract(Duration(minutes: schedule.remindValue));
      case 'hours':
        return schedule.startDate
            .subtract(Duration(hours: schedule.remindValue));
      case 'days':
        return schedule.startDate
            .subtract(Duration(days: schedule.remindValue));
      default:
        return null;
    }
  }

  String _remindLabel(int value, String unit) {
    switch (unit) {
      case 'minutes':
        return '$value分前';
      case 'hours':
        return '$value時間前';
      case 'days':
        return '$value日前';
      default:
        return '';
    }
  }

  void _cancelWebTimer(String scheduleId) {
    _webTimers[scheduleId]?.cancel();
    _webTimers.remove(scheduleId);
  }

  /// フォアグラウンド受信: Androidはローカル通知で表示（iOSはOS側で自動表示）
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || _localPlugin == null) return;

    // iOSはsetForegroundNotificationPresentationOptionsで表示済み
    if (defaultTargetPlatform == TargetPlatform.iOS) return;

    await _localPlugin!.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _diaryChannelId,
          '日記通知',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  Future<void> clearBadge() async {}
}

/// バックグラウンドメッセージハンドラ（トップレベル・別isolate）
/// notification フィールドがあるFCMメッセージはOSが自動表示するため、
/// Firebaseの初期化のみ行う
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
