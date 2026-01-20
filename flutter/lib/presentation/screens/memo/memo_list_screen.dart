import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/memo_model.dart';
import '../../providers/memo_provider.dart';

class MemoListScreen extends ConsumerWidget {
  const MemoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('メモ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: memosAsync.when(
        data: (memos) => memos.isEmpty
            ? _EmptyState()
            : _MemoList(memos: memos),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/memo/detail'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 空状態
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'メモがありません',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
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

/// メモリスト
class _MemoList extends ConsumerWidget {
  final List<MemoModel> memos;

  const _MemoList({required this.memos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: memos.length,
      itemBuilder: (context, index) {
        final memo = memos[index];
        return _MemoCard(memo: memo);
      },
    );
  }
}

/// メモカード
class _MemoCard extends ConsumerWidget {
  final MemoModel memo;

  const _MemoCard({required this.memo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMemoEditor(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  if (memo.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      memo.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // ピン留めボタン
                  IconButton(
                    icon: Icon(
                      memo.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      ref.read(memoControllerProvider.notifier).togglePin(
                        memo.id,
                        !memo.isPinned,
                      );
                    },
                  ),
                ],
              ),

              // 内容プレビュー
              if (memo.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  memo.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // タグ（あれば）
              if (memo.tag.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    memo.tag,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],

              // 更新日時
              const SizedBox(height: 8),
              Text(
                '更新: ${_formatDate(memo.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMemoEditor(BuildContext context, WidgetRef ref) {
    context.push('/memo/detail', extra: memo);
  }
}

/// メモ編集シート
class _MemoEditSheet extends ConsumerStatefulWidget {
  final MemoModel? memo;

  const _MemoEditSheet({this.memo});

  @override
  ConsumerState<_MemoEditSheet> createState() => _MemoEditSheetState();
}

class _MemoEditSheetState extends ConsumerState<_MemoEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late bool _isPinned;

  bool get isEditing => widget.memo != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _contentController = TextEditingController(text: widget.memo?.content ?? '');
    _tagController = TextEditingController(text: widget.memo?.tag ?? '');
    _isPinned = widget.memo?.isPinned ?? false;
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'メモを編集' : '新しいメモ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteMemo,
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

            // 内容
            Flexible(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                minLines: 5,
                expands: false,
              ),
            ),
            const SizedBox(height: 16),

            // タグ
            TextField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: 'タグ（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ピン留め
            SwitchListTile(
              title: const Text('ピン留め'),
              secondary: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              value: _isPinned,
              onChanged: (value) => setState(() => _isPinned = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // 保存ボタン
            FilledButton(
              onPressed: _saveMemo,
              child: Text(isEditing ? '更新' : '追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMemo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    try {
      if (isEditing) {
        await ref.read(memoControllerProvider.notifier).updateMemo(
          widget.memo!.copyWith(
            title: title,
            content: _contentController.text.trim(),
            tag: _tagController.text.trim(),
            isPinned: _isPinned,
          ),
        );
      } else {
        await ref.read(memoControllerProvider.notifier).addMemo(
          MemoModel.create(
            title: title,
            content: _contentController.text.trim(),
            tag: _tagController.text.trim(),
            isPinned: _isPinned,
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

  Future<void> _deleteMemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このメモを削除しますか？'),
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

    if (confirmed == true && widget.memo != null) {
      try {
        await ref.read(memoControllerProvider.notifier).deleteMemo(
          widget.memo!.id,
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
