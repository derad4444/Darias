import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('プライバシー設定'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // 説明
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(Icons.privacy_tip, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'プライバシーに関する設定を管理できます。これらの設定はいつでも変更できます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // データ収集
          _PrivacySection(
            title: 'データ収集',
            icon: Icons.analytics,
            children: [
              _PrivacySwitch(
                title: '使用状況の分析',
                subtitle: 'アプリの利用状況を匿名で収集し、サービス改善に役立てます',
                value: settings.analyticsEnabled,
                onChanged: notifier.setAnalyticsEnabled,
              ),
              _PrivacySwitch(
                title: 'クラッシュレポート',
                subtitle: 'アプリがクラッシュした際に自動でレポートを送信します',
                value: settings.crashReportingEnabled,
                onChanged: notifier.setCrashReportingEnabled,
              ),
              _PrivacySwitch(
                title: 'データ収集',
                subtitle: '機能改善のためのデータ収集を許可します',
                value: settings.dataCollectionEnabled,
                onChanged: notifier.setDataCollectionEnabled,
              ),
            ],
          ),

          const Divider(),

          // 広告
          _PrivacySection(
            title: '広告',
            icon: Icons.ad_units,
            children: [
              _PrivacySwitch(
                title: 'パーソナライズ広告',
                subtitle: '興味関心に基づいた広告を表示します（オフにすると一般的な広告が表示されます）',
                value: settings.personalizedAdsEnabled,
                onChanged: notifier.setPersonalizedAdsEnabled,
              ),
            ],
          ),

          const Divider(),

          // データ管理
          _PrivacySection(
            title: 'データ管理',
            icon: Icons.folder,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('データをエクスポート'),
                subtitle: const Text('あなたのデータをダウンロード'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/data-export'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('キャッシュを削除'),
                subtitle: const Text('一時ファイルを削除します'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _clearCache(context),
              ),
            ],
          ),

          const Divider(),

          // 法的情報
          _PrivacySection(
            title: '法的情報',
            icon: Icons.gavel,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('プライバシーポリシー'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // TODO: プライバシーポリシーのURLを開く
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('プライバシーポリシーページは準備中です')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.article),
                title: const Text('利用規約'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // TODO: 利用規約のURLを開く
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
      // TODO: 実際のキャッシュ削除処理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('キャッシュを削除しました')),
      );
    }
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _PrivacySection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _PrivacySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  const _PrivacySwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
