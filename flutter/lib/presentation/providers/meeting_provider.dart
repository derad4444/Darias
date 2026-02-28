import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/meeting_datasource.dart';
import '../../data/models/meeting_model.dart';
import '../../data/models/meeting_history_model.dart';
import '../../data/models/six_person_meeting_model.dart';
import 'auth_provider.dart';
import 'character_provider.dart';

/// MeetingDatasourceのProvider
final meetingDatasourceProvider = Provider<MeetingDatasource?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  return MeetingDatasource(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
    userId: user.uid,
  );
});

/// 会議履歴のProvider（iOS版と同じパス）
final meetingHistoryProvider =
    StreamProvider.family<List<MeetingHistoryModel>, String>((ref, characterId) {
  final datasource = ref.watch(meetingDatasourceProvider);
  if (datasource == null || characterId.isEmpty) {
    return Stream.value([]);
  }
  return datasource.watchMeetingHistory(characterId: characterId);
});

/// 会議一覧のProvider（旧パス - 互換性のため残す）
final meetingsProvider = StreamProvider<List<MeetingModel>>((ref) {
  final datasource = ref.watch(meetingDatasourceProvider);
  if (datasource == null) {
    return Stream.value([]);
  }
  return datasource.watchMeetings();
});

/// 単一会議のProvider
final meetingProvider =
    StreamProvider.family<MeetingModel?, String>((ref, meetingId) {
  final datasource = ref.watch(meetingDatasourceProvider);
  if (datasource == null) {
    return Stream.value(null);
  }
  return datasource.watchMeeting(meetingId);
});

/// 会議コントローラー
final meetingControllerProvider =
    StateNotifierProvider<MeetingController, AsyncValue<void>>((ref) {
  return MeetingController(ref);
});

class MeetingController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MeetingController(this._ref) : super(const AsyncValue.data(null));

  MeetingDatasource? get _datasource => _ref.read(meetingDatasourceProvider);

  // ===========================================
  // iOS版と同じAPI
  // ===========================================

  /// 6人会議を生成または取得（iOS版と同じ）
  Future<GenerateMeetingResponse?> generateOrReuseMeeting({
    required String concern,
    String? concernCategory,
  }) async {
    final datasource = _datasource;
    final characterId = _ref.read(currentCharacterIdProvider);
    if (datasource == null || characterId == null) return null;

    state = const AsyncValue.loading();
    try {
      final response = await datasource.generateOrReuseMeeting(
        characterId: characterId,
        concern: concern,
        concernCategory: concernCategory,
      );
      state = const AsyncValue.data(null);
      return response;
    } catch (e, st) {
      debugPrint('❌ generateOrReuseMeeting error: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 特定の会議データを取得
  Future<SixPersonMeetingModel?> fetchMeetingById(String meetingId) async {
    final datasource = _datasource;
    if (datasource == null) return null;

    try {
      return await datasource.fetchMeetingById(meetingId);
    } catch (e) {
      debugPrint('❌ fetchMeetingById error: $e');
      return null;
    }
  }

  /// 会議に評価をつける
  Future<void> rateMeeting(String meetingId, int rating) async {
    final datasource = _datasource;
    if (datasource == null) return;

    try {
      await datasource.rateMeeting(meetingId, rating);
    } catch (e) {
      debugPrint('❌ rateMeeting error: $e');
    }
  }

  /// 会議利用回数を取得
  Future<int> getMeetingUsageCount() async {
    final datasource = _datasource;
    final characterId = _ref.read(currentCharacterIdProvider);
    if (datasource == null || characterId == null) return 0;

    return await datasource.getMeetingUsageCount(characterId);
  }

  // ===========================================
  // 以下は旧API（互換性のため残す）
  // ===========================================

  /// 会議を作成
  Future<String?> createMeeting(String topic) async {
    final datasource = _datasource;
    if (datasource == null) return null;

    state = const AsyncValue.loading();
    try {
      final meeting = MeetingModel.create(topic: topic);
      final meetingId = await datasource.createMeeting(meeting);
      state = const AsyncValue.data(null);
      return meetingId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// 会議を削除
  Future<void> deleteMeeting(String meetingId) async {
    final datasource = _datasource;
    if (datasource == null) return;

    state = const AsyncValue.loading();
    try {
      await datasource.deleteMeeting(meetingId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 会議履歴を削除
  Future<void> deleteMeetingHistory({
    required String characterId,
    required String historyId,
  }) async {
    final datasource = _datasource;
    if (datasource == null) return;

    try {
      await datasource.deleteMeetingHistory(
        characterId: characterId,
        historyId: historyId,
      );
    } catch (e) {
      debugPrint('❌ deleteMeetingHistory error: $e');
    }
  }

  /// 会議を終了（アーカイブ）
  Future<void> endMeeting(String meetingId) async {
    final datasource = _datasource;
    if (datasource == null) return;

    state = const AsyncValue.loading();
    try {
      await datasource.archiveMeeting(meetingId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// メッセージを追加
  Future<void> addMessage(String meetingId, MeetingMessage message) async {
    final datasource = _datasource;
    if (datasource == null) return;

    try {
      await datasource.addMessage(meetingId, message);
    } catch (e) {
      // エラーは握りつぶす（UIで処理）
    }
  }

  /// AIの応答を生成してメッセージを追加（Flutter独自の会議機能用）
  Future<void> generateParticipantResponse({
    required String meetingId,
    required String topic,
    required MeetingParticipant participant,
    required List<MeetingMessage> previousMessages,
  }) async {
    final datasource = _datasource;
    if (datasource == null) return;

    try {
      // ダミーレスポンスを生成（この機能はFlutter独自のため）
      final response = _generateDummyResponse(participant, topic, previousMessages);

      final message = MeetingMessage(
        participantId: participant.id,
        participantName: participant.name,
        content: response,
        timestamp: DateTime.now(),
      );

      await datasource.addMessage(meetingId, message);
    } catch (e) {
      debugPrint('❌ generateParticipantResponse error: $e');
    }
  }

  /// ダミーレスポンスを生成（デモ用）
  String _generateDummyResponse(
    MeetingParticipant participant,
    String topic,
    List<MeetingMessage> previousMessages,
  ) {
    final responses = {
      'leader': [
        'この議題について、皆さんの意見を聞かせてください。',
        'なるほど、良い視点ですね。他の方はいかがでしょうか？',
        'それでは、ここまでの議論をまとめましょう。',
        '建設的な議論ができていますね。次のステップを考えましょう。',
      ],
      'analyst': [
        'データを見ると、この方向性には一定の根拠があります。',
        '過去の事例を分析すると、成功率は約70%程度と見込まれます。',
        '数値的な観点から見ると、リスクとリターンのバランスは妥当です。',
        'もう少し詳細なデータが必要かもしれません。',
      ],
      'creative': [
        '面白いアイデアがあります！こんな方法はどうでしょう？',
        '既存の枠にとらわれず、新しいアプローチを試してみませんか？',
        'ここにイノベーションのチャンスがあると思います！',
        '発想を転換すると、もっと良い解決策が見つかるかも。',
      ],
      'critic': [
        'ちょっと待ってください。この点にリスクがあります。',
        '現実的に考えると、いくつかの課題があります。',
        '良いアイデアですが、実現可能性について検討が必要です。',
        '潜在的な問題点を指摘させてください。',
      ],
      'supporter': [
        '皆さんの意見、どれも価値がありますね。',
        'チームで協力すれば、きっと良い結果が出せます。',
        'それぞれの強みを活かしたアプローチが良いと思います。',
        '前向きに取り組めば、解決できない問題はありません。',
      ],
      'executor': [
        '具体的なアクションプランを決めましょう。',
        'まず最初のステップとして、これから着手すべきです。',
        'スケジュールとリソースを明確にしましょう。',
        '効率的に進めるために、優先順位をつけましょう。',
      ],
    };

    final participantResponses = responses[participant.id] ?? responses['leader']!;
    final index = previousMessages.length % participantResponses.length;
    return participantResponses[index];
  }
}
