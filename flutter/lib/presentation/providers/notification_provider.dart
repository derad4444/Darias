import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_service.dart';

/// NotificationServiceのプロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 通知許可状態のプロバイダー
final notificationPermissionProvider = FutureProvider<AuthorizationStatus>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getPermissionStatus();
});

/// FCMトークンのプロバイダー
final fcmTokenProvider = Provider<String?>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.fcmToken;
});

/// 通知設定状態
class NotificationSettings {
  final bool chatNotifications;
  final bool diaryNotifications;
  final bool reminderNotifications;
  final bool promotionNotifications;

  const NotificationSettings({
    this.chatNotifications = true,
    this.diaryNotifications = true,
    this.reminderNotifications = true,
    this.promotionNotifications = false,
  });

  NotificationSettings copyWith({
    bool? chatNotifications,
    bool? diaryNotifications,
    bool? reminderNotifications,
    bool? promotionNotifications,
  }) {
    return NotificationSettings(
      chatNotifications: chatNotifications ?? this.chatNotifications,
      diaryNotifications: diaryNotifications ?? this.diaryNotifications,
      reminderNotifications: reminderNotifications ?? this.reminderNotifications,
      promotionNotifications: promotionNotifications ?? this.promotionNotifications,
    );
  }
}

/// 通知設定のプロバイダー
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier(ref);
});

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final Ref _ref;

  NotificationSettingsNotifier(this._ref) : super(const NotificationSettings());

  void setChatNotifications(bool value) {
    state = state.copyWith(chatNotifications: value);
    _updateTopicSubscription('chat', value);
  }

  void setDiaryNotifications(bool value) {
    state = state.copyWith(diaryNotifications: value);
    _updateTopicSubscription('diary', value);
  }

  void setReminderNotifications(bool value) {
    state = state.copyWith(reminderNotifications: value);
    _updateTopicSubscription('reminder', value);
  }

  void setPromotionNotifications(bool value) {
    state = state.copyWith(promotionNotifications: value);
    _updateTopicSubscription('promotion', value);
  }

  void _updateTopicSubscription(String topic, bool subscribe) {
    final service = _ref.read(notificationServiceProvider);
    if (subscribe) {
      service.subscribeToTopic(topic);
    } else {
      service.unsubscribeFromTopic(topic);
    }
  }
}
