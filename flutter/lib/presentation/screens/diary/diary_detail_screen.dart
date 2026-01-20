import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/diary_model.dart';
import '../../providers/diary_provider.dart';
import '../../providers/ad_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// 日記詳細画面
class DiaryDetailScreen extends ConsumerStatefulWidget {
  final DiaryModel diary;
  final String characterId;

  const DiaryDetailScreen({
    super.key,
    required this.diary,
    required this.characterId,
  });

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  late final TextEditingController _commentController;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _commentController =
        TextEditingController(text: widget.diary.userComment);
    // 日記を見たらバッジをクリア
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).clearBadge();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.diary.dateString),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDiary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上部バナー広告
            if (shouldShowBannerAd) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: BannerAdContainer(),
              ),
            ],

            // 日記カード（日記帳風デザイン）
            _buildDiaryCard(context),

            // コメントセクション
            _buildCommentSection(context, colorScheme),

            // 下部バナー広告
            if (shouldShowBannerAd) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: BannerAdContainer(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5), // クリーム色の紙風
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.brown.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日記ヘッダー（装飾付き）
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.brown.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories,
                  color: Colors.brown.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.diary.dateString,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getWeekdayString(widget.diary.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.brown.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // 天気アイコン（デコレーション）
                Icon(
                  Icons.wb_sunny_outlined,
                  color: Colors.orange.shade300,
                  size: 24,
                ),
              ],
            ),
          ),

          // 日記本文
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.diary.content,
              style: TextStyle(
                fontSize: 16,
                height: 2.0,
                color: Colors.brown.shade900,
                fontFamily: 'serif',
              ),
            ),
          ),

          // 罫線デコレーション
          ...List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              height: 1,
              color: Colors.brown.shade100,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCommentSection(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Icon(
                Icons.edit_note,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'あなたのひとこと',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (!_isEditing && widget.diary.userComment.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // コメント表示 or 編集
          if (_isEditing || widget.diary.userComment.isEmpty) ...[
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'この日の感想やメモを残しましょう...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isEditing)
                  TextButton(
                    onPressed: () {
                      _commentController.text = widget.diary.userComment;
                      setState(() => _isEditing = false);
                    },
                    child: const Text('キャンセル'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveComment,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('保存'),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.diary.userComment,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getWeekdayString(DateTime date) {
    const weekdays = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
    return weekdays[date.weekday - 1];
  }

  Future<void> _saveComment() async {
    final comment = _commentController.text.trim();

    setState(() => _isSaving = true);

    try {
      await ref.read(diaryControllerProvider.notifier).saveUserComment(
            characterId: widget.characterId,
            diaryId: widget.diary.id,
            comment: comment,
          );

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コメントを保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _shareDiary() {
    final text = '''
${widget.diary.dateString}の日記

${widget.diary.content}

${widget.diary.userComment.isNotEmpty ? '---\nひとこと: ${widget.diary.userComment}' : ''}
''';

    Share.share(text.trim(), subject: '${widget.diary.dateString}の日記');
  }
}
