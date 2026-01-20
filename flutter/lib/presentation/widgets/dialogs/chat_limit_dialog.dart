import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// チャット制限ダイアログ
class ChatLimitDialog extends StatelessWidget {
  final int currentCount;
  final int maxCount;
  final VoidCallback? onWatchAd;

  const ChatLimitDialog({
    super.key,
    required this.currentCount,
    required this.maxCount,
    this.onWatchAd,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentCount,
    required int maxCount,
    VoidCallback? onWatchAd,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChatLimitDialog(
        currentCount: currentCount,
        maxCount: maxCount,
        onWatchAd: onWatchAd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // アイコン
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 20),

          // タイトル
          Text(
            '本日のチャット上限に達しました',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // 説明
          Text(
            '無料プランでは1日${maxCount}回までチャットできます。\n明日またお話ししましょう！',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // カウント表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.message,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '$currentCount / $maxCount 回',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 広告を見る
            if (onWatchAd != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onWatchAd!();
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('広告を見て+10回'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // プレミアムアップグレード
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/premium');
              },
              icon: const Icon(Icons.star),
              label: const Text('プレミアムにアップグレード'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // 閉じる
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 会議機能ロックダイアログ
class MeetingFeatureLockedDialog extends StatelessWidget {
  const MeetingFeatureLockedDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const MeetingFeatureLockedDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // アイコン
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // タイトル
          Text(
            '6人会議はプレミアム機能です',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // 説明
          Text(
            '6人の自分が集まって\n様々な視点から議論する機能です。\n\nプレミアムにアップグレードすると\n無制限で利用できます。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 特徴リスト
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _FeatureRow(icon: Icons.groups, text: '6人の自分との会議'),
                const SizedBox(height: 8),
                _FeatureRow(icon: Icons.psychology, text: '多角的な視点で分析'),
                const SizedBox(height: 8),
                _FeatureRow(icon: Icons.lightbulb, text: '新しい発見と気づき'),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // プレミアムアップグレード
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/premium');
              },
              icon: const Icon(Icons.star),
              label: const Text('プレミアムにアップグレード'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // 閉じる
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// 機能アンロックポップアップ
class FeatureUnlockedPopup extends StatelessWidget {
  final String featureName;
  final IconData icon;

  const FeatureUnlockedPopup({
    super.key,
    required this.featureName,
    required this.icon,
  });

  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required IconData icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => FeatureUnlockedPopup(
        featureName: featureName,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // アイコン
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.orange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // お祝いアイコン
          const Text(
            '🎉',
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 12),

          // タイトル
          Text(
            '機能がアンロックされました！',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 機能名
          Text(
            featureName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // 説明
          Text(
            'プレミアム機能をお楽しみください！',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('使ってみる'),
        ),
      ],
    );
  }
}
