import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/meeting_model.dart';

class MeetingDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _userId;

  MeetingDatasource({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required String userId,
  })  : _firestore = firestore,
        _functions = functions,
        _userId = userId;

  CollectionReference<Map<String, dynamic>> get _meetingsCollection =>
      _firestore.collection('users').doc(_userId).collection('meetings');

  /// 会議一覧を取得（リアルタイム）
  Stream<List<MeetingModel>> watchMeetings() {
    return _meetingsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MeetingModel.fromFirestore(doc)).toList());
  }

  /// 単一の会議を取得（リアルタイム）
  Stream<MeetingModel?> watchMeeting(String meetingId) {
    return _meetingsCollection.doc(meetingId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MeetingModel.fromFirestore(doc);
    });
  }

  /// 会議を作成
  Future<String> createMeeting(MeetingModel meeting) async {
    final docRef = await _meetingsCollection.add(meeting.toMap());
    return docRef.id;
  }

  /// 会議を更新
  Future<void> updateMeeting(MeetingModel meeting) async {
    await _meetingsCollection.doc(meeting.id).update({
      ...meeting.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 会議を削除
  Future<void> deleteMeeting(String meetingId) async {
    await _meetingsCollection.doc(meetingId).delete();
  }

  /// メッセージを追加
  Future<void> addMessage(String meetingId, MeetingMessage message) async {
    await _meetingsCollection.doc(meetingId).update({
      'messages': FieldValue.arrayUnion([message.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// AI応答を生成（Cloud Functions経由）
  Future<String> generateMeetingResponse({
    required String meetingId,
    required String topic,
    required MeetingParticipant participant,
    required List<MeetingMessage> previousMessages,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateMeetingResponse');
      final result = await callable.call({
        'meetingId': meetingId,
        'topic': topic,
        'participant': participant.toMap(),
        'previousMessages': previousMessages.map((m) => m.toMap()).toList(),
      });

      return result.data['response'] as String? ?? '';
    } catch (e) {
      // Cloud Functionsがない場合はダミーレスポンス
      return _generateDummyResponse(participant, topic, previousMessages);
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

  /// 会議をアーカイブ
  Future<void> archiveMeeting(String meetingId) async {
    await _meetingsCollection.doc(meetingId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
