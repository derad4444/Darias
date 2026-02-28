import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/todo_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../settings/tag_management_screen.dart';

/// Todo詳細・編集画面
class TodoDetailScreen extends ConsumerStatefulWidget {
  final TodoModel? todo;

  const TodoDetailScreen({super.key, this.todo});

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
    _descriptionController = TextEditingController(text: widget.todo?.description ?? '');

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
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isNewTodo ? '新規TODO' : 'TODO編集',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _titleController.text.isEmpty || _isSaving ? null : _saveTodo,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  )
                : Text('保存', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shouldShowBannerAd) ...[
                  const BannerAdContainer(),
                  const SizedBox(height: 16),
                ],

                // タイトル
                _buildSectionTitle('タイトル'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _titleController,
                  hintText: 'タイトルを入力',
                  accentColor: accentColor,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // 説明（残りスペースを埋める）
                _buildSectionTitle('説明'),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
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
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: '説明を入力（任意）',
                        hintStyle: TextStyle(color: AppColors.textLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 期限設定
                _buildDueDateSection(accentColor),
                const SizedBox(height: 16),

                // 優先度
                _buildPrioritySection(accentColor),
                const SizedBox(height: 16),

                // タグ
                _buildTagSection(accentColor),
                const SizedBox(height: 16),

                // 完了状態（編集時のみ）
                if (!_isNewTodo) ...[
                  _buildCompletedSection(accentColor),
                  const SizedBox(height: 24),
                ],

                // 削除ボタン（編集時のみ）
                if (!_isNewTodo) ...[
                  GestureDetector(
                    onTap: _showDeleteConfirmation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('TODOを削除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (shouldShowBannerAd) ...[
                  const SizedBox(height: 16),
                  const BannerAdContainer(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color accentColor,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Container(
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
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.textLight),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDueDateSection(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: accentColor),
              const SizedBox(width: 12),
              Expanded(child: Text('期限を設定', style: TextStyle(color: AppColors.textPrimary))),
              Switch(
                value: _hasDueDate,
                activeColor: accentColor,
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
            Divider(color: AppColors.textLight.withValues(alpha: 0.3)),
            InkWell(
              onTap: _selectDueDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: accentColor),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate != null
                          ? DateFormat('yyyy/MM/dd HH:mm').format(_dueDate!)
                          : '日時を選択',
                      style: TextStyle(color: AppColors.textPrimary),
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

  Widget _buildPrioritySection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('優先度'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
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
                      color: isSelected ? _getPriorityColor(priority) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority.displayName,
                      textAlign: TextAlign.center,
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
      ],
    );
  }

  Widget _buildTagSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('タグ'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showTagSelection(accentColor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Row(
              children: [
                if (_tag.isNotEmpty) ...[
                  Builder(builder: (context) {
                    final tags = ref.watch(tagsProvider);
                    final tagItem = tags.where((t) => t.name == _tag).firstOrNull;
                    return Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tagItem?.color ?? accentColor,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _tag.isEmpty
                      ? Text(
                          'タグを選択',
                          style: TextStyle(color: AppColors.textLight, fontSize: 15),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTagColor(accentColor).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _tag,
                            style: TextStyle(color: _getTagColor(accentColor), fontSize: 15),
                          ),
                        ),
                ),
                Icon(Icons.keyboard_arrow_down, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getTagColor(Color accentColor) {
    final tags = ref.read(tagsProvider);
    final tagItem = tags.where((t) => t.name == _tag).firstOrNull;
    return tagItem?.color ?? accentColor;
  }

  void _showTagSelection(Color accentColor) {
    final backgroundGradient = ref.read(backgroundGradientProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text('キャンセル', style: TextStyle(color: accentColor)),
                    ),
                    const Text(
                      'タグ選択',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 80),
                  ],
                ),
              ),

              // タグ一覧
              Expanded(
                child: Consumer(builder: (context, ref, _) {
                  final tags = ref.watch(tagsProvider);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // タグなしオプション
                      _buildTagOption(
                        sheetContext: sheetContext,
                        name: 'タグなし',
                        color: null,
                        isSelected: _tag.isEmpty,
                        accentColor: accentColor,
                        onTap: () {
                          setState(() => _tag = '');
                          Navigator.pop(sheetContext);
                        },
                      ),
                      const SizedBox(height: 8),

                      // 既存タグ一覧
                      ...tags.map((tag) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTagOption(
                              sheetContext: sheetContext,
                              name: tag.name,
                              color: tag.color,
                              isSelected: _tag == tag.name,
                              accentColor: accentColor,
                              onTap: () {
                                setState(() => _tag = tag.name);
                                Navigator.pop(sheetContext);
                              },
                            ),
                          )),

                      const SizedBox(height: 16),

                      // タグを管理ボタン
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.push('/tag-management');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.settings, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('タグを管理', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagOption({
    required BuildContext sheetContext,
    required String name,
    required Color? color,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: color == null
                    ? Border.all(color: AppColors.textLight, width: 2)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 15)),
            ),
            if (isSelected)
              Icon(Icons.check, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSection(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: _isCompleted ? Colors.green : AppColors.textLight,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('完了', style: TextStyle(color: AppColors.textPrimary))),
          Switch(
            value: _isCompleted,
            activeColor: accentColor,
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
          _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _saveTodo() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('ユーザーが見つかりません');

      if (_isNewTodo) {
        final newTodo = TodoModel.create(
          title: _titleController.text,
          description: _descriptionController.text,
          dueDate: _hasDueDate ? _dueDate : null,
          priority: _priority,
          tag: _tag,
        );
        await ref.read(todoControllerProvider.notifier).addTodo(newTodo);
      } else {
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

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
}
