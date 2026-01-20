import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// チャットメッセージの送信者タイプ
enum MessageSender {
  user,
  character,
  system,
}

/// チャットバブルウィジェット
class ChatBubble extends StatelessWidget {
  final String message;
  final MessageSender sender;
  final DateTime? timestamp;
  final String? senderName;
  final String? senderAvatar;
  final bool showTimestamp;
  final bool isTyping;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.sender,
    this.timestamp,
    this.senderName,
    this.senderAvatar,
    this.showTimestamp = true,
    this.isTyping = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = sender == MessageSender.user;
    final isSystem = sender == MessageSender.system;
    final colorScheme = Theme.of(context).colorScheme;

    if (isSystem) {
      return _SystemMessage(message: message);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // キャラクターのアバター（左側）
          if (!isUser) ...[
            _Avatar(
              name: senderName,
              avatar: senderAvatar,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 8),
          ],

          // メッセージバブル
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 送信者名（キャラクターの場合）
                if (!isUser && senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      senderName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),

                // バブル本体
                GestureDetector(
                  onLongPress: onLongPress ?? () => _copyToClipboard(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                    ),
                    child: isTyping
                        ? _TypingIndicator(colorScheme: colorScheme)
                        : Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isUser
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                          ),
                  ),
                ),

                // タイムスタンプ
                if (showTimestamp && timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      _formatTime(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                    ),
                  ),
              ],
            ),
          ),

          // ユーザーのアバター（右側）
          if (isUser) ...[
            const SizedBox(width: 8),
            _Avatar(
              name: 'You',
              colorScheme: colorScheme,
              isUser: true,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('メッセージをコピーしました'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? name;
  final String? avatar;
  final ColorScheme colorScheme;
  final bool isUser;

  const _Avatar({
    this.name,
    this.avatar,
    required this.colorScheme,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? colorScheme.primaryContainer : colorScheme.secondaryContainer,
      backgroundImage: avatar != null ? NetworkImage(avatar!) : null,
      child: avatar == null
          ? Text(
              name?.isNotEmpty == true ? name![0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isUser
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
            )
          : null,
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;

  const _TypingIndicator({required this.colorScheme});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // アニメーションを順番に開始
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3 + (_animations[index].value * 0.7),
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

/// チャット入力フィールド
class ChatInputField extends StatefulWidget {
  final Function(String) onSend;
  final bool isEnabled;
  final String? placeholder;

  const ChatInputField({
    super.key,
    required this.onSend,
    this.isEnabled = true,
    this.placeholder,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.isEnabled) return;

    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.isEnabled,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: widget.placeholder ?? 'メッセージを入力...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onChanged: (text) {
                  setState(() => _hasText = text.trim().isNotEmpty);
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                onPressed: (_hasText && widget.isEnabled) ? _sendMessage : null,
                icon: Icon(
                  Icons.send,
                  color: (_hasText && widget.isEnabled)
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: (_hasText && widget.isEnabled)
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
