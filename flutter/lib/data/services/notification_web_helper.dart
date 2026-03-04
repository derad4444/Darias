// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// ブラウザの通知許可をリクエスト
Future<bool> requestWebNotificationPermission() async {
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

/// ブラウザの通知許可状態
bool get isWebNotificationGranted =>
    html.Notification.permission == 'granted';

/// ブラウザ通知を表示
void showWebNotification(String title, {String? body}) {
  if (html.Notification.permission == 'granted') {
    html.Notification(
      title,
      body: body,
    );
  }
}
