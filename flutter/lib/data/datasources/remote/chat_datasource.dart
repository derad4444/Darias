import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';

/// 悩み系キーワード（会議への誘導トリガー）
const _concernKeywords = [
  'どうしよう',
  '迷ってる',
  '迷っている',
  '決められない',
  '悩んでいる',
  '悩んでる',
  'どうすればいい',
  'どうしたらいい',
  '困ってる',
  '困っている',
  '迷い',
  '悩み',
  'どうしたら',
  '相談したい',
  '判断できない',
  'わからなくなってきた',
];

/// メッセージ送信結果
class SendMessageResult {
  final String reply;
  final bool meetingSuggested;

  SendMessageResult({
    required this.reply,
    this.meetingSuggested = false,
  });
}

/// チャット関連のリモートデータソース
class ChatDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ChatDatasource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// 悩み系キーワードが含まれているかチェック（会議への誘導トリガー）
  bool _containsConcernKeyword(String message) {
    return _concernKeywords.any((keyword) => message.contains(keyword));
  }

  /// 直近30日以内の会議結論を取得（案4: チャットのコンテキストに使用）
  Future<String?> _fetchRecentMeetingConclusion(
    String userId,
    String characterId,
  ) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final historySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('characters')
          .doc(characterId)
          .collection('meeting_history')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (historySnapshot.docs.isEmpty) return null;

      final historyData = historySnapshot.docs.first.data();
      final createdAt = (historyData['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null || createdAt.isBefore(thirtyDaysAgo)) return null;

      final sharedMeetingId = historyData['sharedMeetingId'] as String?;
      if (sharedMeetingId == null) return null;

      final meetingDoc = await _firestore
          .collection('shared_meetings')
          .doc(sharedMeetingId)
          .get();

      if (!meetingDoc.exists) return null;

      final data = meetingDoc.data()!;
      final conversation = data['conversation'] as Map<String, dynamic>?;
      final conclusion = conversation?['conclusion'] as Map<String, dynamic>?;
      if (conclusion == null) return null;

      final summary = conclusion['summary'] as String? ?? '';
      final concern = historyData['userConcern'] as String? ?? '';
      if (summary.isEmpty) return null;

      final shortSummary =
          summary.length > 80 ? summary.substring(0, 80) : summary;
      return '相談:$concern / 結論:$shortSummary';
    } catch (e) {
      debugPrint('⚠️ fetchRecentMeetingConclusion error: $e');
      return null;
    }
  }

  /// メッセージを送信してAI返答を取得
  Future<String> sendMessage({
    required String userId,
    required String characterId,
    required String message,
    required bool isPremium,
  }) async {
    final result = await sendMessageWithScheduleDetection(
      userId: userId,
      characterId: characterId,
      message: message,
      isPremium: isPremium,
    );
    return result.reply;
  }

  /// メッセージを送信して検出結果も含めて返す
  /// AIによる分類 → memo/task/schedule/app_qa/chat にルーティング
  Future<SendMessageResult> sendMessageWithScheduleDetection({
    required String userId,
    required String characterId,
    required String message,
    required bool isPremium,
    int phase = 1,
    String? openerContext,
  }) async {
    final trimmed = message.trim();

    // AI分類＋抽出（classifyAndExtract Cloud Function）
    debugPrint('🤖 classifyAndExtract 呼び出し: "$trimmed"');
    Map<String, dynamic> classified;
    try {
      final callable = _functions.httpsCallable('classifyAndExtract');
      final result = await callable.call<Map<String, dynamic>>({
        'userMessage': trimmed,
      });
      classified = result.data;
    } catch (e) {
      debugPrint('⚠️ classifyAndExtract エラー (chat にフォールバック): $e');
      classified = {'type': 'chat'};
    }

    final type = classified['type'] as String? ?? 'chat';
    debugPrint('✅ 分類結果: $type');

    // アプリQ&A
    if (type == 'app_qa') {
      debugPrint('❓ app_qa ルート');
      final reply = await _answerAppQuestion(userId: userId, userMessage: trimmed);
      return SendMessageResult(reply: reply);
    }

    // ⑤ 通常チャット（chat または フォールバック）
    final chatHistory = await _fetchRecentChatHistory(userId, characterId);
    final meetingContext = await _fetchRecentMeetingConclusion(userId, characterId);
    final meetingSuggested = _containsConcernKeyword(trimmed);

    final callable = _functions.httpsCallable('generateCharacterReply');
    final params = <String, dynamic>{
      'characterId': characterId,
      'userMessage': trimmed,
      'userId': userId,
      'isPremium': isPremium,
      'chatHistory': chatHistory,
      'phase': phase,
    };
    if (meetingContext != null) {
      params['meetingContext'] = meetingContext;
    }
    if (openerContext != null) {
      params['openerContext'] = openerContext;
    }
    final result = await callable.call<Map<String, dynamic>>(params);

    final data = result.data;
    final reply = data['reply'] as String? ?? '';

    await _savePost(
      userId: userId,
      characterId: characterId,
      content: trimmed,
      reply: reply,
    );

    return SendMessageResult(
      reply: reply,
      meetingSuggested: meetingSuggested,
    );
  }

  /// アプリQ&A / ユーザーデータ参照（Cloud Function呼び出し）
  Future<String> _answerAppQuestion({
    required String userId,
    required String userMessage,
  }) async {
    try {
      final callable = _functions.httpsCallable('answerAppQuestion');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'userMessage': userMessage,
      });
      return result.data['reply'] as String? ?? 'うまく答えられなかったよ、ごめんね。';
    } catch (e) {
      debugPrint('⚠️ answerAppQuestionエラー: $e');
      return 'うまく答えられなかったよ、ごめんね。';
    }
  }


  /// 最近のチャット履歴を取得（2件）
  Future<List<Map<String, String>>> _fetchRecentChatHistory(
    String userId,
    String characterId,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(2)
        .get();

    return snapshot.docs.reversed.map((doc) {
      final data = doc.data();
      final userContent = data['content'] as String? ?? '';
      final aiResponse = data['analysis_result'] as String? ?? '';
      return {
        'userMessage': userContent.length > 100 ? userContent.substring(0, 100) : userContent,
        'aiResponse': aiResponse.length > 100 ? aiResponse.substring(0, 100) : aiResponse,
      };
    }).toList();
  }

  /// メッセージをFirestoreに保存
  Future<void> _savePost({
    required String userId,
    required String characterId,
    required String content,
    required String reply,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('posts')
        .add({
      'content': content,
      'timestamp': Timestamp.now(),
      'analysis_result': reply,
    });
  }

  /// 起動時オープナーをFirestoreに保存（キャラクター発話・ユーザー入力なし）
  Future<void> saveOpenerPost({
    required String userId,
    required String characterId,
    required String openerText,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('posts')
        .add({
      'content': '',
      'timestamp': Timestamp.now(),
      'analysis_result': openerText,
    });
  }

  /// チャット履歴をリアルタイムで取得
  Stream<List<PostModel>> watchChatHistory({
    required String userId,
    required String characterId,
    int? limit,
  }) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('posts')
        .orderBy('timestamp', descending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    });
  }
}
