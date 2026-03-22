import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/widget_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../../data/models/memo_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/models/todo_model.dart';
import '../../providers/memo_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/calendar_provider.dart';
import '../settings/tag_management_screen.dart';
import '../home/home_screen.dart';
import '../calendar/calendar_screen.dart';
import '../note/note_screen.dart';
import '../character/character_detail_screen.dart';
import '../settings/settings_screen.dart';

/// 現在選択されているタブのインデックス
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// iOS版と同じ5タブ構成のメイン画面
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
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
          WidgetDataService.shared.cacheSchedules(schedules, tagColors: tagColors);
        });
        ref.read(memosProvider).whenData(WidgetDataService.shared.cacheMemos);
        ref.read(todosProvider).whenData(WidgetDataService.shared.cacheTodos);
      });
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    // darias://open/?page=todo  → queryParameters['page'] = 'todo'
    final page = uri.queryParameters['page'];
    if (page == 'calendar') {
      ref.read(selectedTabProvider.notifier).state = 1;
    } else if (page == 'todo') {
      ref.read(selectedTabProvider.notifier).state = 2;
      ref.read(noteSegmentProvider.notifier).state = NoteSegment.todo;
    } else if (page == 'memo') {
      ref.read(selectedTabProvider.notifier).state = 2;
      ref.read(noteSegmentProvider.notifier).state = NoteSegment.memo;
    }
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);

    if (!kIsWeb) {
      ref.listen<AsyncValue<List<MemoModel>>>(memosProvider, (_, next) {
        next.whenData((memos) => WidgetDataService.shared.cacheMemos(memos));
      });
      ref.listen<AsyncValue<List<TodoModel>>>(todosProvider, (_, next) {
        next.whenData((todos) => WidgetDataService.shared.cacheTodos(todos));
      });
      ref.listen<AsyncValue<List<ScheduleModel>>>(allSchedulesProvider, (_, next) {
        next.whenData((schedules) {
          final tags = ref.read(tagsProvider);
          final tagColors = {for (final t in tags) t.name: t.colorHex};
          WidgetDataService.shared.cacheSchedules(schedules, tagColors: tagColors);
        });
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          // タブ0: ホーム
          const HomeScreen(),
          // タブ1: 予定（カレンダー）
          const CalendarScreen(),
          // タブ2: ノート（日記・Todo・メモ統合）
          const NoteScreen(),
          // タブ3: 詳細（キャラクター詳細）
          userAsync.when(
            data: (user) => CharacterDetailScreen(
              characterId: user?.characterId ?? '',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('エラー')),
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
                      icon: Icons.calendar_today_outlined,
                      selectedIcon: Icons.calendar_today,
                      label: '予定',
                      isSelected: selectedTab == 1,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 1,
                    ),
                    _TabItem(
                      icon: Icons.note_outlined,
                      selectedIcon: Icons.note,
                      label: 'ノート',
                      isSelected: selectedTab == 2,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 2,
                    ),
                    _TabItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: '詳細',
                      isSelected: selectedTab == 3,
                      accentColor: accentColor,
                      onTap: () => ref.read(selectedTabProvider.notifier).state = 3,
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

  const _TabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? accentColor : AppColors.textLight,
              size: 24,
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
