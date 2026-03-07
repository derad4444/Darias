import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/memo_model.dart';
import '../../models/post_model.dart';
import '../../models/schedule_model.dart';
import '../../models/todo_model.dart';

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

/// メモ関連のキーワード
const _memoKeywords = [
  'メモ',
  'メモして',
  'メモしといて',
  'メモしておいて',
  'メモしておく',
];

/// タスク関連のキーワード
const _todoKeywords = [
  'タスク',
  'タスクに追加',
  'タスク追加',
  'やること',
  'TODO',
  'todo',
];

/// メッセージ送信結果
class SendMessageResult {
  final String reply;
  final ScheduleModel? detectedSchedule;
  final bool scheduleDetected;
  final MemoModel? detectedMemo;
  final bool memoDetected;
  final TodoModel? detectedTodo;
  final bool todoDetected;

  SendMessageResult({
    required this.reply,
    this.detectedSchedule,
    this.scheduleDetected = false,
    this.detectedMemo,
    this.memoDetected = false,
    this.detectedTodo,
    this.todoDetected = false,
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

  /// メモキーワードが含まれているかチェック
  bool _containsMemoKeyword(String message) {
    return _memoKeywords.any((keyword) => message.contains(keyword));
  }

  /// タスクキーワードが含まれているかチェック
  bool _containsTodoKeyword(String message) {
    return _todoKeywords.any((keyword) => message.contains(keyword));
  }

  /// メッセージからメモ内容をローカル抽出
  MemoModel _extractMemoFromMessage(String message) {
    var content = message;
    // キーワードを除去（長いものから順に）
    final sortedKeywords = List<String>.from(_memoKeywords)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final kw in sortedKeywords) {
      content = content.replaceAll(kw, '').trim();
    }
    final title = content.isEmpty ? message.trim() : content;
    final now = DateTime.now();
    return MemoModel(
      id: '',
      title: title,
      content: '',
      tag: '',
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// メッセージからタスク内容をローカル抽出
  TodoModel _extractTodoFromMessage(String message) {
    var title = message;
    // キーワードを除去（長いものから順に）
    final sortedKeywords = List<String>.from(_todoKeywords)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final kw in sortedKeywords) {
      title = title.replaceAll(kw, '').trim();
    }
    if (title.isEmpty) title = message.trim();
    final now = DateTime.now();
    return TodoModel(
      id: '',
      title: title,
      description: '',
      isCompleted: false,
      dueDate: null,
      priority: TodoPriority.medium,
      tag: '',
      createdAt: now,
      updatedAt: now,
    );
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
  /// 優先順: メモ → タスク → スケジュール → 通常チャット
  Future<SendMessageResult> sendMessageWithScheduleDetection({
    required String userId,
    required String characterId,
    required String message,
    required bool isPremium,
  }) async {
    final trimmed = message.trim();

    // ① メモキーワード検出
    if (_containsMemoKeyword(trimmed)) {
      debugPrint('📝 メモキーワード検出: "$trimmed"');
      final memo = _extractMemoFromMessage(trimmed);
      const reply = 'メモしておくね！';
      await _savePost(
        userId: userId,
        characterId: characterId,
        content: trimmed,
        reply: reply,
      );
      return SendMessageResult(
        reply: reply,
        detectedMemo: memo,
        memoDetected: true,
      );
    }

    // ② タスクキーワード検出
    if (_containsTodoKeyword(trimmed)) {
      debugPrint('✅ タスクキーワード検出: "$trimmed"');
      final todo = _extractTodoFromMessage(trimmed);
      const reply = 'タスクに追加しておくね！';
      await _savePost(
        userId: userId,
        characterId: characterId,
        content: trimmed,
        reply: reply,
      );
      return SendMessageResult(
        reply: reply,
        detectedTodo: todo,
        todoDetected: true,
      );
    }

    // ③ スケジュールキーワード検出
    if (_containsScheduleKeyword(trimmed)) {
      debugPrint('📅 予定キーワード検出: "$trimmed"');
      try {
        final extractResult = await _extractSchedule(
          userId: userId,
          userMessage: trimmed,
        );

        if (extractResult != null) {
          debugPrint('✅ 予定抽出成功: ${extractResult.title}');
          const reply = '予定楽しんでね！';
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
      }
    }

    // ④ 通常のキャラクター返答
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

    if (!hasSchedule) return null;

    final scheduleData = data['scheduleData'] as Map<String, dynamic>?;
    if (scheduleData == null) return null;

    final title = scheduleData['title'] as String? ?? '';
    final startDateStr = scheduleData['startDate'] as String?;
    final endDateStr = scheduleData['endDate'] as String?;
    final isAllDay = scheduleData['isAllDay'] as bool? ?? true;
    final location = scheduleData['location'] as String? ?? '';
    final memo = scheduleData['memo'] as String? ?? '';

    DateTime startDate;
    DateTime endDate;

    try {
      startDate = startDateStr != null ? DateTime.parse(startDateStr) : DateTime.now();
      endDate = endDateStr != null ? DateTime.parse(endDateStr) : startDate;
    } catch (e) {
      startDate = DateTime.now();
      endDate = startDate;
    }

    return ScheduleModel(
      id: '',
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
