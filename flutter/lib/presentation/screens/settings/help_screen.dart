import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// ヘルプ画面
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('ヘルプ'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // アプリについて
          _SectionHeader(title: 'DARIASについて'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.smart_toy,
                          color: colorScheme.onPrimaryContainer,
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'あなたの毎日をサポートするAIパートナー',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // よくある質問
          _SectionHeader(title: 'よくある質問'),
          _FAQItem(
            question: 'キャラクターを変更するには？',
            answer: 'ホーム画面下部の「キャラクターを変更」ボタンから、お好みのキャラクターを選択できます。',
          ),
          _FAQItem(
            question: '日記はどうやって作成されますか？',
            answer: 'キャラクターとの会話内容から、AIが自動的にその日の日記を生成します。会話を楽しむだけで日記が残ります。',
          ),
          _FAQItem(
            question: 'プレミアム会員になると何ができますか？',
            answer: 'プレミアム会員になると、広告の非表示、チャット回数の無制限化、すべてのキャラクターの解放などの特典があります。',
          ),
          _FAQItem(
            question: 'データはどこに保存されますか？',
            answer: 'すべてのデータはクラウド上に安全に保存されます。機種変更時もアカウントでログインすればデータを引き継げます。',
          ),
          _FAQItem(
            question: '通知が届かない場合は？',
            answer: 'デバイスの設定アプリからDARIASの通知設定を確認してください。また、アプリ内の通知設定も有効になっているか確認してください。',
          ),

          const Divider(),

          // お問い合わせ
          _SectionHeader(title: 'お問い合わせ'),
          _ContactItem(
            icon: Icons.mail,
            title: 'メールでお問い合わせ',
            subtitle: 'darias.app4@gmail.com',
            onTap: () => _openEmail(context),
          ),
          _ContactItem(
            icon: Icons.bug_report,
            title: '不具合を報告',
            subtitle: 'バグや問題をご報告ください',
            onTap: () => _openBugReport(context),
          ),
          _ContactItem(
            icon: Icons.lightbulb_outline,
            title: '機能リクエスト',
            subtitle: 'ご要望をお聞かせください',
            onTap: () => _openFeatureRequest(context),
          ),

          const Divider(),

          // 法的情報
          _SectionHeader(title: '法的情報'),
          _LinkItem(
            icon: Icons.description,
            title: '利用規約',
            onTap: () => _openTerms(context),
          ),
          _LinkItem(
            icon: Icons.privacy_tip,
            title: 'プライバシーポリシー',
            onTap: () => _openPrivacy(context),
          ),
          _LinkItem(
            icon: Icons.gavel,
            title: '特定商取引法に基づく表記',
            onTap: () => _openCommercialLaw(context),
          ),

          const SizedBox(height: 32),
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
    // TODO: 利用規約のURLを開く
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('利用規約ページは準備中です')),
    );
  }

  void _openPrivacy(BuildContext context) {
    // TODO: プライバシーポリシーのURLを開く
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プライバシーポリシーページは準備中です')),
    );
  }

  void _openCommercialLaw(BuildContext context) {
    // TODO: 特商法表記のURLを開く
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('特定商取引法に基づく表記ページは準備中です')),
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

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.answer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
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
  final VoidCallback onTap;

  const _ContactItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _LinkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LinkItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}
