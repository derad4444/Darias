import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../data/services/ad_service.dart';
import '../settings/tag_management_screen.dart';

/// Todo詳細・編集画面
class TodoDetailScreen extends ConsumerStatefulWidget {
  final TodoModel? todo;
  final String initialTag;

  const TodoDetailScreen({super.key, this.todo, this.initialTag = ''});

  @override
  ConsumerState<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends ConsumerState<TodoDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime? _dueDate;
  bool _hasDueDate = false;
  bool _dueDatePickerExpanded = false;
  bool _showDueDateYearMonthPicker = false;
  TodoPriority _priority = TodoPriority.medium;
  String _tag = '';
  bool _isCompleted = false;
  bool _isSaving = false;

  bool get _isNewTodo => widget.todo == null || widget.todo!.id.isEmpty;

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
    } else {
      _tag = widget.initialTag;
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
          _isNewTodo ? '新規タスク' : 'タスク編集',
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
          child: CustomScrollView(
            slivers: [
              // タイトル・説明ラベル
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (shouldShowBannerAd) ...[
                      BannerAdContainer(adUnitId: AdConfig.taskAddTopBannerAdUnitId),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionTitle('タイトル'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      hintText: 'タイトルを入力',
                      accentColor: accentColor,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('説明'),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              // 説明欄＋下部項目（スクロール可能・常に表示）
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 説明テキストフィールド（コンテンツ高さで伸縮・最低200px）
                      Container(
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
                          minLines: 8,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: '説明を入力（任意）',
                            hintStyle: TextStyle(color: AppColors.textLight),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDueDateSection(accentColor),
                      const SizedBox(height: 16),
                      _buildPrioritySection(accentColor),
                      const SizedBox(height: 16),
                      _buildTagSection(accentColor),
                      if (!_isNewTodo) ...[
                        const SizedBox(height: 16),
                        _buildCompletedSection(accentColor),
                        const SizedBox(height: 16),
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
                      ],
                      if (shouldShowBannerAd) ...[
                        const SizedBox(height: 16),
                        BannerAdContainer(adUnitId: AdConfig.taskAddBottomBannerAdUnitId),
                      ],
                    ],
                  ),
                ),
              ),

            ],
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
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDueDateSection(Color accentColor) {
    final date = _dueDate ?? DateTime.now().add(const Duration(days: 1));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 期限スイッチ行
          GestureDetector(
            onTap: () {
              setState(() {
                _hasDueDate = !_hasDueDate;
                if (_hasDueDate && _dueDate == null) {
                  _dueDate = DateTime.now().add(const Duration(days: 1));
                }
                if (!_hasDueDate) _dueDatePickerExpanded = false;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
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
                      if (!value) _dueDatePickerExpanded = false;
                    });
                  },
                ),
              ],
            ),
          ),
          // 日時ピル + インラインカレンダー
          if (_hasDueDate) ...[
            Divider(color: AppColors.textLight.withValues(alpha: 0.3)),
            GestureDetector(
              onTap: () => setState(() => _dueDatePickerExpanded = !_dueDatePickerExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('期限', style: TextStyle(color: AppColors.textPrimary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _dueDatePickerExpanded
                            ? accentColor.withValues(alpha: 0.15)
                            : accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: _dueDatePickerExpanded ? 0.5 : 0.3),
                        ),
                      ),
                      child: Text(
                        DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(date),
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: _dueDatePickerExpanded ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_dueDatePickerExpanded) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // 年月ヘッダー
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final m = date.month - 1;
                              final newDate = m < 1
                                  ? DateTime(date.year - 1, 12, date.day, date.hour, date.minute)
                                  : DateTime(date.year, m, date.day.clamp(1, DateTime(date.year, m + 1, 0).day), date.hour, date.minute);
                              setState(() { _dueDate = newDate; _showDueDateYearMonthPicker = false; });
                            },
                            child: Icon(Icons.chevron_left, color: AppColors.textPrimary.withValues(alpha: 0.6), size: 24),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showDueDateYearMonthPicker = !_showDueDateYearMonthPicker),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('yyyy年 M月', 'ja').format(date),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _showDueDateYearMonthPicker ? accentColor : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showDueDateYearMonthPicker ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: _showDueDateYearMonthPicker ? accentColor : AppColors.textPrimary.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final m = date.month + 1;
                              final newDate = m > 12
                                  ? DateTime(date.year + 1, 1, date.day, date.hour, date.minute)
                                  : DateTime(date.year, m, date.day.clamp(1, DateTime(date.year, m + 1, 0).day), date.hour, date.minute);
                              setState(() { _dueDate = newDate; _showDueDateYearMonthPicker = false; });
                            },
                            child: Icon(Icons.chevron_right, color: AppColors.textPrimary.withValues(alpha: 0.6), size: 24),
                          ),
                        ],
                      ),
                    ),
                    if (_showDueDateYearMonthPicker)
                      _TodoYearMonthSelector(
                        year: date.year,
                        month: date.month,
                        textColor: AppColors.textPrimary,
                        accentColor: accentColor,
                        onChanged: (y, m) {
                          final maxDay = DateTime(y, m + 1, 0).day;
                          setState(() {
                            _dueDate = DateTime(y, m, date.day > maxDay ? maxDay : date.day, date.hour, date.minute);
                          });
                        },
                      ),
                    // カレンダー
                    ClipRect(
                      child: SizedBox(
                        height: 300,
                        child: Stack(
                          children: [
                            Positioned(
                              top: -48, left: 0, right: 0, bottom: 0,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                    primary: accentColor,
                                    onSurface: AppColors.textPrimary,
                                  ),
                                ),
                                child: CalendarDatePicker(
                                  key: ValueKey('${date.year}-${date.month}'),
                                  initialDate: date,
                                  firstDate: DateTime(DateTime.now().year - 1),
                                  lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                                  onDateChanged: (d) => setState(() {
                                    _dueDate = DateTime(d.year, d.month, d.day, date.hour, date.minute);
                                    _showDueDateYearMonthPicker = false;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 時間ピッカー
                    Divider(color: AppColors.textPrimary.withValues(alpha: 0.2), height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        height: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, color: AppColors.textPrimary.withValues(alpha: 0.7), size: 20),
                            const SizedBox(width: 16),
                            _TodoTimeWheelPicker(
                              value: date.hour,
                              maxValue: 23,
                              textColor: AppColors.textPrimary,
                              accentColor: accentColor,
                              onChanged: (h) => setState(() {
                                _dueDate = DateTime(date.year, date.month, date.day, h, date.minute);
                              }),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(':', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                            ),
                            _TodoTimeWheelPicker(
                              value: date.minute,
                              maxValue: 59,
                              textColor: AppColors.textPrimary,
                              accentColor: accentColor,
                              onChanged: (m) => setState(() {
                                _dueDate = DateTime(date.year, date.month, date.day, date.hour, m);
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: () => setState(() => _isCompleted = !_isCompleted),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: Text('完了', style: TextStyle(color: AppColors.textPrimary))),
            Switch(
              value: _isCompleted,
              activeColor: accentColor,
              onChanged: (value) => setState(() => _isCompleted = value),
            ),
          ],
        ),
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

// ─── インラインカレンダー用ヘルパーウィジェット ───────────────────────

class _TodoTimeWheelPicker extends StatefulWidget {
  final int value;
  final int maxValue;
  final Color textColor;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  const _TodoTimeWheelPicker({
    required this.value,
    required this.maxValue,
    required this.textColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_TodoTimeWheelPicker> createState() => _TodoTimeWheelPickerState();
}

class _TodoTimeWheelPickerState extends State<_TodoTimeWheelPicker> {
  late FixedExtentScrollController _scrollController;
  bool _isEditing = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(initialItem: widget.value);
    _textController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _TodoTimeWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _scrollController.jumpToItem(widget.value);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = widget.value.toString().padLeft(2, '0');
    });
    Future.microtask(() {
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  void _finishEditing() {
    final parsed = int.tryParse(_textController.text);
    if (parsed != null && parsed >= 0 && parsed <= widget.maxValue) {
      widget.onChanged(parsed);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return SizedBox(
        width: 56,
        height: 44,
        child: TextField(
          controller: _textController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: 2,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _TodoMaxValueFormatter(widget.maxValue),
          ],
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: widget.textColor),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.accentColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.accentColor, width: 2),
            ),
          ),
          onSubmitted: (_) => _finishEditing(),
          onTapOutside: (_) => _finishEditing(),
        ),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: SizedBox(
        width: 56,
        height: 120,
        child: Stack(
          children: [
            Center(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: _scrollController,
              itemExtent: 36,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.003,
              onSelectedItemChanged: widget.onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.maxValue + 1,
                builder: (context, index) {
                  final isSelected = index == widget.value;
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: isSelected ? 22 : 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? widget.textColor
                            : widget.textColor.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoMaxValueFormatter extends TextInputFormatter {
  final int maxValue;
  _TodoMaxValueFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final parsed = int.tryParse(newValue.text);
    if (parsed == null) return oldValue;
    if (parsed > maxValue) return oldValue;
    return newValue;
  }
}

class _TodoYearMonthSelector extends StatefulWidget {
  final int year;
  final int month;
  final Color textColor;
  final Color accentColor;
  final void Function(int year, int month) onChanged;

  const _TodoYearMonthSelector({
    required this.year,
    required this.month,
    required this.textColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_TodoYearMonthSelector> createState() => _TodoYearMonthSelectorState();
}

class _TodoYearMonthSelectorState extends State<_TodoYearMonthSelector> {
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  static const int _baseYear = 2020;
  static const int _yearCount = 10;

  @override
  void initState() {
    super.initState();
    _yearController = FixedExtentScrollController(initialItem: widget.year - _baseYear);
    _monthController = FixedExtentScrollController(initialItem: widget.month - 1);
  }

  @override
  void didUpdateWidget(covariant _TodoYearMonthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) {
      final idx = widget.year - _baseYear;
      if (idx >= 0 && idx < _yearCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _yearController.hasClients) _yearController.jumpToItem(idx);
        });
      }
    }
    if (oldWidget.month != widget.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _monthController.hasClients) _monthController.jumpToItem(widget.month - 1);
      });
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Stack(
      children: [
        Center(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 36,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.5,
          perspective: 0.003,
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final isSelected = index == selectedIndex;
              return Center(
                child: Text(
                  labelBuilder(index),
                  style: TextStyle(
                    fontSize: isSelected ? 18 : 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? widget.textColor : widget.textColor.withValues(alpha: 0.4),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _buildWheel(
              controller: _yearController,
              itemCount: _yearCount,
              labelBuilder: (i) => '${_baseYear + i}年',
              selectedIndex: widget.year - _baseYear,
              onChanged: (i) => widget.onChanged(_baseYear + i, widget.month),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildWheel(
              controller: _monthController,
              itemCount: 12,
              labelBuilder: (i) => '${i + 1}月',
              selectedIndex: widget.month - 1,
              onChanged: (i) => widget.onChanged(widget.year, i + 1),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
