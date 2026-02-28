import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/diary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/theme_provider.dart';
import 'diary_detail_screen.dart';

/// 検索テキストのプロバイダー
final diarySearchTextProvider = StateProvider<String>((ref) => '');

class DiaryListScreen extends ConsumerStatefulWidget {
  const DiaryListScreen({super.key});

  @override
  ConsumerState<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends ConsumerState<DiaryListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final user = ref.watch(userDocProvider).valueOrNull;
    final characterId = user?.characterId;
    final searchText = ref.watch(diarySearchTextProvider);

    final diariesAsync = characterId != null
        ? ref.watch(diariesProvider(characterId))
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: accentColor),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '日記履歴',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: characterId == null
              ? Center(
                  child: Text(
                    'キャラクターを選択してください',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : diariesAsync == null
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : diariesAsync.when(
                      data: (diaries) {
                        // フィルター適用
                        final filteredDiaries = searchText.isEmpty
                            ? diaries
                            : diaries.where((d) =>
                                d.content.toLowerCase().contains(searchText.toLowerCase())).toList();

                        return Column(
                          children: [
                            // 検索バー
                            _SearchBar(
                              controller: _searchController,
                              onChanged: (value) {
                                ref.read(diarySearchTextProvider.notifier).state = value;
                              },
                              onClear: () {
                                _searchController.clear();
                                ref.read(diarySearchTextProvider.notifier).state = '';
                              },
                            ),

                            // コンテンツ
                            Expanded(
                              child: diaries.isEmpty
                                  ? _EmptyState(
                                      icon: Icons.book_outlined,
                                      message: '日記がありません',
                                      submessage: 'キャラクターとの会話から\n日記が自動生成されます',
                                    )
                                  : filteredDiaries.isEmpty
                                      ? _EmptyState(
                                          icon: Icons.search,
                                          message: '検索結果がありません',
                                          submessage: '「$searchText」に一致する日記が見つかりませんでした',
                                        )
                                      : _DiaryList(
                                          diaries: filteredDiaries,
                                          characterId: characterId,
                                          accentColor: accentColor,
                                        ),
                            ),
                          ],
                        );
                      },
                      loading: () => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: accentColor),
                            const SizedBox(height: 16),
                            Text(
                              '読み込み中...',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      error: (e, st) => Center(child: Text('エラー: $e')),
                    ),
        ),
      ),
    );
  }
}

/// 検索バー
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '日記を検索',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: onChanged,
              ),
            ),
            GestureDetector(
              onTap: controller.text.isEmpty ? null : onClear,
              child: Icon(
                Icons.cancel,
                color: controller.text.isEmpty
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状態
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String submessage;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.submessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submessage,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 日記リスト
class _DiaryList extends StatelessWidget {
  final List<DiaryModel> diaries;
  final String characterId;
  final Color accentColor;

  const _DiaryList({
    required this.diaries,
    required this.characterId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: diaries.length,
      itemBuilder: (context, index) {
        final diary = diaries[index];
        return _DiaryCard(
          diary: diary,
          characterId: characterId,
          accentColor: accentColor,
        );
      },
    );
  }
}

/// 日記カード
class _DiaryCard extends StatelessWidget {
  final DiaryModel diary;
  final String characterId;
  final Color accentColor;

  const _DiaryCard({
    required this.diary,
    required this.characterId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // 日付をフォーマット
    final date = diary.date;
    final weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    final weekday = weekdays[date.weekday % 7];
    final dateString = '${date.year}年${date.month}月${date.day}日';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDiaryDetail(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日付ヘッダー
                Row(
                  children: [
                    Icon(
                      Icons.book,
                      size: 18,
                      color: Colors.brown.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateString,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($weekday)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 内容プレビュー
                Text(
                  diary.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // ユーザーコメント（あれば）
                if (diary.userComment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.message,
                        size: 12,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'コメントあり',
                        style: TextStyle(
                          fontSize: 11,
                          color: accentColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiaryDetail(BuildContext context) {
    showDiaryDetailSheet(
      context: context,
      diary: diary,
      characterId: characterId,
      accentColor: accentColor,
    );
  }
}

