import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/memo_datasource.dart';
import '../../data/models/memo_model.dart';
import 'auth_provider.dart';

/// MemoDatasourceのプロバイダー
final memoDatasourceProvider = Provider<MemoDatasource>((ref) {
  return MemoDatasource(
    firestore: ref.watch(firestoreProvider),
  );
});

/// メモリストのストリームプロバイダー
final memosProvider = StreamProvider<List<MemoModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final datasource = ref.watch(memoDatasourceProvider);
  return datasource.watchMemos(userId: userId);
});

/// メモコントローラー
class MemoController extends StateNotifier<AsyncValue<void>> {
  final MemoDatasource _datasource;
  final Ref _ref;

  MemoController(this._datasource, this._ref) : super(const AsyncValue.data(null));

  /// メモを追加
  Future<void> addMemo(MemoModel memo) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.addMemo(
        userId: userId,
        memo: memo,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// メモを更新
  Future<void> updateMemo(MemoModel memo) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.updateMemo(
        userId: userId,
        memo: memo,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// メモを削除
  Future<void> deleteMemo(String memoId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _datasource.deleteMemo(
        userId: userId,
        memoId: memoId,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// ピン留めを切り替え
  Future<void> togglePin(String memoId, bool isPinned) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _datasource.togglePin(
        userId: userId,
        memoId: memoId,
        isPinned: isPinned,
      );
    } catch (e) {
      rethrow;
    }
  }
}

/// メモコントローラーのプロバイダー
final memoControllerProvider =
    StateNotifierProvider<MemoController, AsyncValue<void>>((ref) {
  return MemoController(
    ref.watch(memoDatasourceProvider),
    ref,
  );
});
