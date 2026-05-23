import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/big5_datasource.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';

/// Big5Datasourceのプロバイダー
final big5DatasourceProvider = Provider<Big5Datasource>((ref) {
  return Big5Datasource(
    firestore: ref.watch(firestoreProvider),
  );
});

/// 性格診断リセットコントローラー
class DiagnosisResetController extends StateNotifier<AsyncValue<void>> {
  final Big5Datasource _datasource;
  final Ref _ref;

  DiagnosisResetController(this._datasource, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> resetDiagnosis(String characterId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();
    try {
      await _datasource.resetDiagnosis(
        userId: userId,
        characterId: characterId,
      );
      _ref.read(sessionChatCountProvider.notifier).state = 0;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final diagnosisResetControllerProvider =
    StateNotifierProvider<DiagnosisResetController, AsyncValue<void>>((ref) {
  return DiagnosisResetController(
    ref.watch(big5DatasourceProvider),
    ref,
  );
});
