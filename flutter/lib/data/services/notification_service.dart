import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

/// プッシュ通知サービス
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// 初期化
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('NotificationService: Web platform - skipping initialization');
      return;
    }

    try {
      // 通知許可をリクエスト
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('NotificationService: Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // FCMトークンを取得
        await _getFcmToken();

        // トークンリフレッシュを監視
        _messaging.onTokenRefresh.listen(_onTokenRefresh);

        // フォアグラウンドメッセージハンドラを設定
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);

        // バックグラウンド/終了状態からの起動を処理
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

        // アプリが終了状態から起動した場合の初期メッセージをチェック
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleInitialMessage(initialMessage);
        }

        debugPrint('NotificationService: Initialization complete');
      } else {
        debugPrint('NotificationService: Permission denied');
      }
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
    }
  }

  /// FCMトークンを取得
  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('NotificationService: FCM Token: $_fcmToken');
    } catch (e) {
      debugPrint('NotificationService: Failed to get FCM token: $e');
    }
  }

  /// トークンリフレッシュ時のコールバック
  void _onTokenRefresh(String token) {
    debugPrint('NotificationService: Token refreshed: $token');
    _fcmToken = token;
    // TODO: サーバーにトークンを送信
  }

  /// フォアグラウンドメッセージハンドラ
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('NotificationService: Foreground message received');
    debugPrint('  Title: ${message.notification?.title}');
    debugPrint('  Body: ${message.notification?.body}');
    debugPrint('  Data: ${message.data}');

    // TODO: ローカル通知を表示するか、アプリ内で通知を表示
    _notificationCallback?.call(message);
  }

  /// バックグラウンド/終了状態から通知タップで起動した時のハンドラ
  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('NotificationService: App opened from notification');
    debugPrint('  Data: ${message.data}');

    _handleNotificationTap(message);
  }

  /// 終了状態から起動した場合の初期メッセージ処理
  void _handleInitialMessage(RemoteMessage message) {
    debugPrint('NotificationService: Initial message');
    debugPrint('  Data: ${message.data}');

    _handleNotificationTap(message);
  }

  /// 通知タップ時の処理
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    // 通知タイプに応じて画面遷移
    switch (type) {
      case 'chat':
        _navigationCallback?.call('/chat');
        break;
      case 'diary':
        _navigationCallback?.call('/diary');
        break;
      case 'todo':
        _navigationCallback?.call('/todo');
        break;
      case 'schedule':
        _navigationCallback?.call('/calendar');
        break;
      default:
        _navigationCallback?.call('/');
    }
  }

  // コールバック
  Function(RemoteMessage)? _notificationCallback;
  Function(String)? _navigationCallback;

  /// フォアグラウンド通知コールバックを設定
  void setNotificationCallback(Function(RemoteMessage) callback) {
    _notificationCallback = callback;
  }

  /// ナビゲーションコールバックを設定
  void setNavigationCallback(Function(String) callback) {
    _navigationCallback = callback;
  }

  /// 通知許可状態を確認
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// 通知許可をリクエスト
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// トピックを購読
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('NotificationService: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('NotificationService: Failed to subscribe to topic: $e');
    }
  }

  /// トピック購読を解除
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('NotificationService: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('NotificationService: Failed to unsubscribe from topic: $e');
    }
  }

  /// バッジをクリア
  Future<void> clearBadge() async {
    if (kIsWeb) {
      return;
    }

    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        await FlutterAppBadger.removeBadge();
        debugPrint('NotificationService: Badge cleared');
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to clear badge: $e');
    }
  }
}

/// バックグラウンドメッセージハンドラ（トップレベル関数として定義）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService: Background message received');
  debugPrint('  Title: ${message.notification?.title}');
  debugPrint('  Body: ${message.notification?.body}');
  debugPrint('  Data: ${message.data}');

  // バックグラウンド処理（必要に応じて）
}
