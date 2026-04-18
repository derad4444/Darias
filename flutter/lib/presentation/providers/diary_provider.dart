import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/diary_datasource.dart';
import '../../data/models/diary_model.dart';
import '../../data/services/hint_service.dart';
import 'auth_provider.dart';
import 'character_provider.dart';

/// DiaryDatasourceのプロバイダー
final diaryDatasourceProvider = Provider<DiaryDatasource>((ref) {
  return DiaryDatasource(
    firestore: ref.watch(firestoreProvider),
  );
});

/// 日記リストのストリームプロバイダー
final diariesProvider = StreamProvider.family<List<DiaryModel>, String>((ref, characterId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  if (characterId.isEmpty) return Stream.value([]);

  final datasource = ref.watch(diaryDatasourceProvider);
  return datasource.watchDiaries(
    userId: userId,
    characterId: characterId,
  );
});

/// 現在のキャラクターの全日記リストプロバイダー
final currentCharacterDiariesProvider = Provider<AsyncValue<List<DiaryModel>>>((ref) {
  final characterId = ref.watch(currentCharacterIdProvider);
  if (characterId == null || characterId.isEmpty) {
    return const AsyncValue.data([]);
  }
  return ref.watch(diariesProvider(characterId));
});

/// 特定の日付の日記を取得するプロバイダー
final diaryForDateProvider = Provider.family<DiaryModel?, DateTime>((ref, date) {
  final diariesAsync = ref.watch(currentCharacterDiariesProvider);

  return diariesAsync.whenOrNull(
    data: (diaries) {
      try {
        return diaries.firstWhere(
          (diary) =>
              diary.date.year == date.year &&
              diary.date.month == date.month &&
              diary.date.day == date.day,
        );
      } catch (_) {
        return null;
      }
    },
  );
});

/// 新しい日記があるかどうかのプロバイダー（カレンダータブバッジ用）
final hasNewDiaryProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final diariesAsync = ref.watch(currentCharacterDiariesProvider);
  final diaries = diariesAsync.valueOrNull;
  if (diaries == null || diaries.isEmpty) return false;

  final latestDate = diaries.map((d) => d.date).reduce((a, b) => a.isAfter(b) ? a : b);
  final hint = HintService(userId);
  final lastSeen = await hint.getLastSeenDiaryDate();
  if (lastSeen == null) return true;

  final latest = DateTime(latestDate.year, latestDate.month, latestDate.day);
  final seen = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
  return latest.isAfter(seen);
});

/// 日記バッジクリア（カレンダータブタップ時に呼ぶ）
Future<void> clearDiaryBadge(WidgetRef ref) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;
  final diariesAsync = ref.read(currentCharacterDiariesProvider);
  final diaries = diariesAsync.valueOrNull;
  if (diaries == null || diaries.isEmpty) return;
  final latestDate = diaries.map((d) => d.date).reduce((a, b) => a.isAfter(b) ? a : b);
  await HintService(userId).setLastSeenDiaryDate(latestDate);
  ref.invalidate(hasNewDiaryProvider);
}

/// 日記コントローラー
class DiaryController extends StateNotifier<AsyncValue<void>> {
  final DiaryDatasource _datasource;
  final Ref _ref;

  DiaryController(this._datasource, this._ref) : super(const AsyncValue.data(null));

  /// ユーザーコメントを保存
  Future<void> saveUserComment({
    required String characterId,
    required String diaryId,
    required String comment,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.saveUserComment(
        userId: userId,
        characterId: characterId,
        diaryId: diaryId,
        comment: comment,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 日記コントローラーのプロバイダー
final diaryControllerProvider =
    StateNotifierProvider<DiaryController, AsyncValue<void>>((ref) {
  return DiaryController(
    ref.watch(diaryDatasourceProvider),
    ref,
  );
});
