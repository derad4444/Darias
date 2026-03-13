import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/diary_model.dart';
import '../../providers/diary_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../providers/ad_provider.dart';
import '../../../data/services/ad_service.dart';

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
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

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
          child: SafeArea(
            minimum: const EdgeInsets.only(top: 24),
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
                    // 広告バナー（日記の上）
                    if (shouldShowBannerAd)
                      BannerAdContainer(
                        adUnitId: AdConfig.diaryDetailTopBannerAdUnitId,
                        padding: const EdgeInsets.only(bottom: 8),
                      ),
                    widget.diary.isActivityType
                        ? _buildActivityCard()
                        : _buildLegacyDiaryCard(),
                    _buildCommentSection(),
                    // 広告バナー（コメント欄の下）
                    if (shouldShowBannerAd)
                      BannerAdContainer(
                        adUnitId: AdConfig.diaryDetailBottomBannerAdUnitId,
                        padding: const EdgeInsets.only(top: 8),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  /// アクティビティ型日記の表示（新方式）
  Widget _buildActivityCard() {
    final facts = widget.diary.facts ?? [];
    final aiComment = widget.diary.aiComment ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // 日付ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
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
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // 今日やったこと
          if (facts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '今日やったこと',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...facts.map((fact) => _buildFactItem(fact)),
            const SizedBox(height: 8),
          ],

          // AIコメント吹き出し
          if (aiComment.isNotEmpty)
            _buildAiCommentBubble(aiComment),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFactItem(String fact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: widget.accentColor.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fact,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCommentBubble(String comment) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.accentColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: widget.accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                comment,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 従来型日記の表示（後方互換）
  Widget _buildLegacyDiaryCard() {
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
    final buffer = StringBuffer();
    buffer.writeln('${widget.diary.dateString}の日記\n');

    if (widget.diary.isActivityType) {
      final facts = widget.diary.facts ?? [];
      if (facts.isNotEmpty) {
        buffer.writeln('今日やったこと:');
        for (final fact in facts) {
          buffer.writeln('・$fact');
        }
        buffer.writeln();
      }
      if (widget.diary.aiComment?.isNotEmpty == true) {
        buffer.writeln(widget.diary.aiComment);
      }
    } else {
      buffer.writeln(widget.diary.content);
    }

    if (widget.diary.userComment.isNotEmpty) {
      buffer.writeln('\n---\nひとこと: ${widget.diary.userComment}');
    }

    Share.share(buffer.toString().trim(), subject: '${widget.diary.dateString}の日記');
  }
}
