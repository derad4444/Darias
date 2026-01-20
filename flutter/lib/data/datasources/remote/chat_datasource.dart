import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/post_model.dart';

/// チャット関連のリモートデータソース
class ChatDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ChatDatasource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// メッセージを送信してAI返答を取得
  Future<String> sendMessage({
    required String userId,
    required String characterId,
    required String message,
    required bool isPremium,
  }) async {
    // 会話履歴を取得
    final chatHistory = await _fetchRecentChatHistory(userId, characterId);

    // Cloud Functionを呼び出し
    final callable = _functions.httpsCallable('generateCharacterReply');
    final result = await callable.call<Map<String, dynamic>>({
      'characterId': characterId,
      'userMessage': message,
      'userId': userId,
      'isPremium': isPremium,
      'chatHistory': chatHistory,
    });

    final data = result.data;
    final reply = data['reply'] as String? ?? '';

    // メッセージをFirestoreに保存
    await _savePost(
      userId: userId,
      characterId: characterId,
      content: message,
      reply: reply,
    );

    return reply;
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

      // 各メッセージを100文字に制限
      return {
        'userMessage': userContent.length > 100
            ? userContent.substring(0, 100)
            : userContent,
        'aiResponse': aiResponse.length > 100
            ? aiResponse.substring(0, 100)
            : aiResponse,
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
