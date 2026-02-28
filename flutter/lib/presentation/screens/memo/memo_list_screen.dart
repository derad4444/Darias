import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo_model.dart';
import '../../providers/memo_provider.dart';
import '../../providers/theme_provider.dart';

class MemoListScreen extends ConsumerWidget {
  const MemoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final memosAsync = ref.watch(memosProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/'),
        ),
        title: Text('メモ', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: memosAsync.when(
            data: (memos) => memos.isEmpty
                ? _EmptyState(accentColor: accentColor)
                : _MemoList(memos: memos, accentColor: accentColor),
            loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
            error: (e, st) => Center(child: Text('エラー: $e')),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor, accentColor.withValues(alpha: 0.8)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/memo/detail'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

/// 空状態
class _EmptyState extends StatelessWidget {
  final Color accentColor;

  const _EmptyState({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'メモがありません',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '右下の+ボタンで追加できます',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// メモリスト
class _MemoList extends ConsumerWidget {
  final List<MemoModel> memos;
  final Color accentColor;

  const _MemoList({required this.memos, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: memos.length,
      itemBuilder: (context, index) {
        final memo = memos[index];
        return _MemoCard(memo: memo, accentColor: accentColor);
      },
    );
  }
}

/// メモカード
class _MemoCard extends ConsumerWidget {
  final MemoModel memo;
  final Color accentColor;

  const _MemoCard({required this.memo, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/memo/detail', extra: memo),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー
                Row(
                  children: [
                    if (memo.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.push_pin,
                          size: 16,
                          color: accentColor,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        memo.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ピン留めボタン
                    GestureDetector(
                      onTap: () {
                        ref.read(memoControllerProvider.notifier).togglePin(
                          memo.id,
                          !memo.isPinned,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          memo.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 20,
                          color: memo.isPinned ? accentColor : AppColors.textLight,
                        ),
                      ),
                    ),
                  ],
                ),

                // 内容プレビュー
                if (memo.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    memo.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // タグ（あれば）
                if (memo.tag.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      memo.tag,
                      style: TextStyle(
                        fontSize: 11,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],

                // 更新日時
                const SizedBox(height: 8),
                Text(
                  '更新: ${_formatDate(memo.updatedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
