import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/meeting_datasource.dart';
import '../../data/models/meeting_model.dart';
import 'auth_provider.dart';

/// MeetingDatasourceのProvider
final meetingDatasourceProvider = Provider<MeetingDatasource?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  return MeetingDatasource(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instance,
    userId: user.uid,
  );
});

/// 会議一覧のProvider
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

  /// AIの応答を取得してメッセージを追加
  Future<void> generateParticipantResponse({
    required String meetingId,
    required String topic,
    required MeetingParticipant participant,
    required List<MeetingMessage> previousMessages,
  }) async {
    final datasource = _datasource;
    if (datasource == null) return;

    try {
      final response = await datasource.generateMeetingResponse(
        meetingId: meetingId,
        topic: topic,
        participant: participant,
        previousMessages: previousMessages,
      );

      final message = MeetingMessage(
        participantId: participant.id,
        participantName: participant.name,
        content: response,
        timestamp: DateTime.now(),
      );

      await datasource.addMessage(meetingId, message);
    } catch (e) {
      // エラーは握りつぶす（UIで処理）
    }
  }
}
