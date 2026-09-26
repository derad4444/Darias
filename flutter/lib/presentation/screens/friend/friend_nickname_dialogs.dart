import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_model.dart';
import '../../providers/friend_provider.dart';

/// フレンドのあだ名を付ける・変更するダイアログを開く
///
/// 保存はダイアログの中で行い、保存中は入力もボタンも受け付けない（二重に保存したり、
/// 保存の途中でダイアログを閉じたりしないようにするため）。
/// 保存できたら true を返す（キャンセル・変更なしは false）。
Future<bool> showFriendNicknameEditor(BuildContext context, FriendModel friend) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NicknameEditDialog(friend: friend),
  );
  return saved ?? false;
}

/// あだ名を削除する確認ダイアログを開く（削除できたら true）
Future<bool> confirmDeleteFriendNickname(BuildContext context, FriendModel friend) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NicknameDeleteDialog(friend: friend),
  );
  return deleted ?? false;
}

/// あだ名の入力ダイアログ
///
/// 入力欄のコントローラーはダイアログ自身が持ち、ダイアログが画面から消えたときに
/// 破棄する（呼び出し側で showDialog の直後に破棄すると、閉じるアニメーションの
/// 途中でまだ使われていてエラーになる）。
class _NicknameEditDialog extends ConsumerStatefulWidget {
  final FriendModel friend;

  const _NicknameEditDialog({required this.friend});

  @override
  ConsumerState<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends ConsumerState<_NicknameEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.friend.nickname);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value == widget.friend.nickname) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref.read(friendControllerProvider.notifier).setFriendNickname(
          friendId: widget.friend.id,
          nickname: value,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = 'あだ名を保存できませんでした。通信状況を確認してもう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.friend.hasNickname ? 'あだ名を変更' : 'あだ名を付ける'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              enabled: !_saving,
              autofocus: true,
              maxLength: kFriendNicknameMaxLength,
              decoration: InputDecoration(
                hintText: widget.friend.name.isNotEmpty ? widget.friend.name : 'あだ名',
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            const SizedBox(height: 4),
            Text(
              'あだ名はあなたにだけ表示されます。相手や他の人には表示されません。',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// あだ名の削除確認ダイアログ（削除中は操作を受け付けない）
class _NicknameDeleteDialog extends ConsumerStatefulWidget {
  final FriendModel friend;

  const _NicknameDeleteDialog({required this.friend});

  @override
  ConsumerState<_NicknameDeleteDialog> createState() => _NicknameDeleteDialogState();
}

class _NicknameDeleteDialogState extends ConsumerState<_NicknameDeleteDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    final ok = await ref.read(friendControllerProvider.notifier).setFriendNickname(
          friendId: widget.friend.id,
          nickname: '',
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _deleting = false;
        _error = 'あだ名を削除できませんでした。通信状況を確認してもう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountName = widget.friend.name.isNotEmpty ? widget.friend.name : 'アカウント名';
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('あだ名を削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${widget.friend.nickname}」を削除して、「$accountName」の表示に戻しますか？'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: _deleting ? null : _delete,
            child: _deleting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
