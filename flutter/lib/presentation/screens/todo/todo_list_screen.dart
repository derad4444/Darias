import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/todo_model.dart';
import '../../providers/todo_provider.dart';

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTodosAsync = ref.watch(filteredTodosProvider);
    final statsAsync = ref.watch(todoStatsProvider);
    final currentFilter = ref.watch(todoFilterProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('タスク'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // フィルターセグメント
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<TodoFilter>(
              segments: TodoFilter.values.map((filter) {
                return ButtonSegment<TodoFilter>(
                  value: filter,
                  label: Text(filter.displayName),
                );
              }).toList(),
              selected: {currentFilter},
              onSelectionChanged: (selected) {
                ref.read(todoFilterProvider.notifier).state = selected.first;
              },
            ),
          ),

          // 統計カード
          statsAsync.when(
            data: (stats) => _StatsSection(stats: stats),
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),

          // Todoリスト
          Expanded(
            child: filteredTodosAsync.when(
              data: (todos) => todos.isEmpty
                  ? _EmptyState(filter: currentFilter)
                  : _TodoList(todos: todos),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('エラー: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/todo/detail'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 統計セクション
class _StatsSection extends StatelessWidget {
  final TodoStats stats;

  const _StatsSection({required this.stats});

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final TodoFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            filter == TodoFilter.all
                ? 'タスクがありません'
                : filter == TodoFilter.incomplete
                    ? '未完了のタスクがありません'
                    : '完了済みのタスクがありません',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (filter == TodoFilter.all)
            Text(
              '右下の+ボタンで追加できます',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
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

  const _TodoList({required this.todos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return _TodoItem(todo: todo);
      },
    );
  }
}

/// Todoアイテム
class _TodoItem extends ConsumerWidget {
  final TodoModel todo;

  const _TodoItem({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = switch (todo.priority) {
      TodoPriority.high => Colors.red,
      TodoPriority.medium => Colors.blue,
      TodoPriority.low => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEditDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // チェックボックス
              Checkbox(
                value: todo.isCompleted,
                onChanged: (value) {
                  ref.read(todoControllerProvider.notifier).toggleComplete(
                    todo.id,
                    value ?? false,
                  );
                },
              ),

              // コンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル
                    Text(
                      todo.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: todo.isCompleted
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),

                    // 説明（あれば）
                    if (todo.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        todo.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 期限（あれば）
                    if (todo.dueDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: todo.isOverdue
                                ? Colors.red
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(todo.dueDate!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: todo.isOverdue
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
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

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    context.push('/todo/detail', extra: todo);
  }
}

/// Todo編集シート
class _TodoEditSheet extends ConsumerStatefulWidget {
  final TodoModel? todo;

  const _TodoEditSheet({this.todo});

  @override
  ConsumerState<_TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends ConsumerState<_TodoEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TodoPriority _priority;
  DateTime? _dueDate;

  bool get isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descriptionController = TextEditingController(text: widget.todo?.description ?? '');
    _priority = widget.todo?.priority ?? TodoPriority.medium;
    _dueDate = widget.todo?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'タスクを編集' : '新しいタスク',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteTodo,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // タイトル
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
              ),
              autofocus: !isEditing,
            ),
            const SizedBox(height: 16),

            // 説明
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '説明（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 優先度
            Row(
              children: [
                const Text('優先度: '),
                const SizedBox(width: 8),
                SegmentedButton<TodoPriority>(
                  segments: TodoPriority.values.map((p) {
                    return ButtonSegment<TodoPriority>(
                      value: p,
                      label: Text(p.displayName),
                    );
                  }).toList(),
                  selected: {_priority},
                  onSelectionChanged: (selected) {
                    setState(() => _priority = selected.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 期限
            Row(
              children: [
                const Text('期限: '),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _dueDate != null
                        ? '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'
                        : '設定なし',
                  ),
                  onPressed: _selectDueDate,
                ),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            FilledButton(
              onPressed: _saveTodo,
              child: Text(isEditing ? '更新' : '追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    try {
      if (isEditing) {
        await ref.read(todoControllerProvider.notifier).updateTodo(
          widget.todo!.copyWith(
            title: title,
            description: _descriptionController.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
          ),
        );
      } else {
        await ref.read(todoControllerProvider.notifier).addTodo(
          TodoModel.create(
            title: title,
            description: _descriptionController.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteTodo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このタスクを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.todo != null) {
      try {
        await ref.read(todoControllerProvider.notifier).deleteTodo(
          widget.todo!.id,
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }
}
