import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
  static const String _diaryChannelId = 'diary_channel';

  /// 予定通知を一度消したかどうかの記録キー（端末ごと・1回限りの後始末用）
  static const String _schedulePurgedKey = 'schedule_notifications_purged';

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
          _diaryChannelId,
          '日記通知',
          description: 'キャラクターの日記通知',
          importance: Importance.defaultImportance,
        ));

    // 古いローカル日記通知を削除（FCMへ移行）
    await _localPlugin!.cancel(_diaryNotificationId);

    await _purgeScheduleNotificationsOnce();

    // FCM通知許可リクエスト（未決定の場合のみOSダイアログが表示される）
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS: フォアグラウンド時もバナー表示
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  /// OSに予約済みの予定通知を一度だけ全消去する（端末ごとの後始末）。
  ///
  /// 予定通知はOS側が予約を保持しているため、アプリから登録処理を外すだけでは
  /// 過去に登録した予定の通知が届き続ける。そのため明示的に消す必要がある。
  ///
  /// 毎起動ではなく1回だけにしているのは、cancelAll() が予約済み通知だけでなく
  /// 通知トレイに表示中の通知も消すため。日記通知（FCM）が未読のままトレイにある
  /// 状態でアプリを開くと、それも消えてしまうのを避ける。
  ///
  /// 実行タイミングは initialize() 内、つまりアップデート後の初回起動時（ログイン前）。
  Future<void> _purgeScheduleNotificationsOnce() async {
    if (_localPlugin == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_schedulePurgedKey) ?? false) return;

      await _localPlugin!.cancelAll();
      await prefs.setBool(_schedulePurgedKey, true);
      debugPrint('🔕 予約済みの予定通知を全消去しました（初回のみ）');
    } catch (e) {
      // 消去に失敗しても起動は続行する（次回起動時に再試行される）
      debugPrint('⚠️ 予定通知の消去に失敗しました: $e');
    }
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

    // FCM通知許可リクエスト（iOSではこれを呼ばないとgetToken()がnullになる）
    final fcmSettings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final iosPlugin = _localPlugin
        ?.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin = _localPlugin
        ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    return fcmSettings.authorizationStatus == AuthorizationStatus.authorized ||
        fcmSettings.authorizationStatus == AuthorizationStatus.provisional;
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
