/// Stub implementation for non-web platforms
Future<bool> requestWebNotificationPermission() async => false;
bool get isWebNotificationGranted => false;
void showWebNotification(String title, {String? body}) {}
