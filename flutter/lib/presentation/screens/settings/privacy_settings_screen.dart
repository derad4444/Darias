import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';

/// プライバシー設定のプロバイダー
final privacySettingsProvider = StateNotifierProvider<PrivacySettingsNotifier, PrivacySettings>((ref) {
  return PrivacySettingsNotifier();
});

class PrivacySettings {
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool personalizedAdsEnabled;
  final bool dataCollectionEnabled;

  const PrivacySettings({
    this.analyticsEnabled = true,
    this.crashReportingEnabled = true,
    this.personalizedAdsEnabled = true,
    this.dataCollectionEnabled = true,
  });

  PrivacySettings copyWith({
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? personalizedAdsEnabled,
    bool? dataCollectionEnabled,
  }) {
    return PrivacySettings(
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled: crashReportingEnabled ?? this.crashReportingEnabled,
      personalizedAdsEnabled: personalizedAdsEnabled ?? this.personalizedAdsEnabled,
      dataCollectionEnabled: dataCollectionEnabled ?? this.dataCollectionEnabled,
    );
  }
}

class PrivacySettingsNotifier extends StateNotifier<PrivacySettings> {
  PrivacySettingsNotifier() : super(const PrivacySettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = PrivacySettings(
      analyticsEnabled: prefs.getBool('privacy_analytics') ?? true,
      crashReportingEnabled: prefs.getBool('privacy_crash') ?? true,
      personalizedAdsEnabled: prefs.getBool('privacy_ads') ?? true,
      dataCollectionEnabled: prefs.getBool('privacy_data') ?? true,
    );
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_analytics', value);
    state = state.copyWith(analyticsEnabled: value);
  }

  Future<void> setCrashReportingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_crash', value);
    state = state.copyWith(crashReportingEnabled: value);
  }

  Future<void> setPersonalizedAdsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_ads', value);
    state = state.copyWith(personalizedAdsEnabled: value);
  }

  Future<void> setDataCollectionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_data', value);
    state = state.copyWith(dataCollectionEnabled: value);
  }
}

/// プライバシー設定画面
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);
    final notifier = ref.read(privacySettingsProvider.notifier);
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'プライバシー設定',
          style: TextStyle(color: AppColors.textPrimary),
        ),
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
              // 説明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip, color: accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'プライバシーに関する設定を管理できます。これらの設定はいつでも変更できます。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // データ収集
              _PrivacySection(
                title: 'データ収集',
                icon: Icons.analytics,
                accentColor: accentColor,
                children: [
                  _PrivacySwitch(
                    title: '使用状況の分析',
                    subtitle: 'アプリの利用状況を匿名で収集し、サービス改善に役立てます',
                    value: settings.analyticsEnabled,
                    accentColor: accentColor,
                    onChanged: notifier.setAnalyticsEnabled,
                  ),
                  Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                  _PrivacySwitch(
                    title: 'クラッシュレポート',
                    subtitle: 'アプリがクラッシュした際に自動でレポートを送信します',
                    value: settings.crashReportingEnabled,
                    accentColor: accentColor,
                    onChanged: notifier.setCrashReportingEnabled,
                  ),
                  Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                  _PrivacySwitch(
                    title: 'データ収集',
                    subtitle: '機能改善のためのデータ収集を許可します',
                    value: settings.dataCollectionEnabled,
                    accentColor: accentColor,
                    onChanged: notifier.setDataCollectionEnabled,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 広告
              _PrivacySection(
                title: '広告',
                icon: Icons.ad_units,
                accentColor: accentColor,
                children: [
                  _PrivacySwitch(
                    title: 'パーソナライズ広告',
                    subtitle: '興味関心に基づいた広告を表示します（オフにすると一般的な広告が表示されます）',
                    value: settings.personalizedAdsEnabled,
                    accentColor: accentColor,
                    onChanged: notifier.setPersonalizedAdsEnabled,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // データ管理
              _PrivacySection(
                title: 'データ管理',
                icon: Icons.folder,
                accentColor: accentColor,
                children: [
                  _PrivacyLink(
                    icon: Icons.download,
                    title: 'データをエクスポート',
                    subtitle: 'あなたのデータをダウンロード',
                    accentColor: accentColor,
                    onTap: () => context.push('/data-export'),
                  ),
                  Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                  _PrivacyLink(
                    icon: Icons.delete_sweep,
                    title: 'キャッシュを削除',
                    subtitle: '一時ファイルを削除します',
                    accentColor: accentColor,
                    onTap: () => _clearCache(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 法的情報
              _PrivacySection(
                title: '法的情報',
                icon: Icons.gavel,
                accentColor: accentColor,
                children: [
                  _PrivacyLink(
                    icon: Icons.description,
                    title: 'プライバシーポリシー',
                    accentColor: accentColor,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('プライバシーポリシーページは準備中です')),
                      );
                    },
                  ),
                  Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                  _PrivacyLink(
                    icon: Icons.article,
                    title: '利用規約',
                    accentColor: accentColor,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('利用規約ページは準備中です')),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('キャッシュを削除'),
        content: const Text('一時ファイルを削除します。この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('キャッシュを削除しました')),
      );
    }
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _PrivacySection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _PrivacySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Color accentColor;
  final Future<void> Function(bool) onChanged;

  const _PrivacySwitch({
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _PrivacyLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _PrivacyLink({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
