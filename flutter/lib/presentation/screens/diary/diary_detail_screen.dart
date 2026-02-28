import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/diary_model.dart';
import '../../providers/diary_provider.dart';
import '../../providers/theme_provider.dart';

/// 日記詳細をシートで表示するヘルパー
void showDiaryDetailSheet({
  required BuildContext context,
  required DiaryModel diary,
  required String characterId,
  required Color accentColor,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DiaryDetailSheet(
      diary: diary,
      characterId: characterId,
      accentColor: accentColor,
    ),
  );
}

/// 日記詳細シート
class DiaryDetailSheet extends ConsumerStatefulWidget {
  final DiaryModel diary;
  final String characterId;
  final Color accentColor;

  const DiaryDetailSheet({
    super.key,
    required this.diary,
    required this.characterId,
    required this.accentColor,
  });

  @override
  ConsumerState<DiaryDetailSheet> createState() => _DiaryDetailSheetState();
}

class _DiaryDetailSheetState extends ConsumerState<DiaryDetailSheet> {
  late final TextEditingController _commentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.diary.userComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ヘッダー
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '日記',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: _shareDiary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // コンテンツ
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDiaryCard(),
                    _buildCommentSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.diary.dateString,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'serif',
                  color: Colors.brown,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.menu_book,
                color: Colors.brown.withValues(alpha: 0.6),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Column(
                children: List.generate(
                  25,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: 21.5),
                    height: 0.5,
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Text(
                widget.diary.content,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'serif',
                  height: 1.375,
                  color: Colors.black.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.message_outlined,
                color: widget.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'あなたのコメント',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'この日の感想やメモを残しましょう...',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _isSaving ? null : _saveComment,
                child: Container(
                  width: 90,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else ...[
                        const Icon(Icons.check, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        const Text(
                          '保存',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
