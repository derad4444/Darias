import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/datasources/remote/chat_datasource.dart';
import '../../data/models/post_model.dart';
import 'auth_provider.dart';
import 'calendar_provider.dart';
import 'subscription_provider.dart';

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
    if (userId == null) return null;

    state = const AsyncValue.loading();

    try {
      // 予定検出付きでメッセージ送信
      final result = await _datasource.sendMessageWithScheduleDetection(
        userId: userId,
        characterId: characterId,
        message: message,
        isPremium: _ref.read(effectiveIsPremiumProvider),
      );

      // 予定が検出された場合、カレンダーに追加
      if (result.scheduleDetected && result.detectedSchedule != null) {
        debugPrint('📅 予定をカレンダーに追加: ${result.detectedSchedule!.title}');
        try {
          await _ref.read(calendarControllerProvider.notifier).addSchedule(
            result.detectedSchedule!,
          );
          debugPrint('✅ カレンダーへの追加成功');
        } catch (e) {
          debugPrint('⚠️ カレンダーへの追加失敗: $e');
          // 予定追加に失敗してもチャットは続ける
        }
      }

      state = const AsyncValue.data(null);
      return result.reply;
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
