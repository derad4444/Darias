import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/datasources/remote/chat_datasource.dart';
import '../../data/models/post_model.dart';
import 'auth_provider.dart';
import 'subscription_provider.dart';

/// 会議後フォローアップの結論を一時保持するプロバイダー（案1）
final meetingFollowupConclusionProvider = StateProvider<String?>((ref) => null);

/// セッション内チャットターン数（アプリ起動ごとにリセット、性格リセット時も0に戻す）
final sessionChatCountProvider = StateProvider<int>((ref) => 0);

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

  /// 起動時オープナーをFirestoreに保存
  Future<void> saveOpener({
    required String characterId,
    required String openerText,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _datasource.saveOpenerPost(
      userId: userId,
      characterId: characterId,
      openerText: openerText,
    );
  }

  /// メッセージを送信し、検出結果を返す（保存は呼び出し元が確認後に行う）
  Future<SendMessageResult?> sendMessage({
    required String characterId,
    required String message,
    int phase = 1,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return null;

    state = const AsyncValue.loading();

    try {
      final result = await _datasource.sendMessageWithScheduleDetection(
        userId: userId,
        characterId: characterId,
        message: message,
        isPremium: _ref.read(effectiveIsPremiumProvider),
        phase: phase,
      );

      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      debugPrint('⚠️ sendMessage error: $e');
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
