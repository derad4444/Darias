import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/todo_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// Todo詳細・編集画面
class TodoDetailScreen extends ConsumerStatefulWidget {
  /// 編集対象のTodo（nullの場合は新規作成）
  final TodoModel? todo;

  const TodoDetailScreen({
    super.key,
    this.todo,
  });

  @override
  ConsumerState<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends ConsumerState<TodoDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime? _dueDate;
  bool _hasDueDate = false;
  TodoPriority _priority = TodoPriority.medium;
  String _tag = '';
  bool _isCompleted = false;
  bool _isSaving = false;

  bool get _isNewTodo => widget.todo == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.todo?.description ?? '');

    if (widget.todo != null) {
      final todo = widget.todo!;
      _dueDate = todo.dueDate;
      _hasDueDate = todo.dueDate != null;
      _priority = todo.priority;
      _tag = todo.tag;
      _isCompleted = todo.isCompleted;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_isNewTodo ? '新規TODO' : 'TODO編集'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _titleController.text.isEmpty || _isSaving
                ? null
                : _saveTodo,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上部バナー広告
            if (shouldShowBannerAd) ...[
              const BannerAdContainer(),
              const SizedBox(height: 16),
            ],

            // タイトル
            _buildSectionTitle('タイトル'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'タイトルを入力',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 説明
            _buildSectionTitle('説明'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '説明を入力（任意）',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 期限設定
            _buildDueDateSection(colorScheme),
            const SizedBox(height: 16),

            // 優先度
            _buildPrioritySection(colorScheme),
            const SizedBox(height: 16),

            // タグ
            _buildTagSection(colorScheme),
            const SizedBox(height: 16),

            // 完了状態（編集時のみ）
            if (!_isNewTodo) ...[
              _buildCompletedSection(colorScheme),
              const SizedBox(height: 24),
            ],

            // 削除ボタン（編集時のみ）
            if (!_isNewTodo) ...[
              OutlinedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'TODOを削除',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 下部バナー広告
            if (shouldShowBannerAd) ...[
              const SizedBox(height: 16),
              const BannerAdContainer(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
    );
  }

  Widget _buildDueDateSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.schedule),
              const SizedBox(width: 12),
              const Expanded(child: Text('期限を設定')),
              Switch(
                value: _hasDueDate,
                onChanged: (value) {
                  setState(() {
                    _hasDueDate = value;
                    if (value && _dueDate == null) {
                      _dueDate = DateTime.now().add(const Duration(days: 1));
                    }
                  });
                },
              ),
            ],
          ),
          if (_hasDueDate) ...[
            const Divider(),
            InkWell(
              onTap: _selectDueDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate != null
                          ? DateFormat('yyyy/MM/dd HH:mm').format(_dueDate!)
                          : '日時を選択',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrioritySection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('優先度'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: TodoPriority.values.map((priority) {
              final isSelected = _priority == priority;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = priority),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getPriorityColor(priority)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTagSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('タグ'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'タグを入力（任意）',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _tag = value,
            controller: TextEditingController(text: _tag),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: _isCompleted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('完了')),
          Switch(
            value: _isCompleted,
            onChanged: (value) => setState(() => _isCompleted = value),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.low:
        return Colors.grey;
      case TodoPriority.medium:
        return Colors.blue;
      case TodoPriority.high:
        return Colors.red;
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
      );

      if (time != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveTodo() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        throw Exception('ユーザーが見つかりません');
      }

      if (_isNewTodo) {
        // 新規作成
        final newTodo = TodoModel.create(
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _hasDueDate ? _dueDate : null,
          priority: _priority,
          tag: _tag,
        );
        await ref.read(todoControllerProvider.notifier).addTodo(newTodo);
      } else {
        // 更新
        final updatedTodo = widget.todo!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _hasDueDate ? _dueDate : null,
          priority: _priority,
          tag: _tag,
          isCompleted: _isCompleted,
          updatedAt: DateTime.now(),
        );
        await ref.read(todoControllerProvider.notifier).updateTodo(updatedTodo);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TODOを削除'),
        content: const Text('このTODOを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTodo();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTodo() async {
    if (widget.todo == null) return;

    try {
      await ref.read(todoControllerProvider.notifier).deleteTodo(widget.todo!.id);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
}
