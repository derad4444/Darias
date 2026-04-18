import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/services/hint_service.dart';
import '../../widgets/character_avatar_widget.dart';
import '../../widgets/inline_hint_banner.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
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
                    // フレンド検索・申請管理ボタン
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FriendSearchScreen()),
                      ),
                      icon: Icon(Icons.person_search, color: accentColor),
                      tooltip: 'フレンドを追加',
                    ),
                  ],
                ),
              ),

              // フレンドヒントバナー（初回のみ）
              InlineHintBanner(
                userId: ref.watch(currentUserIdProvider) ?? '',
                feature: HintService.kFriend,
                message: 'フレンドごとに予定の共有レベルを設定できます：非公開・公開（公開設定の予定のみ）・全公開（すべて）。フレンドカードの設定ボタンから変更できます。',
                icon: Icons.people_outline,
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

}

/// フレンドカード
class _FriendCard extends ConsumerWidget {
  final FriendModel friend;
  final Color accentColor;

  const _FriendCard({required this.friend, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            CharacterAvatarWidget(
              userId: friend.id,
              size: 48,
              fallbackText: friend.name.isNotEmpty ? friend.name[0] : '?',
              fallbackBackgroundColor: accentColor.withValues(alpha: 0.15),
              fallbackTextColor: accentColor,
            ),
            const SizedBox(width: 12),
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
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShareLevelChip(friend: friend, accentColor: accentColor),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompatibilityScreen(
                        friend: friend,
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
    final color = _levelColor(friend.shareLevel);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FriendShareLevelSheet(
          friend: friend,
          accentColor: accentColor,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          friend.shareLevel.label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Color _levelColor(FriendShareLevel level) {
    switch (level) {
      case FriendShareLevel.none:   return AppColors.textLight;
      case FriendShareLevel.public: return Colors.blue;
      case FriendShareLevel.full:   return Colors.green;
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
          Text('フレンドがまだいません',
              style: TextStyle(fontSize: 16, color: AppColors.textLight)),
          const SizedBox(height: 8),
          Text('右上のボタンからフレンドを検索しましょう',
              style: TextStyle(fontSize: 13, color: AppColors.textLight.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

// ============================================================
// 申請管理シート（受信・送信タブ）
// ============================================================
class FriendRequestsSheet extends ConsumerStatefulWidget {
  const FriendRequestsSheet({super.key});

  @override
  ConsumerState<FriendRequestsSheet> createState() => _FriendRequestsSheetState();
}

class _FriendRequestsSheetState extends ConsumerState<FriendRequestsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final incomingAsync = ref.watch(incomingFriendRequestsProvider);
    final outgoingAsync = ref.watch(outgoingFriendRequestsProvider);

    final incomingCount = incomingAsync.valueOrNull?.length ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '申請管理',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),

          // タブバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: accentColor,
                unselectedLabelColor: AppColors.textLight,
                indicator: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('受信'),
                        if (incomingCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$incomingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: '送信済み'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 受信タブ
                _RequestList(
                  asyncValue: incomingAsync,
                  isIncoming: true,
                  accentColor: accentColor,
                  emptyMessage: '受信した申請はありません',
                ),
                // 送信済みタブ
                _RequestList(
                  asyncValue: outgoingAsync,
                  isIncoming: false,
                  accentColor: accentColor,
                  emptyMessage: '送信した申請はありません',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 申請リスト（受信/送信 共通）
class _RequestList extends ConsumerWidget {
  final AsyncValue<List<FriendRequestModel>> asyncValue;
  final bool isIncoming;
  final Color accentColor;
  final String emptyMessage;

  const _RequestList({
    required this.asyncValue,
    required this.isIncoming,
    required this.accentColor,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Text(emptyMessage,
                style: TextStyle(color: AppColors.textLight)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: requests.length,
          itemBuilder: (ctx, i) => _RequestCard(
            request: requests[i],
            isIncoming: isIncoming,
            accentColor: accentColor,
          ),
        );
      },
    );
  }
}

/// 申請カード
class _RequestCard extends ConsumerWidget {
  final FriendRequestModel request;
  final bool isIncoming;
  final Color accentColor;

  const _RequestCard({
    required this.request,
    required this.isIncoming,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = isIncoming ? request.fromUserName : request.toUserName;
    final displayEmail = isIncoming ? request.fromUserEmail : '';

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
              displayName.isNotEmpty ? displayName[0] : '?',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (displayEmail.isNotEmpty)
                  Text(displayEmail,
                      style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                const SizedBox(height: 2),
                Text(
                  isIncoming ? '申請を受け取っています' : '申請中（承認待ち）',
                  style: TextStyle(
                    fontSize: 11,
                    color: isIncoming ? Colors.orange[700] : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          if (isIncoming) ...[
            // 承認・拒否ボタン
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(friendControllerProvider.notifier)
                          .acceptFriendRequest(request);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${request.fromUserName}さんと\nフレンドになりました')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('承認', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 28,
                  child: TextButton(
                    onPressed: () async {
                      await ref.read(friendControllerProvider.notifier)
                          .rejectFriendRequest(request);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('拒否', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // キャンセルボタン
            TextButton(
              onPressed: () async {
                await ref.read(friendControllerProvider.notifier)
                    .cancelFriendRequest(request);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('取消', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
