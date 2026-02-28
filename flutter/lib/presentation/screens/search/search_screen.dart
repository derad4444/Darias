import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/todo_model.dart';
import '../../../data/models/memo_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/models/diary_model.dart';
import '../../providers/todo_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/theme_provider.dart';
import '../diary/diary_detail_screen.dart';

/// 検索クエリのプロバイダー
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 検索カテゴリのプロバイダー
final searchCategoryProvider = StateProvider<SearchCategory>((ref) => SearchCategory.all);

enum SearchCategory {
  all('すべて'),
  todo('TODO'),
  memo('メモ'),
  schedule('スケジュール'),
  diary('日記');

  final String label;
  const SearchCategory(this.label);
}

/// 検索結果のプロバイダー
final searchResultsProvider = Provider<SearchResults>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final category = ref.watch(searchCategoryProvider);

  if (query.isEmpty) {
    return SearchResults.empty();
  }

  final results = SearchResults(
    todos: [],
    memos: [],
    schedules: [],
    diaries: [],
  );

  // TODO検索
  if (category == SearchCategory.all || category == SearchCategory.todo) {
    final todosAsync = ref.watch(todosProvider);
    todosAsync.whenData((todos) {
      results.todos.addAll(
        todos.where((t) =>
            t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query) ||
            t.tag.toLowerCase().contains(query)),
      );
    });
  }

  // メモ検索
  if (category == SearchCategory.all || category == SearchCategory.memo) {
    final memosAsync = ref.watch(memosProvider);
    memosAsync.whenData((memos) {
      results.memos.addAll(
        memos.where((m) =>
            m.title.toLowerCase().contains(query) ||
            m.content.toLowerCase().contains(query) ||
            m.tag.toLowerCase().contains(query)),
      );
    });
  }

  // スケジュール検索
  if (category == SearchCategory.all || category == SearchCategory.schedule) {
    final schedulesAsync = ref.watch(allSchedulesProvider);
    schedulesAsync.whenData((schedules) {
      results.schedules.addAll(
        schedules.where((s) =>
            s.title.toLowerCase().contains(query) ||
            s.location.toLowerCase().contains(query) ||
            s.memo.toLowerCase().contains(query) ||
            s.tag.toLowerCase().contains(query)),
      );
    });
  }

  // 日記検索
  if (category == SearchCategory.all || category == SearchCategory.diary) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final characterId = user?.characterId;
    if (characterId != null) {
      final diariesAsync = ref.watch(diariesProvider(characterId));
      diariesAsync.whenData((diaries) {
        results.diaries.addAll(
          diaries.where((d) =>
              d.content.toLowerCase().contains(query) ||
              d.userComment.toLowerCase().contains(query)),
        );
      });
    }
  }

  return results;
});

class SearchResults {
  final List<TodoModel> todos;
  final List<MemoModel> memos;
  final List<ScheduleModel> schedules;
  final List<DiaryModel> diaries;

  SearchResults({
    required this.todos,
    required this.memos,
    required this.schedules,
    required this.diaries,
  });

  factory SearchResults.empty() => SearchResults(
        todos: [],
        memos: [],
        schedules: [],
        diaries: [],
      );

  int get totalCount => todos.length + memos.length + schedules.length + diaries.length;
  bool get isEmpty => totalCount == 0;
}

/// 検索画面
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final category = ref.watch(searchCategoryProvider);
    final results = ref.watch(searchResultsProvider);
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            ref.read(searchQueryProvider.notifier).state = '';
            context.pop();
          },
        ),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '検索...',
              hintStyle: const TextStyle(color: AppColors.textLight),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // カテゴリーフィルター
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: SearchCategory.values.map((cat) {
                      final isSelected = category == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            ref.read(searchCategoryProvider.notifier).state = cat;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 検索結果
              Expanded(
                child: query.isEmpty
                    ? _EmptySearchState(accentColor: accentColor)
                    : results.isEmpty
                        ? _NoResultsState(query: query)
                        : _SearchResultsList(results: results, accentColor: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final Color accentColor;

  const _EmptySearchState({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            '検索ワードを入力してください',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'TODO、メモ、スケジュール、日記を\n横断的に検索できます',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final String query;

  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            '「$query」の検索結果はありません',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '別のキーワードで検索してみてください',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  final SearchResults results;
  final Color accentColor;

  const _SearchResultsList({required this.results, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final characterId = user?.characterId ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 結果件数
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${results.totalCount}件の結果',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),

        // TODO結果
        if (results.todos.isNotEmpty) ...[
          _SectionHeader(icon: Icons.check_circle, title: 'TODO', count: results.todos.length, accentColor: accentColor),
          ...results.todos.map((todo) => _TodoResultItem(todo: todo, accentColor: accentColor)),
          const SizedBox(height: 16),
        ],

        // メモ結果
        if (results.memos.isNotEmpty) ...[
          _SectionHeader(icon: Icons.note, title: 'メモ', count: results.memos.length, accentColor: accentColor),
          ...results.memos.map((memo) => _MemoResultItem(memo: memo, accentColor: accentColor)),
          const SizedBox(height: 16),
        ],

        // スケジュール結果
        if (results.schedules.isNotEmpty) ...[
          _SectionHeader(icon: Icons.event, title: 'スケジュール', count: results.schedules.length, accentColor: accentColor),
          ...results.schedules.map((schedule) => _ScheduleResultItem(schedule: schedule, accentColor: accentColor)),
          const SizedBox(height: 16),
        ],

        // 日記結果
        if (results.diaries.isNotEmpty) ...[
          _SectionHeader(icon: Icons.book, title: '日記', count: results.diaries.length, accentColor: accentColor),
          ...results.diaries.map((diary) => _DiaryResultItem(diary: diary, characterId: characterId, accentColor: accentColor)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color accentColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _TodoResultItem extends StatelessWidget {
  final TodoModel todo;
  final Color accentColor;

  const _TodoResultItem({required this.todo, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          todo.isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: todo.isCompleted ? Colors.green : AppColors.textLight,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            color: AppColors.textPrimary,
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: todo.description.isNotEmpty
            ? Text(
                todo.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            : null,
        onTap: () => context.push('/todo/detail', extra: todo),
      ),
    );
  }
}

class _MemoResultItem extends StatelessWidget {
  final MemoModel memo;
  final Color accentColor;

  const _MemoResultItem({required this.memo, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          memo.isPinned ? Icons.push_pin : Icons.note,
          color: memo.isPinned ? accentColor : AppColors.textSecondary,
        ),
        title: Text(
          memo.title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: memo.content.isNotEmpty
            ? Text(
                memo.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            : null,
        onTap: () => context.push('/memo/detail', extra: memo),
      ),
    );
  }
}

class _ScheduleResultItem extends StatelessWidget {
  final ScheduleModel schedule;
  final Color accentColor;

  const _ScheduleResultItem({required this.schedule, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.event, color: accentColor),
        title: Text(
          schedule.title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          schedule.isAllDay
              ? schedule.dateRangeString
              : '${schedule.dateRangeString} ${schedule.startDate.hour}:${schedule.startDate.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        onTap: () => context.push('/calendar/detail', extra: {
          'schedule': schedule,
          'initialDate': null,
        }),
      ),
    );
  }
}

class _DiaryResultItem extends StatelessWidget {
  final DiaryModel diary;
  final String characterId;
  final Color accentColor;

  const _DiaryResultItem({
    required this.diary,
    required this.characterId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.book, color: accentColor),
        title: Text(
          diary.dateString,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          diary.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        onTap: () => showDiaryDetailSheet(
          context: context,
          diary: diary,
          characterId: characterId,
          accentColor: accentColor,
        ),
      ),
    );
  }
}
