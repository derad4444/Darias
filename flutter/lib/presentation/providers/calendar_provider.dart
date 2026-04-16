import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/calendar_datasource.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/shared_schedule_model.dart';
import '../../data/models/holiday_model.dart';
import '../../data/models/monthly_comment_model.dart';
import '../../data/services/widget_data_service.dart';
import '../../data/services/japanese_holiday_service.dart';
import 'auth_provider.dart';
import 'character_provider.dart';
import 'friend_provider.dart';
import '../screens/settings/tag_management_screen.dart';

/// CalendarDatasourceのプロバイダー
final calendarDatasourceProvider = Provider<CalendarDatasource>((ref) {
  return CalendarDatasource(
    firestore: ref.watch(firestoreProvider),
  );
});

/// 選択中の月
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// 選択中の日
final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// 月のスケジュールのストリームプロバイダー
final monthSchedulesProvider = StreamProvider.family<List<ScheduleModel>, DateTime>((ref, month) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final datasource = ref.watch(calendarDatasourceProvider);
  return datasource.watchSchedules(
    userId: userId,
    month: month,
  );
});

/// 全スケジュールのストリームプロバイダー
final allSchedulesProvider = StreamProvider<List<ScheduleModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final datasource = ref.watch(calendarDatasourceProvider);
  return datasource.watchAllSchedules(userId: userId);
});

/// 特定の日のスケジュール
final daySchedulesProvider = Provider.family<List<ScheduleModel>, DateTime>((ref, day) {
  final schedulesAsync = ref.watch(allSchedulesProvider);

  return schedulesAsync.when(
    data: (schedules) {
      return schedules.where((s) {
        final startDay = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
        final endDay = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);
        final targetDay = DateTime(day.year, day.month, day.day);

        return !targetDay.isBefore(startDay) && !targetDay.isAfter(endDay);
      }).toList();
    },
    loading: () => [],
    error: (e, st) => [],
  );
});

/// カレンダーコントローラー
class CalendarController extends StateNotifier<AsyncValue<void>> {
  final CalendarDatasource _datasource;
  final Ref _ref;

  CalendarController(this._datasource, this._ref) : super(const AsyncValue.data(null)) {
    // スケジュール更新時にキャッシュ
    _ref.listen<AsyncValue<List<ScheduleModel>>>(allSchedulesProvider, (_, next) {
      next.whenData((schedules) => _cacheSchedules(schedules));
    });
    // タグ更新時にも再キャッシュ（タグロード前にスケジュールが先に届くレースコンディション対策）
    _ref.listen<List<TagItem>>(tagsProvider, (_, __) {
      final schedules = _ref.read(allSchedulesProvider);
      schedules.whenData((s) => _cacheSchedules(s));
    });
  }

  void _cacheSchedules(List<ScheduleModel> schedules) {
    final tags = _ref.read(tagsProvider);
    final tagColors = {for (final t in tags) t.name: t.colorHex};
    WidgetDataService.shared.cacheSchedules(schedules, tagColors: tagColors);
  }

  /// スケジュールを追加
  Future<void> addSchedule(ScheduleModel schedule) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.addSchedule(
        userId: userId,
        schedule: schedule,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// スケジュールを更新
  Future<void> updateSchedule(ScheduleModel schedule) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.updateSchedule(
        userId: userId,
        schedule: schedule,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 繰り返しグループの全スケジュールを更新
  Future<void> updateAllRecurringSchedules({
    required String recurringGroupId,
    required ScheduleModel template,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();
    try {
      await _datasource.updateRecurringSchedules(
        userId: userId,
        recurringGroupId: recurringGroupId,
        template: template,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// スケジュールを削除
  Future<void> deleteSchedule(String scheduleId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _datasource.deleteSchedule(
        userId: userId,
        scheduleId: scheduleId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 繰り返しグループの全スケジュールを削除
  Future<void> deleteAllRecurringSchedules(String recurringGroupId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _datasource.deleteRecurringSchedules(
        userId: userId,
        recurringGroupId: recurringGroupId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 月を変更
  void changeMonth(DateTime month) {
    _ref.read(selectedMonthProvider.notifier).state = DateTime(month.year, month.month, 1);
  }

  /// 前月へ
  void previousMonth() {
    final current = _ref.read(selectedMonthProvider);
    changeMonth(DateTime(current.year, current.month - 1, 1));
  }

  /// 次月へ
  void nextMonth() {
    final current = _ref.read(selectedMonthProvider);
    changeMonth(DateTime(current.year, current.month + 1, 1));
  }

  /// 日を選択
  void selectDay(DateTime day) {
    _ref.read(selectedDayProvider.notifier).state = day;
  }

  /// 今日に移動
  void goToToday() {
    final now = DateTime.now();
    changeMonth(DateTime(now.year, now.month, 1));
    selectDay(now);
  }

  /// 指定した年月に移動
  void goToMonth(int year, int month) {
    changeMonth(DateTime(year, month, 1));
  }
}

/// カレンダーコントローラーのプロバイダー
final calendarControllerProvider =
    StateNotifierProvider<CalendarController, AsyncValue<void>>((ref) {
  return CalendarController(
    ref.watch(calendarDatasourceProvider),
    ref,
  );
});

/// 祝日一覧のプロバイダー（ローカルデータを使用）
final holidaysProvider = Provider<List<HolidayModel>>((ref) {
  return JapaneseHolidayService.allHolidays();
});

/// 特定の日付の祝日を取得
final holidayForDateProvider = Provider.family<HolidayModel?, DateTime>((ref, date) {
  final name = JapaneseHolidayService.getHolidayName(date);
  if (name == null) return null;
  return HolidayModel(
    id: JapaneseHolidayService.key(date),
    name: name,
    dateString: JapaneseHolidayService.key(date),
    date: DateTime(date.year, date.month, date.day),
  );
});

/// 月次コメントのプロバイダー
final monthlyCommentProvider = FutureProvider.family<String, DateTime>((ref, month) async {
  final userId = ref.watch(currentUserIdProvider);
  final characterId = ref.watch(currentCharacterIdProvider);

  if (userId == null || characterId == null) {
    return MonthlyCommentModel.defaultComment;
  }

  final firestore = ref.watch(firestoreProvider);
  final monthId = '${month.year}-${month.month.toString().padLeft(2, '0')}';

  try {
    final doc = await firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('monthlyComments')
        .doc(monthId)
        .get();

    if (doc.exists) {
      final comment = MonthlyCommentModel.fromFirestore(doc);
      return comment.comment.isNotEmpty ? comment.comment : MonthlyCommentModel.defaultComment;
    }
    return MonthlyCommentModel.defaultComment;
  } catch (e) {
    return MonthlyCommentModel.defaultComment;
  }
});

/// 最後に使用したタグ（新規予定作成時の初期値として使用）
final lastUsedScheduleTagProvider = StateProvider<String>((ref) => '');

/// 検索テキストの状態
final calendarSearchTextProvider = StateProvider<String>((ref) => '');

// ============================================================
// フレンド予定共有
// ============================================================

// ---------------------------------------------------------------
// フレンドID選択（SharedPreferences で永続化）
// ---------------------------------------------------------------
class SelectedFriendIdsNotifier extends StateNotifier<Set<String>> {
  final FirebaseFirestore _firestore;
  final String? _userId;

  SelectedFriendIdsNotifier(this._firestore, this._userId) : super({}) {
    _load();
  }

  Future<void> _load() async {
    if (_userId == null) return;
    try {
      final doc = await _firestore
          .collection('users').doc(_userId)
          .collection('settings').doc('calendarSettings')
          .get();
      if (doc.exists) {
        final ids = List<String>.from(doc.data()?['selectedFriendIds'] ?? []);
        debugPrint('[SelectedFriendIds] loaded: $ids');
        if (mounted) state = Set.from(ids);
      }
    } catch (e) {
      debugPrint('[SelectedFriendIds] load error: $e');
    }
  }

  void update(Set<String> ids) {
    state = ids;
    _save();
  }

  Future<void> _save() async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users').doc(_userId)
          .collection('settings').doc('calendarSettings')
          .set({'selectedFriendIds': state.toList()}, SetOptions(merge: true));
      debugPrint('[SelectedFriendIds] saved: ${state.toList()}');
    } catch (e) {
      debugPrint('[SelectedFriendIds] save error: $e');
    }
  }
}

/// カレンダーに表示中のフレンドID集合（複数選択可・Firestore永続化）
final selectedFriendIdsProvider =
    StateNotifierProvider<SelectedFriendIdsNotifier, Set<String>>(
  (ref) => SelectedFriendIdsNotifier(
    ref.watch(firestoreProvider),
    ref.watch(currentUserIdProvider),
  ),
);

/// フレンド予定の手動リフレッシュカウンター
final friendScheduleRefreshProvider = StateProvider<int>((ref) => 0);

/// 選択フレンドの指定月スケジュール（Cloud Function 経由、月単位でキャッシュ）
final selectedFriendSchedulesForMonthProvider =
    FutureProvider.family<List<SharedScheduleModel>, DateTime>(
  (ref, month) async {
    // リフレッシュトリガーを監視（変化するたびに再フェッチ）
    ref.watch(friendScheduleRefreshProvider);
    final selectedIds = ref.watch(selectedFriendIdsProvider);
    if (selectedIds.isEmpty) return [];

    final friends = ref.watch(friendsProvider).valueOrNull ?? [];
    final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
    final results = <SharedScheduleModel>[];

    for (final friendId in selectedIds) {
      // フレンド名を取得
      String friendName = '';
      for (final f in friends) {
        if (f.id == friendId) {
          friendName = f.name;
          break;
        }
      }

      try {
        final callable = functions.httpsCallable('getFriendSchedules');
        final result = await callable.call({
          'friendId': friendId,
          'year': month.year,
          'month': month.month,
        });
        final data = result.data as Map<String, dynamic>;
        final schedulesList = data['schedules'] as List<dynamic>? ?? [];

        for (final s in schedulesList) {
          final map = Map<String, dynamic>.from(s as Map);
          results.add(SharedScheduleModel.fromFunctionData(
            map,
            ownerId: friendId,
            ownerName: friendName,
          ));
        }
      } catch (e) {
        debugPrint('[FriendSchedule] Error fetching for $friendId: $e');
      }
    }

    return results;
  },
);

/// 特定の日のフレンドスケジュール
final friendDaySchedulesProvider =
    Provider.family<List<SharedScheduleModel>, DateTime>((ref, day) {
  final selectedIds = ref.watch(selectedFriendIdsProvider);
  if (selectedIds.isEmpty) return [];

  final month = DateTime(day.year, day.month, 1);
  final asyncSchedules = ref.watch(selectedFriendSchedulesForMonthProvider(month));

  return asyncSchedules.when(
    data: (schedules) => schedules.where((ss) {
      final s = ss.schedule;
      final startDay = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
      final endDay = DateTime(s.endDate.year, s.endDate.month, s.endDate.day);
      final targetDay = DateTime(day.year, day.month, day.day);
      return !targetDay.isBefore(startDay) && !targetDay.isAfter(endDay);
    }).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// 検索モードの状態
final calendarSearchModeProvider = StateProvider<bool>((ref) => false);

/// フィルターされたスケジュール（検索用）
final filteredSchedulesProvider = Provider<List<ScheduleModel>>((ref) {
  final searchText = ref.watch(calendarSearchTextProvider);
  final schedulesAsync = ref.watch(allSchedulesProvider);

  return schedulesAsync.when(
    data: (schedules) {
      if (searchText.isEmpty) {
        return schedules;
      }
      final lowerSearch = searchText.toLowerCase();
      return schedules.where((schedule) {
        return schedule.title.toLowerCase().contains(lowerSearch) ||
            schedule.memo.toLowerCase().contains(lowerSearch) ||
            schedule.tag.toLowerCase().contains(lowerSearch);
      }).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
    },
    loading: () => [],
    error: (e, st) => [],
  );
});
