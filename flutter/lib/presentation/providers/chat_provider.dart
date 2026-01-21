import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/datasources/remote/chat_datasource.dart';
import '../../data/models/post_model.dart';
import 'auth_provider.dart';

/// ChatDatasourceのプロバイダー
final chatDatasourceProvider = Provider<ChatDatasource>((ref) {
  return ChatDatasource(
    firestore: ref.watch(firestoreProvider),
    functions: FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
  );
});

/// チャット履歴のストリームプロバイダー
final chatHistoryProvider = StreamProvider.family<List<PostModel>, String>((ref, characterId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  if (characterId.isEmpty) return Stream.value([]);

  final datasource = ref.watch(chatDatasourceProvider);
  return datasource.watchChatHistory(
    userId: userId,
    characterId: characterId,
  );
});

/// チャットコントローラー
class ChatController extends StateNotifier<AsyncValue<void>> {
  final ChatDatasource _datasource;
  final Ref _ref;

  ChatController(this._datasource, this._ref) : super(const AsyncValue.data(null));

  /// メッセージを送信
  Future<String?> sendMessage({
    required String characterId,
    required String message,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    final user = _ref.read(userDocProvider).valueOrNull;
    if (userId == null || user == null) return null;

    state = const AsyncValue.loading();

    try {
      final reply = await _datasource.sendMessage(
        userId: userId,
        characterId: characterId,
        message: message,
        isPremium: user.isPremium,
      );
      state = const AsyncValue.data(null);
      return reply;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// チャットコントローラーのプロバイダー
final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  return ChatController(
    ref.watch(chatDatasourceProvider),
    ref,
  );
});
