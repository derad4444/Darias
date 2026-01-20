import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/notification_provider.dart';

/// 通知設定画面
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(notificationPermissionProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('通知設定'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // 通知許可状態
          permissionAsync.when(
            data: (status) => _PermissionStatusCard(status: status),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => _PermissionStatusCard(
              status: AuthorizationStatus.notDetermined,
              error: e.toString(),
            ),
          ),

          const Divider(),

          // 通知カテゴリー設定
          _SectionHeader(title: '通知カテゴリー'),

          _NotificationToggle(
            icon: Icons.chat,
            title: 'チャット通知',
            subtitle: 'キャラクターからのメッセージを受け取る',
            value: settings.chatNotifications,
            onChanged: (value) {
              ref.read(notificationSettingsProvider.notifier).setChatNotifications(value);
            },
          ),

          _NotificationToggle(
            icon: Icons.book,
            title: '日記通知',
            subtitle: '新しい日記が生成されたときに通知',
            value: settings.diaryNotifications,
            onChanged: (value) {
              ref.read(notificationSettingsProvider.notifier).setDiaryNotifications(value);
            },
          ),

          _NotificationToggle(
            icon: Icons.alarm,
            title: 'リマインダー',
            subtitle: 'TODOや予定のリマインダー',
            value: settings.reminderNotifications,
            onChanged: (value) {
              ref.read(notificationSettingsProvider.notifier).setReminderNotifications(value);
            },
          ),

          _NotificationToggle(
            icon: Icons.campaign,
            title: 'お知らせ・キャンペーン',
            subtitle: 'アプリからのお知らせやキャンペーン情報',
            value: settings.promotionNotifications,
            onChanged: (value) {
              ref.read(notificationSettingsProvider.notifier).setPromotionNotifications(value);
            },
          ),

          const SizedBox(height: 24),

          // 説明テキスト
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '通知を完全にオフにするには、デバイスの設定アプリからDARIASの通知設定を変更してください。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _PermissionStatusCard extends ConsumerWidget {
  final AuthorizationStatus status;
  final String? error;

  const _PermissionStatusCard({
    required this.status,
    this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final isAuthorized = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAuthorized
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAuthorized
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: isAuthorized ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuthorized ? '通知が有効です' : '通知が無効です',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAuthorized
                            ? 'アプリからの通知を受け取れます'
                            : '通知を有効にすると、大切なお知らせを受け取れます',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isAuthorized) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final service = ref.read(notificationServiceProvider);
                  final granted = await service.requestPermission();
                  if (granted) {
                    ref.invalidate(notificationPermissionProvider);
                  }
                },
                icon: const Icon(Icons.notifications),
                label: const Text('通知を有効にする'),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
