import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/character_datasource.dart';
import '../../data/models/character_model.dart';
import 'auth_provider.dart';

/// CharacterDatasourceのプロバイダー
final characterDatasourceProvider = Provider<CharacterDatasource>((ref) {
  return CharacterDatasource(firestore: ref.watch(firestoreProvider));
});

/// 全キャラクターリストのプロバイダー
final charactersProvider = StreamProvider<List<CharacterModel>>((ref) {
  final datasource = ref.watch(characterDatasourceProvider);
  return datasource.watchCharacters();
});

/// 特定のキャラクターのプロバイダー
final characterProvider = StreamProvider.family<CharacterModel?, String>((ref, characterId) {
  final datasource = ref.watch(characterDatasourceProvider);
  return datasource.watchCharacter(characterId);
});

/// 現在選択中のキャラクターのプロバイダー
final currentCharacterProvider = StreamProvider<CharacterModel?>((ref) {
  final user = ref.watch(userDocProvider).valueOrNull;
  final characterId = user?.characterId;

  if (characterId == null) {
    return Stream.value(null);
  }

  final datasource = ref.watch(characterDatasourceProvider);
  return datasource.watchCharacter(characterId);
});

/// キャラクター選択コントローラー
class CharacterController extends StateNotifier<AsyncValue<void>> {
  final CharacterDatasource _datasource;
  final Ref _ref;

  CharacterController(this._datasource, this._ref) : super(const AsyncValue.data(null));

  /// キャラクターを選択
  Future<void> selectCharacter(String characterId) async {
    state = const AsyncValue.loading();
    try {
      final userId = _ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('User not logged in');

      // ユーザードキュメントのcharacterIdを更新
      await _ref.read(firestoreProvider)
          .collection('users')
          .doc(userId)
          .update({'characterId': characterId});

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// キャラクターコントローラーのプロバイダー
final characterControllerProvider =
    StateNotifierProvider<CharacterController, AsyncValue<void>>((ref) {
  return CharacterController(
    ref.watch(characterDatasourceProvider),
    ref,
  );
});
