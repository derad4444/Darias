import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/calendar_datasource.dart';
import '../../data/models/schedule_model.dart';
import 'auth_provider.dart';

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

  CalendarController(this._datasource, this._ref) : super(const AsyncValue.data(null));

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
}

/// カレンダーコントローラーのプロバイダー
final calendarControllerProvider =
    StateNotifierProvider<CalendarController, AsyncValue<void>>((ref) {
  return CalendarController(
    ref.watch(calendarDatasourceProvider),
    ref,
  );
});
