import 'package:flutter/material.dart';

/// 空状態を表示するウィジェット
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  /// データが空の状態
  factory EmptyState.noData({
    String title = 'データがありません',
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      icon: Icons.inbox,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 検索結果が空の状態
  factory EmptyState.noSearchResults({
    String query = '',
  }) {
    return EmptyState(
      icon: Icons.search_off,
      title: query.isEmpty ? '検索結果がありません' : '「$query」の検索結果がありません',
      description: '別のキーワードで検索してみてください',
    );
  }

  /// エラー状態
  factory EmptyState.error({
    String title = 'エラーが発生しました',
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      icon: Icons.error_outline,
      title: title,
      description: description ?? '問題が発生しました。しばらくしてからもう一度お試しください。',
      actionLabel: actionLabel ?? '再試行',
      onAction: onAction,
    );
  }

  /// オフライン状態
  factory EmptyState.offline({
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.cloud_off,
      title: 'オフラインです',
      description: 'インターネット接続を確認してください',
      actionLabel: '再試行',
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
