import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/diary_datasource.dart';
import '../../data/models/diary_model.dart';
import 'auth_provider.dart';

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
