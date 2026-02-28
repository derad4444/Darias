import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../../data/models/post_model.dart';

/// 検索モードの状態
final chatSearchModeProvider = StateProvider<bool>((ref) => false);

/// 検索テキストの状態
final chatSearchTextProvider = StateProvider<String>((ref) => '');

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final user = ref.read(userDocProvider).valueOrNull;
    if (user == null) return;

    final characterId = user.characterId ?? '';
    if (characterId.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(chatControllerProvider.notifier).sendMessage(
        characterId: characterId,
        message: message,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final user = ref.watch(userDocProvider).valueOrNull;
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final isSearchMode = ref.watch(chatSearchModeProvider);
    final searchText = ref.watch(chatSearchTextProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (isSearchMode) {
              ref.read(chatSearchModeProvider.notifier).state = false;
              ref.read(chatSearchTextProvider.notifier).state = '';
              _searchController.clear();
            } else {
              context.go('/');
            }
          },
        ),
        title: isSearchMode
            ? _SearchBar(
                controller: _searchController,
                onChanged: (value) {
                  ref.read(chatSearchTextProvider.notifier).state = value;
                },
                onClear: () {
                  _searchController.clear();
                  ref.read(chatSearchTextProvider.notifier).state = '';
                },
              )
            : const Text(
                'チャット履歴',
                style: TextStyle(color: AppColors.textPrimary),
              ),
        actions: [
          if (!isSearchMode)
            IconButton(
              icon: Icon(Icons.search, color: accentColor),
              onPressed: () {
                ref.read(chatSearchModeProvider.notifier).state = true;
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // メッセージ一覧
              Expanded(
                child: userId == null || user?.characterId == null
                    ? Center(
                        child: Text(
                          'キャラクターを選択してください',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _buildChatList(user!.characterId!, searchText, accentColor),
              ),

              // 入力欄（検索モードでない場合のみ表示）
              if (!isSearchMode)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'メッセージを入力...',
                              hintStyle: TextStyle(color: AppColors.textLight),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : _sendMessage,
                          style: IconButton.styleFrom(
                            backgroundColor: accentColor,
                          ),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
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

  Widget _buildChatList(String characterId, String searchText, Color accentColor) {
    final chatHistoryAsync = ref.watch(chatHistoryProvider(characterId));

    return chatHistoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'エラーが発生しました: $error',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      data: (posts) {
        // 検索フィルター
        var filteredPosts = posts;
        if (searchText.isNotEmpty) {
          final query = searchText.toLowerCase();
          filteredPosts = posts.where((p) =>
              p.content.toLowerCase().contains(query) ||
              p.analysisResult.toLowerCase().contains(query)).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: AppColors.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'メッセージがありません',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '最初のメッセージを送ってみましょう',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (filteredPosts.isEmpty && searchText.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppColors.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  '検索結果がありません',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '「$searchText」に一致するメッセージが見つかりませんでした',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // 日付ごとにグループ化
        final groupedMessages = _groupMessagesByDate(filteredPosts);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: groupedMessages.length,
          itemBuilder: (context, index) {
            final item = groupedMessages[index];
            if (item is _DateHeader) {
              return _DateHeaderWidget(date: item.date);
            } else if (item is _ChatMessage) {
              return _ChatBubble(
                message: item.content,
                isUser: item.isUser,
                timestamp: item.timestamp,
                accentColor: accentColor,
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  List<dynamic> _groupMessagesByDate(List<PostModel> posts) {
    final result = <dynamic>[];
    DateTime? currentDate;

    for (final post in posts) {
      final postDate = DateTime(
        post.timestamp.year,
        post.timestamp.month,
        post.timestamp.day,
      );

      if (currentDate == null || currentDate != postDate) {
        currentDate = postDate;
        result.add(_DateHeader(date: postDate));
      }

      // ユーザーメッセージ
      result.add(_ChatMessage(
        content: post.content,
        isUser: true,
        timestamp: post.timestamp,
      ));

      // AI返答
      if (post.analysisResult.isNotEmpty) {
        result.add(_ChatMessage(
          content: post.analysisResult,
          isUser: false,
          timestamp: post.timestamp,
        ));
      }
    }

    return result;
  }
}

/// 検索バー
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'メッセージを検索',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.cancel,
                color: Colors.grey.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}

/// 日付ヘッダーデータ
class _DateHeader {
  final DateTime date;
  _DateHeader({required this.date});
}

/// 日付ヘッダーウィジェット
class _DateHeaderWidget extends StatelessWidget {
  final DateTime date;

  const _DateHeaderWidget({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.textLight.withValues(alpha: 0.3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.textLight.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今日';
    } else if (targetDate == yesterday) {
      return '昨日';
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }
}

/// チャットメッセージのデータクラス
class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final Color accentColor;

  const _ChatBubble({
    required this.message,
    required this.isUser,
    required this.timestamp,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.face, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: accentColor.withValues(alpha: 0.3),
              child: Icon(Icons.person, size: 20, color: accentColor),
            ),
          ],
        ],
      ),
    );
  }
}
