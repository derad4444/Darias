import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/daily_mission_datasource.dart';
import '../../data/models/daily_mission_model.dart';
import 'auth_provider.dart';

final dailyMissionDatasourceProvider = Provider<DailyMissionDatasource?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (userId == null) return null;
  return DailyMissionDatasource(firestore: firestore, userId: userId);
});

final dailyMissionProvider =
    StateNotifierProvider<DailyMissionNotifier, AsyncValue<DailyMission>>((ref) {
  final ds = ref.watch(dailyMissionDatasourceProvider);
  return DailyMissionNotifier(ds);
});

// カレンダー表示用: 全ミッション達成済みの日付セット
final missionCompletedDatesProvider = FutureProvider<Set<String>>((ref) async {
  final ds = ref.watch(dailyMissionDatasourceProvider);
  if (ds == null) return {};
  return ds.fetchCompletedDates();
});

class DailyMissionNotifier extends StateNotifier<AsyncValue<DailyMission>> {
  final DailyMissionDatasource? _ds;

  DailyMissionNotifier(this._ds) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    if (_ds == null) {
      state = AsyncValue.data(DailyMission(date: _todayStr()));
      return;
    }
    try {
      final mission = await _ds!.fetchToday();
      state = AsyncValue.data(mission);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // 返り値: 今回のアクションで新たに達成されたかどうか
  Future<bool> markLogin() => _update((ds) => ds.markLogin());
  Future<bool> incrementChat() => _update((ds) => ds.incrementChat());
  Future<bool> markDiaryViewed() => _update((ds) => ds.markDiaryViewed());
  Future<bool> markDiaryRead() => _update((ds) => ds.markDiaryRead());

  Future<bool> _update(
      Future<DailyMission> Function(DailyMissionDatasource) action) async {
    if (_ds == null) return false;
    final before = state.valueOrNull;
    try {
      final updated = await action(_ds!);
      state = AsyncValue.data(updated);
      // 新たにいずれかのミッションが達成されたか判定
      return _newlyCompleted(before, updated);
    } catch (_) {
      return false;
    }
  }

  bool _newlyCompleted(DailyMission? before, DailyMission after) {
    if (before == null) return false;
    if (!before.loginDone && after.loginDone) return true;
    if (!before.chat2Done && after.chat2Done) return true;
    if (!before.chat6Done && after.chat6Done) return true;
    if (!before.diaryViewed && after.diaryViewed) return true;
    if (!before.diaryRead && after.diaryRead) return true;
    return false;
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
