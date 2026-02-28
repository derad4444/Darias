import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';

/// ヘルプ画面
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('ヘルプ', style: TextStyle(color: AppColors.textPrimary)),
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
              // アプリについて
              _buildSectionTitle('DARIASについて'),
              const SizedBox(height: 8),
              _buildAboutCard(context, accentColor),

              const SizedBox(height: 24),

              // よくある質問
              _buildSectionTitle('よくある質問'),
              const SizedBox(height: 8),
              _FAQItem(
                question: 'キャラクターを変更するには？',
                answer: 'ホーム画面下部の「キャラクターを変更」ボタンから、お好みのキャラクターを選択できます。',
                accentColor: accentColor,
              ),
              const SizedBox(height: 8),
              _FAQItem(
                question: '日記はどうやって作成されますか？',
                answer: 'キャラクターとの会話内容から、AIが自動的にその日の日記を生成します。会話を楽しむだけで日記が残ります。',
                accentColor: accentColor,
              ),
              const SizedBox(height: 8),
              _FAQItem(
                question: 'プレミアム会員になると何ができますか？',
                answer: 'プレミアム会員になると、広告の非表示、チャット回数の無制限化、すべてのキャラクターの解放などの特典があります。',
                accentColor: accentColor,
              ),
              const SizedBox(height: 8),
              _FAQItem(
                question: 'データはどこに保存されますか？',
                answer: 'すべてのデータはクラウド上に安全に保存されます。機種変更時もアカウントでログインすればデータを引き継げます。',
                accentColor: accentColor,
              ),
              const SizedBox(height: 8),
              _FAQItem(
                question: '通知が届かない場合は？',
                answer: 'デバイスの設定アプリからDARIASの通知設定を確認してください。また、アプリ内の通知設定も有効になっているか確認してください。',
                accentColor: accentColor,
              ),

              const SizedBox(height: 24),

              // お問い合わせ
              _buildSectionTitle('お問い合わせ'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _ContactItem(
                      icon: Icons.mail,
                      title: 'メールでお問い合わせ',
                      subtitle: 'darias.app4@gmail.com',
                      accentColor: accentColor,
                      onTap: () => _openEmail(context),
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _ContactItem(
                      icon: Icons.bug_report,
                      title: '不具合を報告',
                      subtitle: 'バグや問題をご報告ください',
                      accentColor: accentColor,
                      onTap: () => _openBugReport(context),
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _ContactItem(
                      icon: Icons.lightbulb_outline,
                      title: '機能リクエスト',
                      subtitle: 'ご要望をお聞かせください',
                      accentColor: accentColor,
                      onTap: () => _openFeatureRequest(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 法的情報
              _buildSectionTitle('法的情報'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _LinkItem(
                      icon: Icons.description,
                      title: '利用規約',
                      accentColor: accentColor,
                      onTap: () => _openTerms(context),
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _LinkItem(
                      icon: Icons.privacy_tip,
                      title: 'プライバシーポリシー',
                      accentColor: accentColor,
                      onTap: () => _openPrivacy(context),
                    ),
                    Divider(height: 1, color: AppColors.textLight.withValues(alpha: 0.2)),
                    _LinkItem(
                      icon: Icons.gavel,
                      title: '特定商取引法に基づく表記',
                      accentColor: accentColor,
                      onTap: () => _openCommercialLaw(context),
                    ),
                  ],
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

  Widget _buildAboutCard(BuildContext context, Color accentColor) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.smart_toy,
                  color: accentColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DARIAS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'あなたの毎日をサポートするAIパートナー',
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
          const SizedBox(height: 16),
          Text(
            'DARIASは、AIキャラクターとの会話を通じて日々の記録をサポートするアプリです。'
            'チャット、日記、TODO、スケジュール管理など、あなたの毎日をより豊かにする機能を提供します。',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:darias.app4@gmail.com?subject=DARIASアプリについて');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを開けませんでした')),
        );
      }
    }
  }

  Future<void> _openBugReport(BuildContext context) async {
    final uri = Uri.parse('mailto:darias.app4@gmail.com?subject=[バグ報告] DARIASアプリ');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを開けませんでした')),
        );
      }
    }
  }

  Future<void> _openFeatureRequest(BuildContext context) async {
    final uri = Uri.parse('mailto:darias.app4@gmail.com?subject=[機能リクエスト] DARIASアプリ');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを開けませんでした')),
        );
      }
    }
  }

  void _openTerms(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('利用規約ページは準備中です')),
    );
  }

  void _openPrivacy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プライバシーポリシーページは準備中です')),
    );
  }

  void _openCommercialLaw(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('特定商取引法に基づく表記ページは準備中です')),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  final Color accentColor;

  const _FAQItem({
    required this.question,
    required this.answer,
    required this.accentColor,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: widget.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.question,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _ContactItem({
    required this.icon,
    required this.title,
    required this.subtitle,
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
              Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final VoidCallback onTap;

  const _LinkItem({
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
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
