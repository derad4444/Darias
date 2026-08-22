import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/bgm_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';
import '../character/character_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../friend/friend_screen.dart';
import '../../../features/roguelike/screens/roguelike_home_screen.dart';
import '../../../features/roguelike/widgets/adventure_door_transition.dart';
import '../settings/volume_settings_screen.dart';
import '../../providers/friend_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../../data/services/analytics_service.dart';

/// 現在選択されているタブのインデックス
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// iOS版と同じ5タブ構成のメイン画面
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  @override
  void initState() {
    super.initState();
    // iOSのRootView.onAppearと同様にBGMを開始
    BGMPlayer.shared.playBGM('assets/audio/DARIAS BGM.mp3');
    // Analyticsのセグメントを初期化する。
    // ref.listen は初期値では発火しないため、ポストフレームで一度だけ補完する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAnalyticsSegment();
    });
    // 音量設定プロバイダーを早期初期化してミュート状態をロードしておく
    ref.read(volumeSettingsProvider);
  }

  void _updateAppBadge(WidgetRef ref) {
    final friendRequests = ref.read(pendingFriendRequestCountProvider);
    final unreadDiaries = ref.read(unreadDiaryCountProvider).valueOrNull ?? 0;
    FlutterAppBadger.updateBadgeCount(friendRequests + unreadDiaries);
  }


  @override
  void dispose() {
    super.dispose();
  }

  /// Analyticsのユーザープロパティ（元素・成長段階・課金状態）を最新化する。
  ///
  /// 送るのは区分値のみで、uid や本文などの個人・内容に関わる情報は含めない。
  void _syncAnalyticsSegment() {
    AnalyticsService.instance.setUserSegment(
      element: ref.read(characterDetailsProvider).valueOrNull?.element,
      signalCount: ref.read(signalCountProvider).valueOrNull,
      isPremium: ref.read(effectiveIsPremiumProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final pendingFriendCount = ref.watch(friendTabBadgeCountProvider);

    // 元素の確定・成長段階の変化・課金状態の変化に追従してセグメントを更新する
    ref.listen(signalCountProvider, (_, __) => _syncAnalyticsSegment());
    ref.listen(characterDetailsProvider, (_, __) => _syncAnalyticsSegment());
    ref.listen(effectiveIsPremiumProvider, (_, __) => _syncAnalyticsSegment());

    // アプリアイコンバッジ更新（iOS only）
    if (!kIsWeb) {
      ref.listen<int>(pendingFriendRequestCountProvider, (_, __) => _updateAppBadge(ref));
      ref.listen<AsyncValue<int>>(unreadDiaryCountProvider, (_, __) => _updateAppBadge(ref));
    }

    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          // タブ0: ホーム
          const HomeScreen(),
          // タブ1: 詳細（キャラクター詳細）
          userAsync.when(
            data: (user) => CharacterDetailScreen(
              characterId: user?.characterId ?? '',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('エラー')),
          ),
          // タブ2: フレンド
          const FriendScreen(),
          // タブ3: 冒険（ローグライク）※タブを開くと扉が開く演出を重ねる
          const AdventureDoorTransition(
            adventureTabIndex: 3,
            child: RoguelikeHomeScreen(),
          ),
          // タブ4: 設定
          const SettingsScreen(),
        ],
      ),
      // iOS風の半透明タブバー
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TabItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'ホーム',
                      isSelected: selectedTab == 0,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
                    ),
                    _TabItem(
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore,
                      label: '冒険',
                      isSelected: selectedTab == 3,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 3,
                    ),
                    _TabItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: '詳細',
                      isSelected: selectedTab == 1,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 1,
                    ),
                    _TabItem(
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      label: 'フレンド',
                      isSelected: selectedTab == 2,
                      accentColor: accentColor,
                      badgeCount: pendingFriendCount,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 2,
                    ),
                    _TabItem(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: '設定',
                      isSelected: selectedTab == 4,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// タブアイテムウィジェット
class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _TabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? accentColor : AppColors.textLight,
                      size: 24,
                    ),
                    if (hasBadge)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: badgeCount > 0
                              ? Text(
                                  badgeCount > 99 ? '99+' : '$badgeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              : const SizedBox(width: 8, height: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                color: isSelected ? accentColor : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
