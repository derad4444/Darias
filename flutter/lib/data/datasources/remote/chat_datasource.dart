import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';
import '../../models/schedule_model.dart';

/// 予定関連のキーワード（iOS版と同じ）
const _scheduleKeywords = [
  '予定',
  'スケジュール',
  '日',
  '時',
  'から',
  'まで',
  '明日',
  '今日',
  '週',
  '月',
  '年',
];

/// メッセージ送信結果
class SendMessageResult {
  final String reply;
  final ScheduleModel? detectedSchedule;
  final bool scheduleDetected;

  SendMessageResult({
    required this.reply,
    this.detectedSchedule,
    this.scheduleDetected = false,
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

  /// 予定キーワードが含まれているかチェック
  bool _containsScheduleKeyword(String message) {
    return _scheduleKeywords.any((keyword) => message.contains(keyword));
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

  /// メッセージを送信して予定検出結果も含めて返す
  Future<SendMessageResult> sendMessageWithScheduleDetection({
    required String userId,
    required String characterId,
    required String message,
    required bool isPremium,
  }) async {
    final trimmed = message.trim();

    // 予定キーワードが含まれている場合、まず予定抽出を試みる
    if (_containsScheduleKeyword(trimmed)) {
      debugPrint('📅 予定キーワード検出: メッセージ="$trimmed"');
      try {
        final extractResult = await _extractSchedule(
          userId: userId,
          userMessage: trimmed,
        );

        if (extractResult != null) {
          debugPrint('✅ 予定抽出成功: ${extractResult.title}');
          const reply = '予定楽しんでね！';

          // メッセージをFirestoreに保存
          await _savePost(
            userId: userId,
            characterId: characterId,
            content: trimmed,
            reply: reply,
          );

          return SendMessageResult(
            reply: reply,
            detectedSchedule: extractResult,
            scheduleDetected: true,
          );
        }
        debugPrint('ℹ️ 予定は検出されませんでした');
      } catch (e) {
        debugPrint('⚠️ extractScheduleエラー: $e');
        // extractScheduleエラー時は通常のキャラクター返答に進む
      }
    }

    // 通常のキャラクター返答を生成
    final chatHistory = await _fetchRecentChatHistory(userId, characterId);

    final callable = _functions.httpsCallable('generateCharacterReply');
    final result = await callable.call<Map<String, dynamic>>({
      'characterId': characterId,
      'userMessage': trimmed,
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
      content: trimmed,
      reply: reply,
    );

    return SendMessageResult(reply: reply);
  }

  /// Cloud Functionで予定を抽出
  Future<ScheduleModel?> _extractSchedule({
    required String userId,
    required String userMessage,
  }) async {
    final callable = _functions.httpsCallable('extractSchedule');
    final result = await callable.call<Map<String, dynamic>>({
      'userId': userId,
      'userMessage': userMessage,
    });

    final data = result.data;
    final hasSchedule = data['hasSchedule'] as bool? ?? false;

    if (!hasSchedule) {
      return null;
    }

    final scheduleData = data['scheduleData'] as Map<String, dynamic>?;
    if (scheduleData == null) {
      return null;
    }

    // scheduleDataからScheduleModelを作成
    final title = scheduleData['title'] as String? ?? '';
    final startDateStr = scheduleData['startDate'] as String?;
    final endDateStr = scheduleData['endDate'] as String?;
    final isAllDay = scheduleData['isAllDay'] as bool? ?? true;
    final location = scheduleData['location'] as String? ?? '';
    final memo = scheduleData['memo'] as String? ?? '';

    DateTime startDate;
    DateTime endDate;

    try {
      startDate = startDateStr != null
          ? DateTime.parse(startDateStr)
          : DateTime.now();
      endDate = endDateStr != null ? DateTime.parse(endDateStr) : startDate;
    } catch (e) {
      startDate = DateTime.now();
      endDate = startDate;
    }

    return ScheduleModel(
      id: '', // 新規作成なのでIDは空
      title: title,
      startDate: startDate,
      endDate: endDate,
      isAllDay: isAllDay,
      location: location,
      memo: memo,
    );
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
    print('📜 watchChatHistory called - userId: $userId, characterId: $characterId');

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
      print('📜 Got ${snapshot.docs.length} posts from Firestore');
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    });
  }
}
