import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
// 説明ヒントバナー廃止に伴い不使用:
// import '../../providers/auth_provider.dart';
import '../../../data/models/friend_model.dart';
import '../../widgets/character_avatar_widget.dart';
import '../../widgets/ads/screen_banner.dart';
import '../../../data/services/ad_service.dart';
import 'friend_search_screen.dart';
import 'compatibility_screen.dart';
class FriendScreen extends ConsumerWidget {
  const FriendScreen({super.key});

  void _showElementChartSheet(BuildContext context, Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ElementChartSheet(accentColor: accentColor),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;
    final friendsAsync = ref.watch(friendsProvider);
    final pendingCount = ref.watch(pendingFriendRequestCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 上部バナー広告
              ScreenBanner(adUnitId: AdConfig.friendScreenTopBannerAdUnitId),
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
                    // 元素相性表ヘルプボタン
                    IconButton(
                      icon: Icon(Icons.help_outline, color: textColor),
                      tooltip: '元素の相性について',
                      onPressed: () => _showElementChartSheet(context, accentColor),
                    ),
                  ],
                ),
              ),

              // フレンド一覧（追加ボタンはこの領域の上に重ねる。
              // 下のバナー広告やヘッダーに被らせないため Stack はここに置く）
              Expanded(
                child: Stack(
                  children: [
                    friendsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('エラー: $e')),
                      data: (friends) {
                        if (friends.isEmpty) {
                          return _EmptyFriendView(accentColor: accentColor);
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
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
                    _DraggableFriendAddButton(
                      accentColor: accentColor,
                      pendingCount: pendingCount,
                    ),
                  ],
                ),
              ),
              // 下部バナー広告
              ScreenBanner(adUnitId: AdConfig.friendScreenBottomBannerAdUnitId),
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

  Future<void> _confirmRemoveFriend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('フレンドを削除'),
        content: Text(
          '${friend.displayName}をフレンドから削除しますか？\n\n相手のフレンド一覧からも削除され、予定の共有も解除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(friendControllerProvider.notifier).removeFriend(friend.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompatibilityScreen(friend: friend),
        ),
      ),
      onLongPress: () => _confirmRemoveFriend(context, ref),
      child: Container(
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
                fallbackText: friend.displayName.isNotEmpty ? friend.displayName[0] : '?',
                fallbackBackgroundColor: accentColor.withValues(alpha: 0.15),
                fallbackTextColor: accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // あだ名を大きく出し、下にアカウント名を添える。
                    // あだ名が無い人はアカウント名だけを出す。
                    // メールアドレスは一覧に出さない（画面の写り込みで他人に見えてしまうため）
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (friend.hasNickname && friend.name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        friend.name,
                        style: TextStyle(fontSize: 12, color: AppColors.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_right,
                      color: accentColor.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// フレンドがいない時の表示
/// フレンド追加ボタンを押したときの選択肢
enum _FriendAddAction { search, requests }

/// 「フレンドを追加」「申請の管理」を選ぶシート
class _FriendAddActionMenu extends StatelessWidget {
  final Color accentColor;
  final int pendingCount;

  const _FriendAddActionMenu({
    required this.accentColor,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_add_alt_1, color: accentColor),
              title: const Text('フレンドを追加'),
              subtitle: const Text('IDやQRコードで探して申請する'),
              onTap: () => Navigator.pop(context, _FriendAddAction.search),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.mail_outline, color: accentColor),
              title: const Text('申請の管理'),
              subtitle: const Text('受け取った申請・送った申請を確認する'),
              trailing: pendingCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      alignment: Alignment.center,
                      child: Text(
                        pendingCount > 99 ? '99+' : '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () => Navigator.pop(context, _FriendAddAction.requests),
            ),
          ],
        ),
      ),
    );
  }
}

/// フレンド検索・申請管理を開く丸ボタン。
///
/// ドラッグで好きな位置へ動かせる。位置は「置ける範囲に対する割合」で端末に保存するため、
/// 画面サイズが違う端末や回転後でも同じ相対位置に出る。
class _DraggableFriendAddButton extends StatefulWidget {
  final Color accentColor;
  final int pendingCount;

  const _DraggableFriendAddButton({
    required this.accentColor,
    required this.pendingCount,
  });

  @override
  State<_DraggableFriendAddButton> createState() => _DraggableFriendAddButtonState();
}

class _DraggableFriendAddButtonState extends State<_DraggableFriendAddButton> {
  static const _prefsKeyX = 'friend_add_button_ratio_x';
  static const _prefsKeyY = 'friend_add_button_ratio_y';
  static const _size = 56.0;
  static const _margin = 16.0;

  /// 置ける範囲に対する割合(0.0〜1.0)。未設定のあいだは null で、既定の右下に出す。
  Offset? _ratio;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_prefsKeyX);
      final y = prefs.getDouble(_prefsKeyY);
      if (!mounted || x == null || y == null) return;
      setState(() => _ratio = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)));
    } catch (_) {
      // 読めなければ既定位置のままでよい
    }
  }

  /// 「フレンドを追加」か「申請の管理」かを選ばせてから遷移する。
  Future<void> _showActionMenu() async {
    final action = await showModalBottomSheet<_FriendAddAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FriendAddActionMenu(
        accentColor: widget.accentColor,
        pendingCount: widget.pendingCount,
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _FriendAddAction.search:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendSearchScreen()),
        );
      case _FriendAddAction.requests:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
        );
    }
  }

  Future<void> _savePosition(Offset ratio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyX, ratio.dx);
      await prefs.setDouble(_prefsKeyY, ratio.dy);
    } catch (_) {
      // 保存に失敗しても操作は妨げない
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ボタンの中心が動ける幅・高さ（余白ぶんを除いた範囲）
        final rangeX =
            (constraints.maxWidth - _size - _margin * 2).clamp(1.0, double.infinity);
        final rangeY =
            (constraints.maxHeight - _size - _margin * 2).clamp(1.0, double.infinity);
        final ratio = _ratio ?? const Offset(1, 1); // 既定は右下

        return Padding(
          padding: const EdgeInsets.all(_margin),
          child: Align(
            // 割合(0〜1) を Alignment(-1〜1) に変換する
            alignment: Alignment(ratio.dx * 2 - 1, ratio.dy * 2 - 1),
            child: GestureDetector(
              onTap: _showActionMenu,
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _ratio = Offset(
                    (ratio.dx + details.delta.dx / rangeX).clamp(0.0, 1.0),
                    (ratio.dy + details.delta.dy / rangeY).clamp(0.0, 1.0),
                  );
                });
              },
              onPanEnd: (_) {
                setState(() => _dragging = false);
                final saved = _ratio;
                if (saved != null) _savePosition(saved);
              },
              child: AnimatedScale(
                scale: _dragging ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: _dragging ? 0.3 : 0.18),
                              blurRadius: _dragging ? 12 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_search,
                            color: Colors.white, size: 26),
                      ),
                      if (widget.pendingCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints:
                                const BoxConstraints(minWidth: 20, minHeight: 20),
                            child: Text(
                              widget.pendingCount > 99
                                  ? '99+'
                                  : '${widget.pendingCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
          Text('フレンド追加ボタンからフレンドを検索しましょう',
              style: TextStyle(fontSize: 13, color: AppColors.textLight.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

// ============================================================
// 申請管理画面（受信・送信タブ）
// ============================================================
class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen>
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios, color: accentColor),
                ),
                Text(
                  '申請管理',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
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
        ),
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
          CharacterAvatarWidget(
            userId: isIncoming ? request.fromUserId : request.toUserId,
            size: 44,
            fallbackText: displayName.isNotEmpty ? displayName[0] : '?',
            fallbackBackgroundColor: accentColor.withValues(alpha: 0.15),
            fallbackTextColor: accentColor,
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

// ============================================================
// 元素相性表ボトムシート
// ============================================================
class _ElementChartSheet extends ConsumerWidget {
  final Color accentColor;
  const _ElementChartSheet({required this.accentColor});

  static const _pairs = [
    ('炎↔水', '感情で深く繋がる。時にぶつかるほどの熱量'),
    ('雷↔氷', '同じ直感型。熱量の差が惹かれ合いを生む'),
    ('光↔闇', '同じ分析型。外向きと内向きで視点が逆'),
    ('風↔土', '完全対極。自由と安定が刺激し合う'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(backgroundGradientProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Text(
                      '元素と相性について',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor.withAlpha(160)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: textColor.withAlpha(40)),
              // コンテンツ
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/element_chart.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '双方向矢印の元素同士は特に相性が良い対ペアです。無はすべての元素と一定の相性があります。',
                      style: TextStyle(fontSize: 13, color: textColor.withAlpha(180), height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    ..._pairs.map((pair) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pair.$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                          Text(' : ', style: TextStyle(fontSize: 13, color: textColor)),
                          Expanded(
                            child: Text(
                              pair.$2,
                              style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
