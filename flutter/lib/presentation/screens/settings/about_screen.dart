import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';

/// アバウト画面
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'アプリについて',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            // アプリロゴとバージョン
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  // アプリアイコン
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // アプリ名
                  Text(
                    'DARIAS',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // サブタイトル
                  Text(
                    'AI Partner App',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // バージョン
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version 1.0.0 (Build 1)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            // 説明
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DARIASについて',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'DARIASは、AIキャラクターとの会話を通じて日々の生活をサポートする'
                      'パーソナルアシスタントアプリです。\n\n'
                      'チャット、日記、TODO管理、スケジュール管理、メモ、BIG5性格診断など、'
                      '様々な機能を搭載しています。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // 機能一覧
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主な機能',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.chat_bubble,
                      title: 'AIチャット',
                      description: 'AIキャラクターとの自然な会話',
                      accentColor: accentColor,
                    ),
                    _FeatureRow(
                      icon: Icons.book,
                      title: '自動日記生成',
                      description: '会話から自動で日記を作成',
                      accentColor: accentColor,
                    ),
                    _FeatureRow(
                      icon: Icons.psychology,
                      title: 'BIG5性格診断',
                      description: '100問の質問で性格を分析',
                      accentColor: accentColor,
                    ),
                    _FeatureRow(
                      icon: Icons.groups,
                      title: '6人会議',
                      description: 'AIキャラクターたちとの会議シミュレーション',
                      accentColor: accentColor,
                    ),
                    _FeatureRow(
                      icon: Icons.calendar_today,
                      title: 'スケジュール管理',
                      description: '予定の登録と管理',
                      accentColor: accentColor,
                    ),
                    _FeatureRow(
                      icon: Icons.check_circle,
                      title: 'TODO管理',
                      description: 'タスクの作成と進捗管理',
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // リンク
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _LinkTile(
                      icon: Icons.description,
                      title: '利用規約',
                      accentColor: accentColor,
                      onTap: () => _openUrl('https://example.com/terms'),
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _LinkTile(
                      icon: Icons.privacy_tip,
                      title: 'プライバシーポリシー',
                      accentColor: accentColor,
                      onTap: () => _openUrl('https://example.com/privacy'),
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _LinkTile(
                      icon: Icons.code,
                      title: 'オープンソースライセンス',
                      accentColor: accentColor,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'DARIAS',
                        applicationVersion: '1.0.0',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            Icons.smart_toy,
                            size: 48,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 開発者情報
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '開発',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const _InfoRow(label: '開発者', value: 'DARIAS Team'),
                    const _InfoRow(label: 'お問い合わせ', value: 'darias.app4@gmail.com'),
                    const SizedBox(height: 12),
                    Text(
                      '2024 DARIAS. All rights reserved.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
