import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memo_model.dart';
import '../../providers/memo_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../settings/tag_management_screen.dart';

/// メモ詳細・編集画面
class MemoDetailScreen extends ConsumerStatefulWidget {
  /// 編集対象のメモ（nullの場合は新規作成）
  final MemoModel? memo;

  const MemoDetailScreen({
    super.key,
    this.memo,
  });

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String _selectedTag = '';

  bool _isPinned = false;
  bool _isEditMode = true;
  bool _isSaving = false;

  bool get _isNewMemo => widget.memo == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _contentController =
        TextEditingController(text: widget.memo?.content ?? '');
    _selectedTag = widget.memo?.tag ?? '';

    if (widget.memo != null) {
      _isPinned = widget.memo!.isPinned;
      // 既存メモはプレビューモードで開始
      _isEditMode = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
          _isNewMemo ? '新規メモ' : 'メモ編集',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: _titleController.text.isEmpty || _isSaving
                  ? null
                  : _saveMemo,
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                    )
                  : Text('保存', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isEditMode = true),
              child: Text('編集', style: TextStyle(color: accentColor, fontWeight: FontWeight.w600)),
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
                // 上部バナー広告
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
                  readOnly: !_isEditMode,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // 内容（残りスペースを埋める）
                _buildSectionTitle('内容'),
                const SizedBox(height: 8),
                Expanded(
                  child: _isEditMode
                      ? _buildEditableContent(accentColor)
                      : _buildPreviewContent(),
                ),
                const SizedBox(height: 16),

                // タグ
                _buildSectionTitle('タグ'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isEditMode ? () => _showTagSelection(accentColor) : null,
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
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textLight,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ピン留め
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
                      Expanded(child: Text('ピン留め', style: TextStyle(color: AppColors.textPrimary))),
                      Switch(
                        value: _isPinned,
                        activeColor: accentColor,
                        onChanged: _isEditMode
                            ? (value) => setState(() => _isPinned = value)
                            : null,
                      ),
                    ],
                  ),
                ),

                // 削除ボタン（編集時のみ）
                if (!_isNewMemo) ...[
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

                // 下部バナー広告
                if (shouldShowBannerAd) ...[
                  const SizedBox(height: 24),
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
    bool readOnly = false,
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
        readOnly: readOnly,
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

  Widget _buildEditableContent(Color accentColor) {
    return Column(
      children: [
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
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '内容を入力',
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
        const SizedBox(height: 8),
        // マークダウンツールバー
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMarkdownButton(
                icon: Icons.format_bold,
                label: '太字',
                accentColor: accentColor,
                onPressed: () => _insertMarkdown('**', '太字'),
              ),
              _buildMarkdownButton(
                icon: Icons.format_list_bulleted,
                label: '箇条書き',
                accentColor: accentColor,
                onPressed: () => _insertMarkdown('- ', '', isPrefix: true),
              ),
              _buildMarkdownButton(
                icon: Icons.format_list_numbered,
                label: '番号',
                accentColor: accentColor,
                onPressed: () => _insertMarkdown('1. ', '', isPrefix: true),
              ),
              _buildMarkdownButton(
                icon: Icons.title,
                label: '見出し',
                accentColor: accentColor,
                onPressed: () => _insertMarkdown('# ', '', isPrefix: true),
              ),
              _buildMarkdownButton(
                icon: Icons.format_quote,
                label: '引用',
                accentColor: accentColor,
                onPressed: () => _insertMarkdown('> ', '', isPrefix: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownButton({
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _contentController.text.isEmpty
            ? Text(
                '内容がありません',
                style: TextStyle(color: AppColors.textLight),
              )
            : Text(
                _contentController.text,
                style: TextStyle(color: AppColors.textPrimary),
              ),
      ),
    );
  }

  void _insertMarkdown(String syntax, String placeholder, {bool isPrefix = false}) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    String newText;
    int newCursorPosition;

    if (isPrefix) {
      // プレフィックス型（箇条書き、見出しなど）
      final insertText = '\n$syntax$placeholder';
      newText = text.substring(0, selection.start) +
          insertText +
          text.substring(selection.end);
      newCursorPosition = selection.start + insertText.length;
    } else {
      // ラップ型（太字など）
      final insertText = '$syntax$placeholder$syntax';
      newText = text.substring(0, selection.start) +
          insertText +
          text.substring(selection.end);
      newCursorPosition = selection.start + syntax.length + placeholder.length;
    }

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  Future<void> _saveMemo() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      if (_isNewMemo) {
        // 新規作成
        final newMemo = MemoModel.create(
          title: _titleController.text,
          content: _contentController.text,
          tag: _selectedTag,
          isPinned: _isPinned,
        );
        await ref.read(memoControllerProvider.notifier).addMemo(newMemo);
      } else {
        // 更新
        final updatedMemo = widget.memo!.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          tag: _selectedTag,
          isPinned: _isPinned,
          updatedAt: DateTime.now(),
        );
        await ref.read(memoControllerProvider.notifier).updateMemo(updatedMemo);
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
                        isSelected: _selectedTag.isEmpty,
                        accentColor: accentColor,
                        onTap: () {
                          setState(() => _selectedTag = '');
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
                              isSelected: _selectedTag == tag.name,
                              accentColor: accentColor,
                              onTap: () {
                                setState(() => _selectedTag = tag.name);
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
            // タグ色
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
            // タグ名
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            // チェックマーク
            if (isSelected)
              Icon(Icons.check, color: accentColor, size: 20),
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
    if (widget.memo == null) return;

    try {
      await ref.read(memoControllerProvider.notifier).deleteMemo(widget.memo!.id);
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
