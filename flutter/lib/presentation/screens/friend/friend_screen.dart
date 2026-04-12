import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
import '../../../data/models/friend_model.dart';
import 'friend_search_screen.dart';
import 'compatibility_screen.dart';
import 'friend_share_level_sheet.dart';

class FriendScreen extends ConsumerWidget {
  const FriendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final friendsAsync = ref.watch(friendsProvider);
    final requestsAsync = ref.watch(incomingFriendRequestsProvider);

    final pendingCount = requestsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'フレンド',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const Spacer(),
                    // 申請バッジ
                    if (pendingCount > 0)
                      GestureDetector(
                        onTap: () => _showRequestsSheet(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add, size: 16, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                '$pendingCount件の申請',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: accentColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FriendSearchScreen()),
                      ),
                      icon: Icon(Icons.person_search, color: accentColor),
                    ),
                  ],
                ),
              ),

              // フレンド一覧
              Expanded(
                child: friendsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('エラー: $e')),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return _EmptyFriendView(accentColor: accentColor);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        return _FriendCard(
                          friend: friends[index],
                          accentColor: accentColor,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FriendRequestsSheet(ref: ref),
    );
  }
}

/// フレンドカード
class _FriendCard extends ConsumerWidget {
  final FriendModel friend;
  final Color accentColor;

  const _FriendCard({required this.friend, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDocProvider);
    final myCharacterId = userAsync.valueOrNull?.characterId ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // アバター
            CircleAvatar(
              radius: 24,
              backgroundColor: accentColor.withValues(alpha: 0.15),
              child: Text(
                friend.name.isNotEmpty ? friend.name[0] : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 名前・メール
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name.isNotEmpty ? friend.name : '名前未設定',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),

            // アクションボタン群
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 共有設定
                _ShareLevelChip(
                  friend: friend,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 8),
                // 相性診断
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompatibilityScreen(
                        friend: friend,
                        myCharacterId: myCharacterId,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '相性診断',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 共有レベルチップ
class _ShareLevelChip extends ConsumerWidget {
  final FriendModel friend;
  final Color accentColor;

  const _ShareLevelChip({required this.friend, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = friend.shareLevel.label;
    final color = _levelColor(friend.shareLevel);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FriendShareLevelSheet(
            friend: friend,
            accentColor: accentColor,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _levelColor(FriendShareLevel level) {
    switch (level) {
      case FriendShareLevel.none:
        return AppColors.textLight;
      case FriendShareLevel.public:
        return Colors.blue;
      case FriendShareLevel.full:
        return Colors.green;
    }
  }
}

/// フレンドがいない時の表示
class _EmptyFriendView extends StatelessWidget {
  final Color accentColor;
  const _EmptyFriendView({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: accentColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'フレンドがまだいません',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '右上のボタンからフレンドを検索しましょう',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 申請一覧シート
class _FriendRequestsSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _FriendRequestsSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final gradient = widgetRef.watch(backgroundGradientProvider);
    final accentColor = widgetRef.watch(accentColorProvider);
    final requestsAsync = widgetRef.watch(incomingFriendRequestsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'フレンド申請',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(
                    child: Text(
                      '申請はありません',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: requests.length,
                  itemBuilder: (ctx, i) {
                    final req = requests[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: accentColor.withValues(alpha: 0.15),
                            child: Text(
                              req.fromUserName.isNotEmpty ? req.fromUserName[0] : '?',
                              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.fromUserName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  req.fromUserEmail,
                                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await widgetRef.read(friendControllerProvider.notifier).acceptFriendRequest(req);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: Text('承認', style: TextStyle(color: accentColor)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await widgetRef.read(friendControllerProvider.notifier).rejectFriendRequest(req.id);
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text('拒否', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
