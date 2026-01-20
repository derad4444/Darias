import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/memo_model.dart';
import '../../providers/memo_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

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
  late final TextEditingController _tagController;

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
    _tagController = TextEditingController(text: widget.memo?.tag ?? '');

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
    _tagController.dispose();
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
        title: Text(_isNewMemo ? '新規メモ' : 'メモ編集'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: _titleController.text.isEmpty || _isSaving
                  ? null
                  : _saveMemo,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isEditMode = true),
              child: const Text('編集'),
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
              readOnly: !_isEditMode,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 内容
            _buildSectionTitle('内容'),
            const SizedBox(height: 8),
            if (_isEditMode)
              _buildEditableContent(colorScheme)
            else
              _buildPreviewContent(colorScheme),
            const SizedBox(height: 16),

            // タグ
            _buildSectionTitle('タグ'),
            const SizedBox(height: 8),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                hintText: 'タグを入力（任意）',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              readOnly: !_isEditMode,
            ),
            const SizedBox(height: 16),

            // ピン留め
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: _isPinned ? colorScheme.primary : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('ピン留め')),
                  Switch(
                    value: _isPinned,
                    onChanged: _isEditMode
                        ? (value) => setState(() => _isPinned = value)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 削除ボタン（編集時のみ）
            if (!_isNewMemo) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'メモを削除',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.red),
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

  Widget _buildEditableContent(ColorScheme colorScheme) {
    return Column(
      children: [
        TextField(
          controller: _contentController,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: '内容を入力',
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
                onPressed: () => _insertMarkdown('**', '太字'),
              ),
              _buildMarkdownButton(
                icon: Icons.format_list_bulleted,
                label: '箇条書き',
                onPressed: () => _insertMarkdown('- ', '', isPrefix: true),
              ),
              _buildMarkdownButton(
                icon: Icons.format_list_numbered,
                label: '番号',
                onPressed: () => _insertMarkdown('1. ', '', isPrefix: true),
              ),
              _buildMarkdownButton(
                icon: Icons.title,
                label: '見出し',
                onPressed: () => _insertMarkdown('# ', '', isPrefix: true),
              ),
              _buildMarkdownButton(
                icon: Icons.format_quote,
                label: '引用',
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
            color: Theme.of(context).colorScheme.primary,
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

  Widget _buildPreviewContent(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _contentController.text.isEmpty
          ? Text(
              '内容がありません',
              style: TextStyle(color: Colors.grey[500]),
            )
          : Text(
              _contentController.text,
              style: Theme.of(context).textTheme.bodyMedium,
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
          tag: _tagController.text,
          isPinned: _isPinned,
        );
        await ref.read(memoControllerProvider.notifier).addMemo(newMemo);
      } else {
        // 更新
        final updatedMemo = widget.memo!.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          tag: _tagController.text,
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
