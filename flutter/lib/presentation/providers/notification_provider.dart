import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/notification_service.dart';
import 'character_provider.dart';

/// NotificationServiceのプロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 通知許可状態のプロバイダー
final notificationPermissionProvider =
    FutureProvider<AuthorizationStatus>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getPermissionStatus();
});

// ────────────────────────────────────────
// 通知設定モデル
// ────────────────────────────────────────

class NotificationSettings {
  final bool scheduleNotifications;
  final bool diaryNotifications;

  const NotificationSettings({
    this.scheduleNotifications = true,
    this.diaryNotifications = true,
  });

  NotificationSettings copyWith({
    bool? scheduleNotifications,
    bool? diaryNotifications,
  }) {
    return NotificationSettings(
      scheduleNotifications:
          scheduleNotifications ?? this.scheduleNotifications,
      diaryNotifications: diaryNotifications ?? this.diaryNotifications,
    );
  }
}

// ────────────────────────────────────────
// 通知設定プロバイダー
// ────────────────────────────────────────

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        (ref) {
  return NotificationSettingsNotifier(ref);
});

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings> {
  final Ref _ref;

  static const _keySchedule = 'notification_schedule';
  static const _keyDiary = 'notification_diary';

  NotificationSettingsNotifier(this._ref)
      : super(const NotificationSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      scheduleNotifications: prefs.getBool(_keySchedule) ?? true,
      diaryNotifications: prefs.getBool(_keyDiary) ?? true,
    );
  }

  Future<void> setScheduleNotifications(bool value) async {
    state = state.copyWith(scheduleNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySchedule, value);
    // 予定通知はスケジュール保存時に個別に設定されるため、ここではトピック購読のみ
    final service = _ref.read(notificationServiceProvider);
    if (value) {
      service.subscribeToTopic('schedule');
    } else {
      service.unsubscribeFromTopic('schedule');
    }
  }

  Future<void> setDiaryNotifications(bool value) async {
    state = state.copyWith(diaryNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDiary, value);

    final service = _ref.read(notificationServiceProvider);
    if (value) {
      // キャラクター名を取得して日記通知をスケジュール
      final character = _ref.read(currentCharacterProvider).valueOrNull;
      final name = character?.name ?? 'キャラクター';
      await service.scheduleDailyDiaryNotification(name);
    } else {
      await service.cancelDailyDiaryNotification();
    }
  }
}
