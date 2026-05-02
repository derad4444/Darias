import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/memo_content_utils.dart';
import '../../providers/theme_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/draggable_fab.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../providers/ad_provider.dart';
import '../../../data/services/ad_service.dart';
import '../settings/tag_management_screen.dart';

/// ノートのセグメント
enum NoteSegment { schedule, memo, todo }

/// 現在選択されているセグメント
final noteSegmentProvider = StateProvider<NoteSegment>((ref) => NoteSegment.schedule);

/// メモタブで選択中のタグフィルター
final memoSelectedTagProvider = StateProvider<String>((ref) => 'すべて');

/// タスクタブで選択中のタグフィルター
final todoSelectedTagProvider = StateProvider<String>((ref) => 'すべて');

/// iOS版NoteViewと同じ構成のノート画面
class NoteScreen extends ConsumerWidget {
  const NoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSegment = ref.watch(noteSegmentProvider);
    final accentColor = ref.watch(accentColorProvider);
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    void onFabTap() {
      if (selectedSegment == NoteSegment.schedule) {
        context.push('/calendar/detail', extra: {'initialDate': DateTime.now()});
      } else if (selectedSegment == NoteSegment.memo) {
        final selectedTag = ref.read(memoSelectedTagProvider);
        final initialTag = (selectedTag != 'すべて') ? selectedTag : '';
        context.push('/memo/detail', extra: {'initialTag': initialTag});
      } else {
        final selectedTag = ref.read(todoSelectedTagProvider);
        final initialTag = (selectedTag != 'すべて') ? selectedTag : '';
        context.push('/todo/detail', extra: {'initialTag': initialTag});
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ノート'),
        centerTitle: true,
      ),
      body: DraggableFabStack(
        onTap: onFabTap,
        accentColor: accentColor,
        child: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _SegmentControl(
                    selectedSegment: selectedSegment,
                    accentColor: accentColor,
                    onSegmentChanged: (segment) {
                      ref.read(noteSegmentProvider.notifier).state = segment;
                    },
                  ),
                ),
                Expanded(
                  child: switch (selectedSegment) {
                    NoteSegment.schedule => const ScheduleContentView(),
                    NoteSegment.memo => const MemoContentView(),
                    NoteSegment.todo => const TodoContentView(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// セグメントコントロール
class _SegmentControl extends StatelessWidget {
  final NoteSegment selectedSegment;
  final Color accentColor;
  final ValueChanged<NoteSegment> onSegmentChanged;

  const _SegmentControl({
    required this.selectedSegment,
    required this.accentColor,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: '予定',
              icon: Icons.calendar_today,
              isSelected: selectedSegment == NoteSegment.schedule,
              accentColor: accentColor,
              onTap: () => onSegmentChanged(NoteSegment.schedule),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'メモ',
              icon: Icons.edit_note,
              isSelected: selectedSegment == NoteSegment.memo,
              accentColor: accentColor,
              onTap: () => onSegmentChanged(NoteSegment.memo),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'タスク',
              icon: Icons.check_circle_outline,
              isSelected: selectedSegment == NoteSegment.todo,
              accentColor: accentColor,
              onTap: () => onSegmentChanged(NoteSegment.todo),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? accentColor : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 予定コンテンツビュー
class ScheduleContentView extends ConsumerWidget {
  const ScheduleContentView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = ref.watch(accentColorProvider);
    final schedulesAsync = ref.watch(allSchedulesProvider);
    final tags = ref.watch(tagsProvider);
    final tagColorMap = {for (final t in tags) t.name: t.color};

    return schedulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
      data: (schedules) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcoming = schedules
            .where((s) {
              final endDay = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);
              return !endDay.isBefore(today);
            })
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

        if (upcoming.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  '予定がありません',
                  style: TextStyle(fontSize: 18, color: Colors.grey.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcoming.length,
          itemBuilder: (context, index) {
            final schedule = upcoming[index];
            final tagColor = tagColorMap[schedule.tag];
            final hasTagColor = tagColor != null;
            final startDay = DateTime(schedule.startDate.year, schedule.startDate.month, schedule.startDate.day);
            final isToday = startDay == today;
            final isPast = startDay.isBefore(today);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.push('/calendar/detail', extra: {'schedule': schedule}),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hasTagColor
                        ? tagColor.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: hasTagColor
                        ? Border(left: BorderSide(color: tagColor, width: 4))
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 日付バッジ
                      Container(
                        width: 46,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isToday
                              ? accentColor
                              : isPast
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : (hasTagColor ? tagColor.withValues(alpha: 0.15) : accentColor.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${schedule.startDate.month}/${schedule.startDate.day}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isToday ? Colors.white : (hasTagColor ? tagColor : accentColor),
                              ),
                            ),
                            if (schedule.isMultiDay)
                              Text(
                                '〜${schedule.endDate.month}/${schedule.endDate.day}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isToday ? Colors.white.withValues(alpha: 0.8) : (hasTagColor ? tagColor : accentColor).withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isToday)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '今日',
                                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    schedule.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (!schedule.isAllDay) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${schedule.startDate.hour.toString().padLeft(2, '0')}:${schedule.startDate.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                            if (schedule.location.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      schedule.location,
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (schedule.tag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (tagColor ?? accentColor).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            schedule.tag,
                            style: TextStyle(fontSize: 11, color: tagColor ?? accentColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// メモコンテンツビュー
class MemoContentView extends ConsumerStatefulWidget {
  const MemoContentView();

  @override
  ConsumerState<MemoContentView> createState() => MemoContentViewState();
}

class MemoContentViewState extends ConsumerState<MemoContentView> {
  final TextEditingController _searchController = TextEditingController();

  String get _selectedTag => ref.read(memoSelectedTagProvider);
  set _selectedTag(String value) => ref.read(memoSelectedTagProvider.notifier).state = value;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = ref.watch(accentColorProvider);
    final memosAsync = ref.watch(memosProvider);
    final selectedTag = ref.watch(memoSelectedTagProvider);
    final tags = ref.watch(tagsProvider);
    final tagColorMap = {for (final t in tags) t.name: t.color};
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return memosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
      data: (memos) {
        // フィルター適用
        var filteredMemos = memos;
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          filteredMemos = filteredMemos
              .where((m) =>
                  m.title.toLowerCase().contains(query) ||
                  extractPlainText(m.content).toLowerCase().contains(query))
              .toList();
        }
        if (selectedTag != 'すべて') {
          filteredMemos =
              filteredMemos.where((m) => m.tag == selectedTag).toList();
        }

        // 利用可能なタグ（tagsProviderの登録順を維持、実際に使われているもののみ表示）
        final usedTagSet = {for (final m in memos) if (m.tag.isNotEmpty) m.tag};
        final availableTags = ['すべて'] +
            tags.map((t) => t.name).where((name) => usedTagSet.contains(name)).toList();

        return Column(
          children: [
            // 検索バー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'メモを検索',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),

            // タグフィルター
            if (availableTags.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: availableTags.map((tag) {
                    final isSelected = selectedTag == tag;
                    final chipColor = tag == 'すべて' ? accentColor : (tagColorMap[tag] ?? accentColor);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ref.read(memoSelectedTagProvider.notifier).state = tag,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? chipColor
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : chipColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // メモ一覧
            Expanded(
              child: filteredMemos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 60,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'メモがありません',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredMemos.length + (shouldShowBannerAd ? 2 : 0),
                      itemBuilder: (context, index) {
                        if (shouldShowBannerAd) {
                          if (index == 0) {
                            return BannerAdContainer(
                              adUnitId: AdConfig.memoTopBannerAdUnitId,
                              padding: const EdgeInsets.only(bottom: 8),
                            );
                          }
                          if (index == filteredMemos.length + 1) {
                            return BannerAdContainer(
                              adUnitId: AdConfig.memoBottomBannerAdUnitId,
                              padding: const EdgeInsets.only(top: 8),
                            );
                          }
                          final memo = filteredMemos[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MemoCard(
                              title: memo.title,
                              content: extractPlainText(memo.content),
                              tag: memo.tag,
                              isPinned: memo.isPinned,
                              accentColor: accentColor,
                              tagColor: tagColorMap[memo.tag],
                              onTap: () => context.push('/memo/detail', extra: memo),
                              onLongPress: () => _confirmDelete(
                                context,
                                title: memo.title,
                                onConfirm: () => ref.read(memoControllerProvider.notifier).deleteMemo(memo.id),
                              ),
                            ),
                          );
                        }
                        final memo = filteredMemos[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MemoCard(
                            title: memo.title,
                            content: extractPlainText(memo.content),
                            tag: memo.tag,
                            isPinned: memo.isPinned,
                            accentColor: accentColor,
                            tagColor: tagColorMap[memo.tag],
                            onTap: () => context.push('/memo/detail', extra: memo),
                            onLongPress: () => _confirmDelete(
                              context,
                              title: memo.title,
                              onConfirm: () => ref.read(memoControllerProvider.notifier).deleteMemo(memo.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// メモカード
class _MemoCard extends StatelessWidget {
  final String title;
  final String content;
  final String tag;
  final bool isPinned;
  final Color accentColor;
  final Color? tagColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MemoCard({
    required this.title,
    required this.content,
    required this.tag,
    required this.isPinned,
    required this.accentColor,
    this.tagColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasTagColor = tagColor != null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasTagColor
              ? tagColor!.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: hasTagColor
              ? Border(left: BorderSide(color: tagColor!, width: 4))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.push_pin, size: 16, color: accentColor),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (tagColor ?? accentColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 11, color: tagColor ?? accentColor),
                    ),
                  ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Todoコンテンツビュー
class TodoContentView extends ConsumerStatefulWidget {
  const TodoContentView();

  @override
  ConsumerState<TodoContentView> createState() => TodoContentViewState();
}

class TodoContentViewState extends ConsumerState<TodoContentView> {
  String _selectedFilter = 'すべて';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = ref.watch(accentColorProvider);
    final todosAsync = ref.watch(todosProvider);
    final selectedTag = ref.watch(todoSelectedTagProvider);
    final tags = ref.watch(tagsProvider);
    final tagColorMap = {for (final t in tags) t.name: t.color};
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
      data: (todos) {
        // フィルター適用
        var filteredTodos = todos;
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          filteredTodos = filteredTodos
              .where((t) =>
                  t.title.toLowerCase().contains(query) ||
                  t.description.toLowerCase().contains(query))
              .toList();
        }
        if (_selectedFilter == '未完了') {
          filteredTodos = filteredTodos.where((t) => !t.isCompleted).toList();
        } else if (_selectedFilter == '完了済み') {
          filteredTodos = filteredTodos.where((t) => t.isCompleted).toList();
        }
        if (selectedTag != 'すべて') {
          filteredTodos =
              filteredTodos.where((t) => t.tag == selectedTag).toList();
        }

        // 統計
        final incompleteCount = todos.where((t) => !t.isCompleted).length;
        final overdueCount = todos.where((t) {
          if (t.dueDate == null || t.isCompleted) return false;
          return t.dueDate!.isBefore(DateTime.now());
        }).length;
        final completedCount = todos.where((t) => t.isCompleted).length;

        // 利用可能なタグ（tagsProviderの登録順を維持、実際に使われているもののみ表示）
        final usedTagSet = {for (final t in todos) if (t.tag.isNotEmpty) t.tag};
        final availableTags = ['すべて'] +
            tags.map((t) => t.name).where((name) => usedTagSet.contains(name)).toList();

        return Column(
          children: [
            // 検索バー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'タスクを検索',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),

            // フィルターセグメント
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: ['すべて', '未完了', '完了済み'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            filter,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? accentColor
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // タグフィルター
            if (availableTags.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: availableTags.map((tag) {
                    final isSelected = selectedTag == tag;
                    final chipColor = tag == 'すべて' ? accentColor : (tagColorMap[tag] ?? accentColor);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ref.read(todoSelectedTagProvider.notifier).state = tag,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? chipColor
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : chipColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // 統計カード
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: '未完了',
                      count: incompleteCount,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: '期限切れ',
                      count: overdueCount,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: '完了',
                      count: completedCount,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // タスク一覧
            Expanded(
              child: filteredTodos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.checklist,
                            size: 60,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'タスクがありません',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredTodos.length + (shouldShowBannerAd ? 2 : 0),
                      itemBuilder: (context, index) {
                        if (shouldShowBannerAd) {
                          if (index == 0) {
                            return BannerAdContainer(
                              adUnitId: AdConfig.taskTopBannerAdUnitId,
                              padding: const EdgeInsets.only(bottom: 8),
                            );
                          }
                          if (index == filteredTodos.length + 1) {
                            return BannerAdContainer(
                              adUnitId: AdConfig.taskBottomBannerAdUnitId,
                              padding: const EdgeInsets.only(top: 8),
                            );
                          }
                          final todo = filteredTodos[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TodoRow(
                              title: todo.title,
                              isCompleted: todo.isCompleted,
                              dueDate: todo.dueDate,
                              priority: todo.priority.displayName,
                              tag: todo.tag,
                              accentColor: accentColor,
                              tagColor: tagColorMap[todo.tag],
                              onTap: () => context.push('/todo/detail', extra: todo),
                              onToggle: () {
                                ref.read(todoControllerProvider.notifier).toggleComplete(
                                      todo.id,
                                      !todo.isCompleted,
                                    );
                              },
                              onLongPress: () => _confirmDelete(
                                context,
                                title: todo.title,
                                onConfirm: () => ref.read(todoControllerProvider.notifier).deleteTodo(todo.id),
                              ),
                            ),
                          );
                        }
                        final todo = filteredTodos[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TodoRow(
                            title: todo.title,
                            isCompleted: todo.isCompleted,
                            dueDate: todo.dueDate,
                            priority: todo.priority.displayName,
                            tag: todo.tag,
                            accentColor: accentColor,
                            tagColor: tagColorMap[todo.tag],
                            onTap: () => context.push('/todo/detail', extra: todo),
                            onToggle: () {
                              ref.read(todoControllerProvider.notifier).toggleComplete(
                                    todo.id,
                                    !todo.isCompleted,
                                  );
                            },
                            onLongPress: () => _confirmDelete(
                              context,
                              title: todo.title,
                              onConfirm: () => ref.read(todoControllerProvider.notifier).deleteTodo(todo.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 統計カード
class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Todoロウ
class _TodoRow extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final String priority;
  final String tag;
  final Color accentColor;
  final Color? tagColor;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;

  const _TodoRow({
    required this.title,
    required this.isCompleted,
    this.dueDate,
    required this.priority,
    required this.tag,
    required this.accentColor,
    this.tagColor,
    required this.onTap,
    required this.onToggle,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = dueDate != null &&
        dueDate!.isBefore(DateTime.now()) &&
        !isCompleted;

    final hasTagColor = tagColor != null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasTagColor
              ? tagColor!.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: hasTagColor
              ? Border(left: BorderSide(color: tagColor!, width: 4))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // チェックボックス
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? Colors.green : accentColor,
                    width: 2,
                  ),
                  color: isCompleted ? Colors.green : Colors.transparent,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // タイトルと期限
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isCompleted
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (dueDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : AppColors.textLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // タグと優先度
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tag.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (tagColor ?? accentColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 11, color: tagColor ?? accentColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priority == '高'
                        ? Colors.red.withValues(alpha: 0.1)
                        : priority == '中'
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 11,
                      color: priority == '高'
                          ? Colors.red
                          : priority == '中'
                              ? Colors.orange
                              : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays == 0) {
      return '今日';
    } else if (diff.inDays == 1) {
      return '明日';
    } else if (diff.inDays == -1) {
      return '昨日';
    } else if (diff.inDays < 0) {
      return '${-diff.inDays}日前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日後';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

/// 削除確認ダイアログ
Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('削除'),
      content: Text('「$title」を削除しますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  if (confirmed == true) onConfirm();
}
