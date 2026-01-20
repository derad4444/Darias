import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/todo_model.dart';
import '../../../data/models/memo_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/models/diary_model.dart';
import '../../providers/todo_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(searchQueryProvider.notifier).state = '';
            context.pop();
          },
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: '検索...',
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
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
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // カテゴリーフィルター
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: SearchCategory.values.map((cat) {
                final isSelected = category == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref.read(searchCategoryProvider.notifier).state = cat;
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 検索結果
          Expanded(
            child: query.isEmpty
                ? _EmptySearchState()
                : results.isEmpty
                    ? _NoResultsState(query: query)
                    : _SearchResultsList(results: results),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '検索ワードを入力してください',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'TODO、メモ、スケジュール、日記を\n横断的に検索できます',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
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
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '「$query」の検索結果はありません',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '別のキーワードで検索してみてください',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  final SearchResults results;

  const _SearchResultsList({required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final characterId = user?.characterId ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 結果件数
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${results.totalCount}件の結果',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),

        // TODO結果
        if (results.todos.isNotEmpty) ...[
          _SectionHeader(icon: Icons.check_circle, title: 'TODO', count: results.todos.length),
          ...results.todos.map((todo) => _TodoResultItem(todo: todo)),
          const SizedBox(height: 16),
        ],

        // メモ結果
        if (results.memos.isNotEmpty) ...[
          _SectionHeader(icon: Icons.note, title: 'メモ', count: results.memos.length),
          ...results.memos.map((memo) => _MemoResultItem(memo: memo)),
          const SizedBox(height: 16),
        ],

        // スケジュール結果
        if (results.schedules.isNotEmpty) ...[
          _SectionHeader(icon: Icons.event, title: 'スケジュール', count: results.schedules.length),
          ...results.schedules.map((schedule) => _ScheduleResultItem(schedule: schedule)),
          const SizedBox(height: 16),
        ],

        // 日記結果
        if (results.diaries.isNotEmpty) ...[
          _SectionHeader(icon: Icons.book, title: '日記', count: results.diaries.length),
          ...results.diaries.map((diary) => _DiaryResultItem(diary: diary, characterId: characterId)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _TodoResultItem extends StatelessWidget {
  final TodoModel todo;

  const _TodoResultItem({required this.todo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          todo.isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: todo.isCompleted ? Colors.green : Colors.grey,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: todo.description.isNotEmpty ? Text(todo.description, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        onTap: () => context.push('/todo/detail', extra: todo),
      ),
    );
  }
}

class _MemoResultItem extends StatelessWidget {
  final MemoModel memo;

  const _MemoResultItem({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          memo.isPinned ? Icons.push_pin : Icons.note,
          color: memo.isPinned ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        title: Text(memo.title),
        subtitle: memo.content.isNotEmpty ? Text(memo.content, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        onTap: () => context.push('/memo/detail', extra: memo),
      ),
    );
  }
}

class _ScheduleResultItem extends StatelessWidget {
  final ScheduleModel schedule;

  const _ScheduleResultItem({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(schedule.title),
        subtitle: Text(
          schedule.isAllDay
              ? schedule.dateRangeString
              : '${schedule.dateRangeString} ${schedule.startDate.hour}:${schedule.startDate.minute.toString().padLeft(2, '0')}',
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

  const _DiaryResultItem({required this.diary, required this.characterId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.book),
        title: Text(diary.dateString),
        subtitle: Text(diary.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => context.push('/diary/detail', extra: {
          'diary': diary,
          'characterId': characterId,
        }),
      ),
    );
  }
}
