import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo_model.dart';
import '../../../utils/memo_content_utils.dart';
import '../../providers/memo_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ad_provider.dart';
import '../../providers/todo_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../../data/models/todo_model.dart';
import '../../../data/services/ad_service.dart';
import '../settings/tag_management_screen.dart';

/// メモ詳細・編集画面
class MemoDetailScreen extends ConsumerStatefulWidget {
  final MemoModel? memo;
  final String initialTag;

  const MemoDetailScreen({
    super.key,
    this.memo,
    this.initialTag = '',
  });

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;

  String _selectedTag = '';
  bool _isPinned = false;
  bool _showInWidget = false;
  bool _isSaving = false;
  bool _isDisposed = false;
  int _taskCount = 0;

  /// Quill本文からタスクタイトル一覧を抽出（行頭にtaskIconエンベッドがある行を対象）
  List<String> _extractTaskTitles() {
    final ops = _quillController.document.toDelta().operations;
    final tasks = <String>[];
    final lineBuffer = StringBuffer();
    bool lineHasTaskIcon = false;
    bool isLineStart = true;

    for (final op in ops) {
      if (!op.isInsert) continue;
      final data = op.data;

      if (data is Map && (data as Map).containsKey('taskIcon')) {
        if (isLineStart) lineHasTaskIcon = true;
        isLineStart = false;
      } else if (data is String) {
        for (final ch in data.split('')) {
          if (ch == '\n') {
            if (lineHasTaskIcon) {
              final title = lineBuffer.toString().trim();
              if (title.isNotEmpty) tasks.add(title);
            }
            lineBuffer.clear();
            lineHasTaskIcon = false;
            isLineStart = true;
          } else {
            lineBuffer.write(ch);
            isLineStart = false;
          }
        }
      }
    }
    return tasks;
  }

  /// 自動保存用タイマー
  Timer? _debounceTimer;

  /// 新規作成後に保存済みメモを追跡（ID取得のため）
  MemoModel? _savedMemo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _quillController = buildQuillController(widget.memo?.content ?? '');
    _editorFocusNode = FocusNode();
    _editorScrollController = ScrollController();
    _selectedTag = widget.memo?.tag ?? widget.initialTag;

    if (widget.memo != null) {
      _isPinned = widget.memo!.isPinned;
      _showInWidget = widget.memo!.showInWidget;
    }

    // 変更を検知して自動保存スケジュール
    _titleController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);

    // 初期タスク数
    _taskCount = _extractTaskTitles().length;
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    // 画面離脱時に未保存の変更を即時保存（setState は呼ばれない）
    _saveNow();
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  /// アプリがバックグラウンドに入ったときに保存
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _debounceTimer?.cancel();
      _saveNow();
    }
  }

  void _onContentChanged() {
    _scheduleSave();
    final count = _extractTaskTitles().length;
    if (count != _taskCount) {
      setState(() => _taskCount = count);
    }
  }

  /// 2秒後に自動保存（入力が続く間はリセット）
  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _saveNow);
  }

  /// 即時保存（画面離脱・バックグラウンド時に呼ぶ）
  void _saveNow() {
    _debounceTimer?.cancel();
    if (_titleController.text.isNotEmpty) {
      _persistMemo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _debounceTimer?.cancel();
          _saveNow();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            widget.memo == null && _savedMemo == null ? '新規メモ' : 'メモ編集',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            _isSaving
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                    ),
                  )
                : TextButton(
                    onPressed: _titleController.text.isEmpty ? null : _saveAndPop,
                    child: Text('保存', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
                  ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // タイトル・内容ラベル
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (shouldShowBannerAd) ...[
                        BannerAdContainer(adUnitId: AdConfig.memoAddTopBannerAdUnitId),
                        const SizedBox(height: 16),
                      ],
                      _buildSectionTitle('タイトル'),
                      const SizedBox(height: 8),
                      _buildTitleField(accentColor),
                      const SizedBox(height: 16),
                      _buildSectionTitle('内容'),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
                // 内容欄＋下部項目（スクロール可能・常に表示）
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // エディタ（コンテンツ高さで伸縮・最低200px）
                        _buildEditorArea(accentColor),
                        const SizedBox(height: 16),
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
                                if (_selectedTag.isNotEmpty) ...[
                                  Builder(builder: (context) {
                                    final tags = ref.watch(tagsProvider);
                                    final tagItem = tags.where((t) => t.name == _selectedTag).firstOrNull;
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
                                  child: Text(
                                    _selectedTag.isEmpty ? 'タグを選択' : _selectedTag,
                                    style: TextStyle(
                                      color: _selectedTag.isEmpty ? AppColors.textLight : AppColors.textPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, color: AppColors.textLight),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                color: _isPinned ? accentColor : AppColors.textLight,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ピン留め', style: TextStyle(color: AppColors.textPrimary)),
                                    Text(
                                      'メモ一覧の上部に固定します',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isPinned,
                                activeTrackColor: accentColor,
                                onChanged: (value) {
                                  setState(() => _isPinned = value);
                                  _saveNow();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.widgets_outlined,
                                color: _showInWidget ? accentColor : AppColors.textLight,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ウィジェットに表示', style: TextStyle(color: AppColors.textPrimary)),
                                    Text(
                                      'ホーム画面のメモウィジェットに表示',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _showInWidget,
                                activeTrackColor: accentColor,
                                onChanged: (value) {
                                  setState(() => _showInWidget = value);
                                  _saveNow();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _taskCount > 0 ? () => _showTaskRegistrationSheet(accentColor) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _taskCount > 0
                                  ? accentColor.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _taskCount > 0
                                    ? accentColor.withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.checklist_rounded,
                                        color: _taskCount > 0 ? accentColor : Colors.grey[400], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _taskCount > 0 ? 'タスクに登録（$_taskCount件）' : 'タスクに登録',
                                      style: TextStyle(
                                        color: _taskCount > 0 ? accentColor : Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: _taskCount > 0
                                          ? accentColor.withValues(alpha: 0.65)
                                          : Colors.grey[400],
                                      fontSize: 11,
                                    ),
                                    children: [
                                      const TextSpan(text: 'タスクアイコン（'),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Icon(Icons.task_alt, size: 12,
                                            color: _taskCount > 0
                                                ? accentColor.withValues(alpha: 0.65)
                                                : Colors.grey[400]),
                                      ),
                                      const TextSpan(text: '）付きの行をタスクに登録します'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.memo != null || _savedMemo != null) ...[
                          const SizedBox(height: 8),
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
                                  Text('メモを削除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (shouldShowBannerAd) ...[
                          const SizedBox(height: 16),
                          BannerAdContainer(adUnitId: AdConfig.memoAddBottomBannerAdUnitId),
                        ],
                      ],
                    ),
                  ),
                ),
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
      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
  }

  Widget _buildTitleField(Color accentColor) {
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
        controller: _titleController,
        maxLines: 1,
        decoration: InputDecoration(
          hintText: 'タイトルを入力',
          hintStyle: TextStyle(color: AppColors.textLight),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildEditorArea(Color accentColor) {
    // コンテンツ高さで伸縮するコンテナ（最低200px）
    // ページ全体のCustomScrollViewがスクロールを担当するため scrollable: false
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MemoToolbar(controller: _quillController, accentColor: accentColor),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: QuillEditor(
              controller: _quillController,
              focusNode: _editorFocusNode,
              scrollController: _editorScrollController,
              config: const QuillEditorConfig(
                placeholder: '内容を入力',
                padding: EdgeInsets.all(12),
                expands: false,
                scrollable: false,
                embedBuilders: [_TaskIconEmbedBuilder()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Firestore に保存（画面遷移なし）
  Future<void> _persistMemo() async {
    if (_titleController.text.isEmpty) return;
    if (_isSaving) return;

    // mounted/disposed に関わらずフラグをセット（並行保存防止）
    _isSaving = true;
    if (!_isDisposed && mounted) setState(() {});

    try {
      final contentJson = jsonEncode(
        _quillController.document.toDelta().toJson(),
      );

      final existingMemo = (widget.memo != null && widget.memo!.id.isNotEmpty) ? widget.memo : _savedMemo;
      if (existingMemo == null) {
        // 新規作成
        final newMemo = MemoModel.create(
          title: _titleController.text,
          content: contentJson,
          tag: _selectedTag,
          isPinned: _isPinned,
          showInWidget: _showInWidget,
        );
        final id = await ref.read(memoControllerProvider.notifier).addMemo(newMemo);
        if (id != null && !_isDisposed) {
          _savedMemo = newMemo.copyWith(
            id: id,
            content: contentJson,
          );
        }
      } else {
        // 更新
        await ref.read(memoControllerProvider.notifier).updateMemo(
          existingMemo.copyWith(
            title: _titleController.text,
            content: contentJson,
            tag: _selectedTag,
            isPinned: _isPinned,
            showInWidget: _showInWidget,
            updatedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔴 メモ自動保存エラー: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自動保存に失敗しました: $e')),
        );
      }
    } finally {
      _isSaving = false;
      if (!_isDisposed && mounted) setState(() {});
    }
  }

  /// 手動保存ボタン：保存後に画面を閉じる
  Future<void> _saveAndPop() async {
    _debounceTimer?.cancel();
    await _persistMemo();
    if (mounted) context.pop();
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
              Expanded(
                child: Consumer(builder: (context, ref, _) {
                  final tags = ref.watch(tagsProvider);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTagOption(
                        sheetContext: sheetContext,
                        name: 'タグなし',
                        color: null,
                        isSelected: _selectedTag.isEmpty,
                        accentColor: accentColor,
                        onTap: () {
                          setState(() => _selectedTag = '');
                          Navigator.pop(sheetContext);
                          _saveNow();
                        },
                      ),
                      const SizedBox(height: 8),
                      ...tags.map((tag) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTagOption(
                              sheetContext: sheetContext,
                              name: tag.name,
                              color: tag.color,
                              isSelected: _selectedTag == tag.name,
                              accentColor: accentColor,
                              onTap: () {
                                setState(() => _selectedTag = tag.name);
                                Navigator.pop(sheetContext);
                                _saveNow();
                              },
                            ),
                          )),
                      const SizedBox(height: 16),
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
            if (isSelected) Icon(Icons.check, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('メモを削除'),
        content: const Text('このメモを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemo();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMemo() async {
    final target = widget.memo ?? _savedMemo;
    if (target == null) return;

    try {
      await ref.read(memoControllerProvider.notifier).deleteMemo(target.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  void _showTaskRegistrationSheet(Color accentColor) {
    final tasks = _extractTaskTitles();
    if (tasks.isEmpty) return;

    final backgroundGradient = ref.read(backgroundGradientProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskRegistrationSheet(
        tasks: tasks,
        accentColor: accentColor,
        backgroundGradient: backgroundGradient,
        onRegister: (selected) async {
          Navigator.pop(ctx);
          await _registerTasks(selected);
        },
      ),
    );
  }

  Future<void> _registerTasks(List<String> titles) async {
    int count = 0;
    for (final title in titles) {
      try {
        await ref.read(todoControllerProvider.notifier).addTodo(
          TodoModel.create(title: title),
        );
        count++;
      } catch (e) {
        debugPrint('タスク登録エラー: $e');
      }
    }
    if (mounted && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count件のタスクを登録しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────
// カスタムツールバー
// ─────────────────────────────────────────

class _MemoToolbar extends StatefulWidget {
  final QuillController controller;
  final Color accentColor;

  const _MemoToolbar({required this.controller, required this.accentColor});

  @override
  State<_MemoToolbar> createState() => _MemoToolbarState();
}

class _MemoToolbarState extends State<_MemoToolbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // ── アクティブ判定 ──

  bool _isInline(Attribute attr) {
    final a = widget.controller.getSelectionStyle().attributes[attr.key];
    return a != null && a.value != null;
  }

  bool _isHeader(int level) {
    final a = widget.controller.getSelectionStyle().attributes[Attribute.header.key];
    return a?.value == level;
  }

  bool _isList(String type) {
    final a = widget.controller.getSelectionStyle().attributes[Attribute.list.key];
    return a?.value == type;
  }

  bool _isBlockQuote() =>
      widget.controller.getSelectionStyle().attributes.containsKey(Attribute.blockQuote.key);

  bool _isTaskLine() {
    final controller = widget.controller;
    final cursorPos = controller.selection.baseOffset;
    if (cursorPos < 0) return false;
    final plainText = controller.document.toPlainText();
    if (plainText.isEmpty) return false;
    final safePos = cursorPos.clamp(0, plainText.length);
    final lineStart = safePos > 0 ? plainText.lastIndexOf('\n', safePos - 1) + 1 : 0;
    int offset = 0;
    for (final op in controller.document.toDelta().operations) {
      if (!op.isInsert) continue;
      if (offset == lineStart) {
        return op.data is Map && (op.data as Map).containsKey('taskIcon');
      }
      if (offset > lineStart) break;
      offset += op.length ?? 0;
    }
    return false;
  }

  String? _currentColor() =>
      widget.controller.getSelectionStyle().attributes[Attribute.color.key]?.value as String?;

  // ── トグル操作 ──

  void _toggleInline(Attribute attr) {
    widget.controller.formatSelection(
      _isInline(attr) ? Attribute.clone(attr, null) : attr,
    );
  }

  void _toggleHeader(int level) {
    widget.controller.formatSelection(
      _isHeader(level) ? Attribute.clone(Attribute.header, null) : HeaderAttribute(level: level),
    );
  }

  void _toggleList(Attribute attr, String type) {
    widget.controller.formatSelection(
      _isList(type) ? Attribute.clone(Attribute.list, null) : attr,
    );
  }

  void _toggleBlockQuote() {
    widget.controller.formatSelection(
      _isBlockQuote() ? Attribute.clone(Attribute.blockQuote, null) : Attribute.blockQuote,
    );
  }

  void _toggleTaskLine() {
    final controller = widget.controller;
    final cursorPos = controller.selection.baseOffset;
    if (cursorPos < 0) return;
    final plainText = controller.document.toPlainText();
    final safePos = plainText.isEmpty ? 0 : cursorPos.clamp(0, plainText.length);
    final lineStart = safePos > 0 ? plainText.lastIndexOf('\n', safePos - 1) + 1 : 0;
    if (_isTaskLine()) {
      controller.replaceText(lineStart, 1, '', null);
    } else {
      controller.replaceText(lineStart, 0, Embeddable('taskIcon', ''), null);
      // embedの直後にカーソルを移動
      controller.updateSelection(
        TextSelection.collapsed(offset: lineStart + 1),
        ChangeSource.local,
      );
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPaletteSheet(
        currentHex: _currentColor(),
        accentColor: widget.accentColor,
        onSelected: (hex) {
          widget.controller.formatSelection(
            hex == null
                ? Attribute.clone(Attribute.color, null)
                : ColorAttribute(hex),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            _Btn(icon: Icons.looks_one_rounded,    isActive: _isHeader(1),           ac: ac, onTap: () => _toggleHeader(1)),
            _Btn(icon: Icons.looks_two_rounded,    isActive: _isHeader(2),           ac: ac, onTap: () => _toggleHeader(2)),
            const _Divider(),
            _Btn(icon: Icons.format_bold,          isActive: _isInline(Attribute.bold),        ac: ac, onTap: () => _toggleInline(Attribute.bold)),
            _Btn(icon: Icons.format_italic,        isActive: _isInline(Attribute.italic),      ac: ac, onTap: () => _toggleInline(Attribute.italic)),
            _Btn(icon: Icons.format_underline,     isActive: _isInline(Attribute.underline),   ac: ac, onTap: () => _toggleInline(Attribute.underline)),
            _Btn(icon: Icons.format_strikethrough, isActive: _isInline(Attribute.strikeThrough), ac: ac, onTap: () => _toggleInline(Attribute.strikeThrough)),
            const _Divider(),
            _Btn(icon: Icons.format_list_bulleted, isActive: _isList('bullet'),  ac: ac, onTap: () => _toggleList(Attribute.ul, 'bullet')),
            _Btn(icon: Icons.format_list_numbered, isActive: _isList('ordered'), ac: ac, onTap: () => _toggleList(Attribute.ol, 'ordered')),
            _TextBtn(label: 'タスク', isActive: _isTaskLine(), ac: ac, onTap: _toggleTaskLine),
            _Btn(icon: Icons.format_quote,         isActive: _isBlockQuote(),    ac: ac, onTap: _toggleBlockQuote),
            const _Divider(),
            _ColorBtn(currentHex: _currentColor(), ac: ac, onTap: _showColorPicker),
            const _Divider(),
            _Btn(icon: Icons.undo, isActive: false, ac: ac,
              onTap: widget.controller.hasUndo ? widget.controller.undo : null),
            _Btn(icon: Icons.redo, isActive: false, ac: ac,
              onTap: widget.controller.hasRedo ? widget.controller.redo : null),
          ],
        ),
      ),
    );
  }
}

// ── ツールバーパーツ ──

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color ac;
  final VoidCallback? onTap;

  const _Btn({required this.icon, required this.isActive, required this.ac, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? ac.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18,
          color: onTap == null
              ? Colors.grey.withValues(alpha: 0.35)
              : isActive ? ac : Colors.grey[600]),
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color ac;
  final VoidCallback? onTap;

  const _TextBtn({required this.label, required this.isActive, required this.ac, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? ac.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? Colors.grey.withValues(alpha: 0.35)
                : isActive ? ac : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

/// タスクアイコンのインラインEmbedビルダー
class _TaskIconEmbedBuilder extends EmbedBuilder {
  const _TaskIconEmbedBuilder();

  @override
  String get key => 'taskIcon';

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Padding(
      padding: const EdgeInsets.only(right: 3, bottom: 1),
      child: Icon(Icons.task_alt, size: 13, color: Colors.grey[600]),
    );
  }
}

class _ColorBtn extends StatelessWidget {
  final String? currentHex;
  final Color ac;
  final VoidCallback onTap;

  const _ColorBtn({required this.currentHex, required this.ac, required this.onTap});

  Color get _dotColor {
    if (currentHex == null) return Colors.black;
    try {
      return Color(int.parse('FF${currentHex!.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_color_text, size: 16, color: Colors.grey[600]),
            const SizedBox(height: 2),
            Container(
              width: 16, height: 3,
              decoration: BoxDecoration(
                color: _dotColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withValues(alpha: 0.25),
    );
  }
}

// ─────────────────────────────────────────
// タスク登録 確認シート
// ─────────────────────────────────────────

class _TaskRegistrationSheet extends StatefulWidget {
  final List<String> tasks;
  final Color accentColor;
  final Gradient backgroundGradient;
  final void Function(List<String> selected) onRegister;

  const _TaskRegistrationSheet({
    required this.tasks,
    required this.accentColor,
    required this.backgroundGradient,
    required this.onRegister,
  });

  @override
  State<_TaskRegistrationSheet> createState() => _TaskRegistrationSheetState();
}

class _TaskRegistrationSheetState extends State<_TaskRegistrationSheet> {
  late List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.tasks.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _checked.where((c) => c).length;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: widget.backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'タスクに登録',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'メモ内のタスク行をToDoに登録します',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          ...List.generate(widget.tasks.length, (i) {
            return CheckboxListTile(
              value: _checked[i],
              onChanged: (v) => setState(() => _checked[i] = v ?? false),
              title: Text(widget.tasks[i], style: const TextStyle(fontSize: 15)),
              activeColor: widget.accentColor,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      final selected = [
                        for (int i = 0; i < widget.tasks.length; i++)
                          if (_checked[i]) widget.tasks[i],
                      ];
                      widget.onRegister(selected);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                selectedCount > 0 ? '$selectedCount件を登録する' : '登録する',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// カラーパレット ボトムシート
// ─────────────────────────────────────────

class _ColorPaletteSheet extends StatelessWidget {
  final String? currentHex;
  final Color accentColor;
  final void Function(String?) onSelected;

  const _ColorPaletteSheet({
    required this.currentHex,
    required this.accentColor,
    required this.onSelected,
  });

  static const _palette = [
    ('黒',     '#000000', Color(0xFF000000)),
    ('グレー',  '#757575', Color(0xFF757575)),
    ('赤',     '#E53935', Color(0xFFE53935)),
    ('オレンジ','#F4511E', Color(0xFFF4511E)),
    ('黄',     '#F6BF26', Color(0xFFF6BF26)),
    ('緑',     '#33B679', Color(0xFF33B679)),
    ('水色',   '#039BE5', Color(0xFF039BE5)),
    ('青',     '#4285F4', Color(0xFF4285F4)),
    ('紫',     '#7986CB', Color(0xFF7986CB)),
    ('ピンク',  '#E67C73', Color(0xFFE67C73)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('テキストカラー',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // 色なし
              GestureDetector(
                onTap: () => onSelected(null),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    color: currentHex == null ? accentColor.withValues(alpha: 0.1) : null,
                  ),
                  child: Icon(Icons.format_color_reset, size: 20,
                      color: currentHex == null ? accentColor : Colors.grey),
                ),
              ),
              ..._palette.map((c) {
                final isSelected = currentHex == c.$2;
                return GestureDetector(
                  onTap: () => onSelected(c.$2),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: c.$3,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: accentColor, width: 3)
                          : Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
