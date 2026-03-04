import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';

/// 通知設定画面（iOS版に準拠）
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final permissionAsync = ref.watch(notificationPermissionProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('通知設定', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // 通知許可状態
              permissionAsync.when(
                data: (status) => _PermissionCard(
                  status: status,
                  accentColor: accentColor,
                  textColor: textColor,
                ),
                loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
                error: (e, st) => _PermissionCard(
                  status: AuthorizationStatus.notDetermined,
                  accentColor: accentColor,
                  textColor: textColor,
                ),
              ),

              const SizedBox(height: 16),

              // 予定の通知
              _NotificationToggle(
                icon: Icons.calendar_month_outlined,
                title: '予定の通知',
                subtitle: '予定の開始時刻前に通知',
                value: settings.scheduleNotifications,
                accentColor: accentColor,
                textColor: textColor,
                onChanged: (value) {
                  ref.read(notificationSettingsProvider.notifier).setScheduleNotifications(value);
                },
              ),

              const SizedBox(height: 12),

              // 日記の通知
              _NotificationToggle(
                icon: Icons.book_outlined,
                title: '日記の通知',
                subtitle: '毎日23:55に日記作成を通知',
                value: settings.diaryNotifications,
                accentColor: accentColor,
                textColor: textColor,
                onChanged: (value) {
                  ref.read(notificationSettingsProvider.notifier).setDiaryNotifications(value);
                },
              ),

              const SizedBox(height: 24),

              // 通知についての説明
              _InfoCard(textColor: textColor),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通知許可状態カード
class _PermissionCard extends ConsumerWidget {
  final AuthorizationStatus status;
  final Color accentColor;
  final Color textColor;

  const _PermissionCard({
    required this.status,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthorized = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAuthorized
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAuthorized
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: isAuthorized ? Colors.green : Colors.orange,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuthorized ? '通知が許可されています' : '通知が許可されていません',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAuthorized
                      ? '通知を受け取ることができます'
                      : 'デバイスの設定から通知を許可してください',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (!isAuthorized)
            GestureDetector(
              onTap: () async {
                final service = ref.read(notificationServiceProvider);
                await service.requestPermission();
                ref.invalidate(notificationPermissionProvider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '設定',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 通知トグル行
class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color accentColor;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accentColor,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 通知についての説明カード
class _InfoCard extends StatelessWidget {
  final Color textColor;

  const _InfoCard({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: textColor.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '通知について',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bullet('予定の通知：各予定に設定した時刻に通知されます', textColor),
          const SizedBox(height: 6),
          _bullet('日記の通知：キャラクターが日記を書いたことを毎日お知らせします', textColor),
          const SizedBox(height: 6),
          _bullet('通知をオフにしても、アプリ内で予定や日記を確認できます', textColor),
        ],
      ),
    );
  }

  Widget _bullet(String text, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
