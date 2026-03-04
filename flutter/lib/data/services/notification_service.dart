import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/schedule_model.dart';
import 'notification_web_helper_stub.dart'
    if (dart.library.html) 'notification_web_helper.dart';

/// プッシュ通知・ローカル通知サービス
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _localPlugin;

  static const int _diaryNotificationId = 9999;
  static const String _scheduleChannelId = 'schedule_channel';
  static const String _diaryChannelId = 'diary_channel';

  // Web: タイマーベースのスケジューリング（アプリ起動中のみ有効）
  final Map<String, Timer> _webTimers = {};
  Timer? _webDiaryTimer;

  // ────────────────────────────────────────
  // 初期化
  // ────────────────────────────────────────

  Future<void> initialize() async {
    if (kIsWeb) {
      // Web: FCMフォアグラウンドメッセージのみ設定
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

    // Android 通知チャンネル作成
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

    // FCM フォアグラウンドメッセージ
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  // ────────────────────────────────────────
  // 通知許可
  // ────────────────────────────────────────

  /// 現在の許可状態を取得
  Future<AuthorizationStatus> getPermissionStatus() async {
    if (kIsWeb) {
      return isWebNotificationGranted
          ? AuthorizationStatus.authorized
          : AuthorizationStatus.notDetermined;
    }
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// 許可をリクエスト
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
  // 予定通知
  // ────────────────────────────────────────

  /// 予定のリマインダーをスケジュール
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

  /// 予定の通知をキャンセル
  Future<void> cancelScheduleNotification(String scheduleId) async {
    if (kIsWeb) {
      _cancelWebTimer(scheduleId);
      return;
    }
    await _localPlugin?.cancel(scheduleId.hashCode);
  }

  // ────────────────────────────────────────
  // 日記通知（毎日23:55）
  // ────────────────────────────────────────

  /// 日記通知を毎日23:55にスケジュール
  Future<void> scheduleDailyDiaryNotification(String characterName) async {
    if (kIsWeb) {
      _scheduleWebDiary(characterName);
      return;
    }

    await _localPlugin?.cancel(_diaryNotificationId);

    final now = DateTime.now();
    var notifyAt = DateTime(now.year, now.month, now.day, 23, 55);
    if (notifyAt.isBefore(now)) {
      notifyAt = notifyAt.add(const Duration(days: 1));
    }

    await _localPlugin?.zonedSchedule(
      _diaryNotificationId,
      '${characterName}の日記',
      'キャラクターが今日の日記を書きました',
      tz.TZDateTime.from(notifyAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _diaryChannelId,
          '日記通知',
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 毎日繰り返し
    );
  }

  /// 日記通知をキャンセル
  Future<void> cancelDailyDiaryNotification() async {
    if (kIsWeb) {
      _webDiaryTimer?.cancel();
      _webDiaryTimer = null;
      return;
    }
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

  void _scheduleWebDiary(String characterName) {
    _webDiaryTimer?.cancel();
    final now = DateTime.now();
    var notifyAt = DateTime(now.year, now.month, now.day, 23, 55);
    if (notifyAt.isBefore(now)) {
      notifyAt = notifyAt.add(const Duration(days: 1));
    }
    _webDiaryTimer = Timer(notifyAt.difference(now), () {
      showWebNotification('${characterName}の日記',
          body: 'キャラクターが今日の日記を書きました');
      // 翌日のためにもう一度スケジュール
      _scheduleWebDiary(characterName);
    });
  }

  /// バッジをクリア
  Future<void> clearBadge() async {}

  void _onForegroundMessage(dynamic message) {
    debugPrint('NotificationService: foreground message received');
  }
}

/// バックグラウンドメッセージハンドラ（トップレベル）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {
  debugPrint('NotificationService: background message received');
}
