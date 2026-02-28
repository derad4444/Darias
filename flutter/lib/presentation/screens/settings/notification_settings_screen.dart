import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';

/// 通知設定画面
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final permissionAsync = ref.watch(notificationPermissionProvider);
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('通知設定', style: TextStyle(color: AppColors.textPrimary)),
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
                data: (status) => _PermissionStatusCard(
                  status: status,
                  accentColor: accentColor,
                ),
                loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
                error: (e, st) => _PermissionStatusCard(
                  status: AuthorizationStatus.notDetermined,
                  accentColor: accentColor,
                  error: e.toString(),
                ),
              ),

              const SizedBox(height: 16),

              // 通知カテゴリー設定
              _buildSectionTitle('通知カテゴリー'),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _NotificationToggle(
                      icon: Icons.chat,
                      title: 'チャット通知',
                      subtitle: 'キャラクターからのメッセージを受け取る',
                      value: settings.chatNotifications,
                      accentColor: accentColor,
                      onChanged: (value) {
                        ref.read(notificationSettingsProvider.notifier).setChatNotifications(value);
                      },
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _NotificationToggle(
                      icon: Icons.book,
                      title: '日記通知',
                      subtitle: '新しい日記が生成されたときに通知',
                      value: settings.diaryNotifications,
                      accentColor: accentColor,
                      onChanged: (value) {
                        ref.read(notificationSettingsProvider.notifier).setDiaryNotifications(value);
                      },
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _NotificationToggle(
                      icon: Icons.alarm,
                      title: 'リマインダー',
                      subtitle: 'TODOや予定のリマインダー',
                      value: settings.reminderNotifications,
                      accentColor: accentColor,
                      onChanged: (value) {
                        ref.read(notificationSettingsProvider.notifier).setReminderNotifications(value);
                      },
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _NotificationToggle(
                      icon: Icons.campaign,
                      title: 'お知らせ・キャンペーン',
                      subtitle: 'アプリからのお知らせやキャンペーン情報',
                      value: settings.promotionNotifications,
                      accentColor: accentColor,
                      onChanged: (value) {
                        ref.read(notificationSettingsProvider.notifier).setPromotionNotifications(value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 説明テキスト
              Text(
                '通知を完全にオフにするには、デバイスの設定アプリからDARIASの通知設定を変更してください。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _PermissionStatusCard extends ConsumerWidget {
  final AuthorizationStatus status;
  final Color accentColor;
  final String? error;

  const _PermissionStatusCard({
    required this.status,
    required this.accentColor,
    this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthorized = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAuthorized
                          ? 'アプリからの通知を受け取れます'
                          : '通知を有効にすると、大切なお知らせを受け取れます',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isAuthorized) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final service = ref.read(notificationServiceProvider);
                final granted = await service.requestPermission();
                if (granted) {
                  ref.invalidate(notificationPermissionProvider);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '通知を有効にする',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
