// import 'dart:async'; // 手帳ウィジェット購読廃止に伴いコメントアウト（不使用・復活時に戻す）
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:home_widget/home_widget.dart'; // 手帳ウィジェット廃止に伴いコメントアウト（不使用・復活時に戻す）
import '../../../core/theme/app_colors.dart';
import '../../../data/services/bgm_player.dart';
// ホーム画面ウィジェット機能の停止に伴いコメントアウト（不使用・復活時に戻す）
// import '../../../data/services/widget_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
// import '../../../data/models/memo_model.dart'; // 同上（ウィジェット用キャッシュでのみ使用）
// import '../../../data/models/schedule_model.dart'; // 予定通知の再登録停止に伴いコメントアウト
// import '../../../data/models/todo_model.dart'; // 同上（ウィジェット用キャッシュでのみ使用）
// import '../../providers/memo_provider.dart'; // 同上
// import '../../providers/todo_provider.dart'; // 同上
// import '../../providers/calendar_provider.dart'; // 同上（allSchedulesProvider）
// import '../settings/tag_management_screen.dart'; // 同上（tagsProvider/TagItem）
import '../home/home_screen.dart';
import '../plan/plan_screen.dart';
import '../character/character_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../friend/friend_screen.dart';
import '../../../features/roguelike/screens/roguelike_home_screen.dart';
import '../../../features/roguelike/widgets/adventure_door_transition.dart';
import '../settings/volume_settings_screen.dart';
import '../../providers/friend_provider.dart';
import '../../providers/diary_provider.dart';
// import '../../providers/notification_provider.dart'; // 同上（notificationSettingsProvider）
// import '../../../data/services/notification_service.dart'; // 同上

/// 現在選択されているタブのインデックス
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// iOS版と同じ5タブ構成のメイン画面
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  // 手帳タブ廃止に伴いコメントアウト（不使用・復活時に戻す）。ウィジェットタップ購読。
  // StreamSubscription<Uri?>? _widgetClickSub;
  // 予定通知の再登録停止に伴いコメントアウト（不使用・復活時に戻す）。再登録の重複防止用。
  // bool _hasRescheduledNotifications = false;

  @override
  void initState() {
    super.initState();
    // iOSのRootView.onAppearと同様にBGMを開始
    BGMPlayer.shared.playBGM('assets/audio/DARIAS BGM.mp3');
    // 音量設定プロバイダーを早期初期化してミュート状態をロードしておく
    ref.read(volumeSettingsProvider);
    // ホーム画面ウィジェット機能の停止に伴いコメントアウト（不使用・復活時に戻す）。
    // ウィジェットのディープリンク購読と、初回表示時のウィジェット用データキャッシュ。
    /* if (!kIsWeb) {
      _widgetClickSub = WidgetDataService.shared.widgetActionStream.listen(_handleWidgetUri);
      // コールドスタート（ウィジェットタップによるアプリ起動）の処理
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (uri != null) _handleWidgetUri(uri);
      });
      // 初回表示時にすでにデータが揃っている場合も確実にキャッシュ
      // （ref.listenは初期値では発火しないため、ポストフレームで補完）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(allSchedulesProvider).whenData((schedules) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheSchedules(schedules, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheSchedules (init) error: $e');
          });
        });
        ref.read(memosProvider).whenData((memos) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheMemos(memos, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheMemos (init) error: $e');
          });
        });
        ref.read(todosProvider).whenData((todos) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheTodos(todos, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheTodos (init) error: $e');
          });
        });
      });
    } */
  }

  void _updateAppBadge(WidgetRef ref) {
    final friendRequests = ref.read(pendingFriendRequestCountProvider);
    final unreadDiaries = ref.read(unreadDiaryCountProvider).valueOrNull ?? 0;
    FlutterAppBadger.updateBadgeCount(friendRequests + unreadDiaries);
  }

  // 手帳タブ廃止に伴いコメントアウト（削除せず残置。復活時に戻す）。
  /* void _showPlanSegmentMenu(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final tabWidth = size.width / 6;
    final tabCenter = tabWidth * 1.5;

    showMenu<PlanSegment>(
      context: context,
      position: RelativeRect.fromLTRB(
        tabCenter - 80,
        size.height - padding.bottom - 170,
        size.width - tabCenter - 80,
        padding.bottom + 80,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: PlanSegment.schedule,
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 10),
            const Text('予定'),
          ]),
        ),
        PopupMenuItem(
          value: PlanSegment.memo,
          child: Row(children: [
            const Icon(Icons.edit_note, size: 18),
            const SizedBox(width: 10),
            const Text('メモ'),
          ]),
        ),
        PopupMenuItem(
          value: PlanSegment.todo,
          child: Row(children: [
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: 10),
            const Text('タスク'),
          ]),
        ),
      ],
    ).then((segment) {
      if (segment == null) return;
      ref.read(selectedTabProvider.notifier).state = 1;
      ref.read(planSegmentProvider.notifier).state = segment;
      clearDiaryBadge(ref).then((_) {
        if (!kIsWeb) _updateAppBadge(ref);
      });
    });
  } */

  // 手帳タブ廃止に伴いコメントアウト（不使用・復活時に戻す）。ウィジェットのディープリンクで手帳へ遷移していた。
  /* void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    // darias://open/?page=todo  → queryParameters['page'] = 'todo'
    final page = uri.queryParameters['page'];
    if (page == 'calendar') {
      ref.read(selectedTabProvider.notifier).state = 1;
      ref.read(planSegmentProvider.notifier).state = PlanSegment.schedule;
    } else if (page == 'todo') {
      ref.read(selectedTabProvider.notifier).state = 1;
      ref.read(planSegmentProvider.notifier).state = PlanSegment.todo;
    } else if (page == 'memo') {
      ref.read(selectedTabProvider.notifier).state = 1;
      ref.read(planSegmentProvider.notifier).state = PlanSegment.memo;
    }
  } */

  @override
  void dispose() {
    // _widgetClickSub?.cancel(); // 手帳タブ廃止に伴いコメントアウト（不使用）

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final pendingFriendCount = ref.watch(friendTabBadgeCountProvider);
    // 手帳タブ廃止に伴いコメントアウト（復活時に戻す）。手帳バッジ用。
    // final hasNewDiary = ref.watch(hasNewDiaryProvider).valueOrNull ?? false;

    // アプリアイコンバッジ更新（iOS only）
    if (!kIsWeb) {
      ref.listen<int>(pendingFriendRequestCountProvider, (_, __) => _updateAppBadge(ref));
      ref.listen<AsyncValue<int>>(unreadDiaryCountProvider, (_, __) => _updateAppBadge(ref));
      // 手帳（予定）機能の停止に伴いコメントアウト（不使用・復活時に戻す）。
      // 起動時に今後の予定通知を再登録（iOSの64件上限対応）していた。
      // これが生きていると、UIを隠しても過去に登録した予定の通知が届き続ける。
      /* ref.listen<AsyncValue<List<ScheduleModel>>>(allSchedulesProvider, (_, next) {
        if (_hasRescheduledNotifications || !mounted) return;
        next.whenData((schedules) {
          if (!ref.read(notificationSettingsProvider).scheduleNotifications) return;
          _hasRescheduledNotifications = true;
          NotificationService().rescheduleUpcomingNotifications(schedules);
        });
      }); */
    }

    // ホーム画面ウィジェット機能の停止に伴いコメントアウト（不使用・復活時に戻す）。
    // 予定・メモ・タスク・タグの変更をウィジェット用ストレージへ書き出していた。
    /* if (!kIsWeb) {
      ref.listen<AsyncValue<List<MemoModel>>>(memosProvider, (_, next) {
        next.whenData((memos) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheMemos(memos, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheMemos error: $e');
          });
        });
      });
      ref.listen<AsyncValue<List<TodoModel>>>(todosProvider, (_, next) {
        next.whenData((todos) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheTodos(todos, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheTodos error: $e');
          });
        });
      });
      ref.listen<AsyncValue<List<ScheduleModel>>>(allSchedulesProvider, (_, next) {
        next.whenData((schedules) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheSchedules(schedules, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheSchedules error: $e');
          });
        });
      });
      // タグがロード/更新されたら全データを再キャッシュ（初回ロード時のタイミングずれ対策）
      ref.listen<List<TagItem>>(tagsProvider, (_, tags) {
        if (tags.isEmpty) return;
        final tagColors = {for (final t in tags) t.name: t.colorHex};
        ref.read(allSchedulesProvider).whenData((schedules) {
          WidgetDataService.shared.cacheSchedules(schedules, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheSchedules (tag update) error: $e');
          });
        });
        ref.read(memosProvider).whenData((memos) {
          WidgetDataService.shared.cacheMemos(memos, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheMemos (tag update) error: $e');
          });
        });
        ref.read(todosProvider).whenData((todos) {
          WidgetDataService.shared.cacheTodos(todos, tagColors: tagColors).catchError((e) {
            debugPrint('⚠️ cacheTodos (tag update) error: $e');
          });
        });
      });
    } */

    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          // タブ0: ホーム
          const HomeScreen(),
          // タブ1: 予定・タスク・メモ（統合）＝手帳。ナビの手帳ボタンは廃止（コメントアウト）
          // したが、他タブの index を維持するため IndexedStack の子はここに残す（非表示・到達不可）。
          const PlanScreen(),
          // タブ2: 詳細（キャラクター詳細）
          userAsync.when(
            data: (user) => CharacterDetailScreen(
              characterId: user?.characterId ?? '',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('エラー')),
          ),
          // タブ3: フレンド
          const FriendScreen(),
          // タブ4: 冒険（ローグライク）※タブを開くと扉が開く演出を重ねる
          const AdventureDoorTransition(
            adventureTabIndex: 4,
            child: RoguelikeHomeScreen(),
          ),
          // タブ5: 設定
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
                    // 手帳タブは廃止（削除ではなくコメントアウトで残置）。
                    // 復活時はこの _TabItem と、hasNewDiary の宣言・_showPlanSegmentMenu の
                    // コメントアウトを外す。タブ index は他タブ維持のため IndexedStack 側は残す。
                    /* _TabItem(
                      icon: Icons.menu_book_outlined,
                      selectedIcon: Icons.menu_book,
                      label: '手帳',
                      isSelected: selectedTab == 1,
                      accentColor: accentColor,
                      showBadge: hasNewDiary,
                      onTap: () {
                        ref.read(selectedTabProvider.notifier).state = 1;
                        clearDiaryBadge(ref).then((_) {
                          if (!kIsWeb) _updateAppBadge(ref);
                        });
                      },
                      onLongPress: () => _showPlanSegmentMenu(context, ref),
                    ), */
                    // 並び順: ホーム→冒険→詳細→フレンド→設定（index は維持し表示順のみ変更）。
                    _TabItem(
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore,
                      label: '冒険',
                      isSelected: selectedTab == 4,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 4,
                    ),
                    _TabItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: '詳細',
                      isSelected: selectedTab == 2,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 2,
                    ),
                    _TabItem(
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      label: 'フレンド',
                      isSelected: selectedTab == 3,
                      accentColor: accentColor,
                      badgeCount: pendingFriendCount,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 3,
                    ),
                    _TabItem(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: '設定',
                      isSelected: selectedTab == 5,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 5,
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
  final VoidCallback? onLongPress;
  final int badgeCount;
  final bool showBadge;

  const _TabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.badgeCount = 0,
    // 手帳タブ廃止で現在は未使用（復活時に再利用するため残置）。
    // ignore: unused_element_parameter
    this.showBadge = false,
    // ignore: unused_element_parameter
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0 || showBadge;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                if (onLongPress != null) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.unfold_more,
                    size: 15,
                    color: isSelected ? accentColor : AppColors.textLight,
                  ),
                ],
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
