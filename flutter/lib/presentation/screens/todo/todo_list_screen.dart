import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/todo_model.dart';
import '../../providers/todo_provider.dart';
import '../../providers/theme_provider.dart';

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final filteredTodosAsync = ref.watch(filteredTodosProvider);
    final statsAsync = ref.watch(todoStatsProvider);
    final currentFilter = ref.watch(todoFilterProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/'),
        ),
        title: Text('タスク', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // フィルターセグメント
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: TodoFilter.values.map((filter) {
                      final isSelected = currentFilter == filter;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => ref.read(todoFilterProvider.notifier).state = filter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              filter.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 統計カード
              statsAsync.when(
                data: (stats) => _StatsSection(stats: stats, accentColor: accentColor),
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
              ),

              // Todoリスト
              Expanded(
                child: filteredTodosAsync.when(
                  data: (todos) => todos.isEmpty
                      ? _EmptyState(filter: currentFilter, accentColor: accentColor)
                      : _TodoList(todos: todos, accentColor: accentColor),
                  loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
                  error: (e, st) => Center(child: Text('エラー: $e')),
                ),
              ),
            ],
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
          onPressed: () => context.push('/todo/detail'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

/// 統計セクション
class _StatsSection extends StatelessWidget {
  final TodoStats stats;
  final Color accentColor;

  const _StatsSection({required this.stats, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '未完了',
              count: stats.incomplete,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: '期限切れ',
              count: stats.overdue,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: '完了',
              count: stats.completed,
              color: Colors.green,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状態
class _EmptyState extends StatelessWidget {
  final TodoFilter filter;
  final Color accentColor;

  const _EmptyState({required this.filter, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            filter == TodoFilter.all
                ? 'タスクがありません'
                : filter == TodoFilter.incomplete
                    ? '未完了のタスクがありません'
                    : '完了済みのタスクがありません',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (filter == TodoFilter.all)
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

/// Todoリスト
class _TodoList extends ConsumerWidget {
  final List<TodoModel> todos;
  final Color accentColor;

  const _TodoList({required this.todos, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return _TodoItem(todo: todo, accentColor: accentColor);
      },
    );
  }
}

/// Todoアイテム
class _TodoItem extends ConsumerWidget {
  final TodoModel todo;
  final Color accentColor;

  const _TodoItem({required this.todo, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = switch (todo.priority) {
      TodoPriority.high => Colors.red,
      TodoPriority.medium => Colors.blue,
      TodoPriority.low => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          onTap: () => context.push('/todo/detail', extra: todo),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // チェックボックス
                GestureDetector(
                  onTap: () {
                    ref.read(todoControllerProvider.notifier).toggleComplete(
                      todo.id,
                      !todo.isCompleted,
                    );
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: todo.isCompleted ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: todo.isCompleted ? accentColor : AppColors.textLight,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: todo.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // コンテンツ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                          color: todo.isCompleted ? AppColors.textLight : AppColors.textPrimary,
                        ),
                      ),
                      if (todo.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          todo.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (todo.dueDate != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: todo.isOverdue ? Colors.red : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(todo.dueDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: todo.isOverdue ? Colors.red : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // 優先度インジケーター
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今日';
    } else if (targetDate == tomorrow) {
      return '明日';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
