import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/friend_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
import 'compatibility_category_screen.dart' show CompatibilityChatBubble;

/// 「フレンドのことを聞く」履歴一覧画面
class FriendAskHistoryScreen extends ConsumerWidget {
  final FriendModel friend;

  const FriendAskHistoryScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final friendName = friend.name.isNotEmpty ? friend.name : 'フレンド';
    final historyAsync = ref.watch(askHistoryProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: accentColor),
        ),
        title: Text(
          '$friendNameへの質問履歴',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: historyAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: accentColor)),
            error: (e, _) => const Center(child: Text('履歴の取得に失敗しました')),
            data: (allHistory) {
              // このフレンドの履歴のみフィルタリング
              final history = allHistory
                  .where((e) => e.friendId == friend.id)
                  .toList();

              if (history.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 48, color: accentColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'まだ質問履歴がありません',
                        style: TextStyle(fontSize: 14, color: accentColor.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  return _HistoryCard(
                    entry: history[index],
                    friend: friend,
                    accentColor: accentColor,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerStatefulWidget {
  final AskHistoryEntry entry;
  final FriendModel friend;
  final Color accentColor;

  const _HistoryCard({
    required this.entry,
    required this.friend,
    required this.accentColor,
  });

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accentColor = widget.accentColor;
    final dateStr = DateFormat('M/d HH:mm').format(entry.createdAt);
    final myUserId = ref.watch(currentUserIdProvider) ?? '';
    final myName = ref.watch(userDocProvider).valueOrNull?.name ?? '自分';
    final friendName = widget.friend.name.isNotEmpty ? widget.friend.name : 'フレンド';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー（質問 + 日時）
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.question,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: accentColor.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // おすすめ（常に表示）
          if (entry.recommendation.isNotEmpty) ...[
            Divider(height: 1, color: accentColor.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.recommendation,
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor.withValues(alpha: 0.85),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 会話詳細（展開時）
          if (_expanded && entry.conversation.isNotEmpty) ...[
            Divider(height: 1, color: accentColor.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: entry.conversation
                    .map((msg) => CompatibilityChatBubble(
                          message: msg,
                          myUserId: myUserId,
                          friendUserId: widget.friend.id,
                          myName: myName,
                          friendName: friendName,
                          accentColor: accentColor,
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
