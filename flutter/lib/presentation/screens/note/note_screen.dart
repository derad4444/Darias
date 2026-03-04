import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/memo_content_utils.dart';
import '../../providers/theme_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/draggable_fab.dart';
import '../settings/tag_management_screen.dart';

/// ノートのセグメント
enum NoteSegment { memo, todo }

/// 現在選択されているセグメント
final noteSegmentProvider = StateProvider<NoteSegment>((ref) => NoteSegment.memo);

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
      if (selectedSegment == NoteSegment.memo) {
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
                  child: selectedSegment == NoteSegment.memo
                      ? const _MemoContentView()
                      : const _TodoContentView(),
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
              label: 'メモ',
              isSelected: selectedSegment == NoteSegment.memo,
              accentColor: accentColor,
              onTap: () => onSegmentChanged(NoteSegment.memo),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'タスク',
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
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? accentColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// メモコンテンツビュー
class _MemoContentView extends ConsumerStatefulWidget {
  const _MemoContentView();

  @override
  ConsumerState<_MemoContentView> createState() => _MemoContentViewState();
}

class _MemoContentViewState extends ConsumerState<_MemoContentView> {
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

        // 利用可能なタグ（「すべて」を先頭固定、出現順を維持）
        final tagSet = <String>{};
        for (final m in memos) {
          if (m.tag.isNotEmpty) tagSet.add(m.tag);
        }
        final availableTags = ['すべて'] + tagSet.toList();

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
                      itemCount: filteredMemos.length,
                      itemBuilder: (context, index) {
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

  const _MemoCard({
    required this.title,
    required this.content,
    required this.tag,
    required this.isPinned,
    required this.accentColor,
    this.tagColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTagColor = tagColor != null;
    return GestureDetector(
      onTap: onTap,
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
class _TodoContentView extends ConsumerStatefulWidget {
  const _TodoContentView();

  @override
  ConsumerState<_TodoContentView> createState() => _TodoContentViewState();
}

class _TodoContentViewState extends ConsumerState<_TodoContentView> {
  String _selectedFilter = 'すべて';

  @override
  Widget build(BuildContext context) {
    final accentColor = ref.watch(accentColorProvider);
    final todosAsync = ref.watch(todosProvider);
    final selectedTag = ref.watch(todoSelectedTagProvider);
    final tags = ref.watch(tagsProvider);
    final tagColorMap = {for (final t in tags) t.name: t.color};

    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
      data: (todos) {
        // フィルター適用
        var filteredTodos = todos;
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

        // 利用可能なタグ（「すべて」を先頭固定、出現順を維持）
        final tagSet = <String>{};
        for (final t in todos) {
          if (t.tag.isNotEmpty) tagSet.add(t.tag);
        }
        final availableTags = ['すべて'] + tagSet.toList();

        return Column(
          children: [
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
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
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
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = dueDate != null &&
        dueDate!.isBefore(DateTime.now()) &&
        !isCompleted;

    final hasTagColor = tagColor != null;
    return GestureDetector(
      onTap: onTap,
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
