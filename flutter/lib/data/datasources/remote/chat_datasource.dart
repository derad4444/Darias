import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../models/memo_model.dart';
import '../../models/post_model.dart';
import '../../models/schedule_model.dart';
import '../../models/todo_model.dart';

/// 質問パターン（アプリ操作に関する質問のみ → アプリQ&A）
const _questionKeywords = [
  'どうやって',
  'どうすれば',
  '使い方',
  'やり方',
  '方法',
  'わからない',
  'わかんない',
  'どこ',
  'どうする',
  'どうやる',
  'できる？',
  'できない？',
  '見るには',
];

/// アプリ関連ワード（質問キーワードと組み合わせてQ&Aルートを判定）
const _appKeywords = [
  'アプリ',
  '機能',
  '設定',
  '予定',
  'タスク',
  'メモ',
  'カレンダー',
  '日記',
  '診断',
  'キャラクター',
  '履歴',
  'チャット',
  'TODO',
  'todo',
  '追加',
  '削除',
  '編集',
  'タグ',
  'ピン',
  '通知',
];

/// ユーザーデータ参照キーワード（質問と組み合わせてFirestoreから取得）
const _scheduleDataKeywords = ['予定', 'スケジュール', 'カレンダー'];
const _todoDataKeywords = ['タスク', 'TODO', 'todo', 'やること'];
const _memoDataKeywords = ['メモ一覧', 'メモ見せて', 'メモある'];

/// 予定関連のキーワード（誤検知防止のため具体的な表現のみ）
const _scheduleKeywords = [
  '予定',
  'スケジュール',
  '明日',
  '明後日',
  '今日',
  '今週',
  '来週',
  '今月',
  '来月',
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
  final List<ScheduleModel> detectedSchedules;
  final MemoModel? detectedMemo;
  final bool memoDetected;
  final TodoModel? detectedTodo;
  final bool todoDetected;
  final bool meetingSuggested;

  bool get scheduleDetected => detectedSchedules.isNotEmpty;

  SendMessageResult({
    required this.reply,
    this.detectedSchedules = const [],
    this.detectedMemo,
    this.memoDetected = false,
    this.detectedTodo,
    this.todoDetected = false,
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

  /// 質問パターンが含まれているかチェック（アプリ操作ワードとの組み合わせ必須）
  bool _containsQuestionPattern(String message) {
    final hasQuestion = _questionKeywords.any((k) => message.contains(k));
    final hasAppWord = _appKeywords.any((k) => message.contains(k));
    return hasQuestion && hasAppWord;
  }

  /// ユーザーデータ参照が必要なキーワードを検出（質問時のみ使用）
  List<String> _detectDataTypes(String message) {
    final types = <String>[];
    if (_scheduleDataKeywords.any((kw) => message.contains(kw))) types.add('schedules');
    if (_todoDataKeywords.any((kw) => message.contains(kw))) types.add('todos');
    if (_memoDataKeywords.any((kw) => message.contains(kw))) types.add('memos');
    return types;
  }

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
  /// 優先順: 質問 → メモ → タスク → スケジュール → 通常チャット
  Future<SendMessageResult> sendMessageWithScheduleDetection({
    required String userId,
    required String characterId,
    required String message,
    required bool isPremium,
  }) async {
    final trimmed = message.trim();

    // ① 質問パターン検出（最優先：アプリQ&A / ユーザーデータ参照）
    if (_containsQuestionPattern(trimmed)) {
      debugPrint('❓ 質問パターン検出: "$trimmed"');
      final reply = await _answerAppQuestion(userId: userId, userMessage: trimmed);
      return SendMessageResult(reply: reply);
    }

    // ② メモキーワード検出（postsには保存しない：日記はmemosコレクションから直接読む）
    if (_containsMemoKeyword(trimmed)) {
      debugPrint('📝 メモキーワード検出: "$trimmed"');
      final memo = _extractMemoFromMessage(trimmed);
      return SendMessageResult(
        reply: 'メモしておくね！',
        detectedMemo: memo,
        memoDetected: true,
      );
    }

    // ③ タスクキーワード検出（postsには保存しない：日記はtodosコレクションから直接読む）
    if (_containsTodoKeyword(trimmed)) {
      debugPrint('✅ タスクキーワード検出: "$trimmed"');
      final todo = _extractTodoFromMessage(trimmed);
      return SendMessageResult(
        reply: 'タスクに追加しておくね！',
        detectedTodo: todo,
        todoDetected: true,
      );
    }

    // ④ スケジュールキーワード検出（postsには保存しない：日記はschedulesコレクションから直接読む）
    if (_containsScheduleKeyword(trimmed)) {
      debugPrint('📅 予定キーワード検出: "$trimmed"');
      try {
        final extractResult = await _extractSchedule(
          userId: userId,
          userMessage: trimmed,
        );

        if (extractResult.isNotEmpty) {
          debugPrint('✅ 予定抽出成功: ${extractResult.length}件');
          return SendMessageResult(
            reply: '予定楽しんでね！',
            detectedSchedules: extractResult,
          );
        }
        debugPrint('ℹ️ 予定は検出されませんでした');
      } catch (e) {
        debugPrint('⚠️ extractScheduleエラー: $e');
      }
    }

    // ⑤ 通常のキャラクター返答
    final chatHistory = await _fetchRecentChatHistory(userId, characterId);

    // 案4: 直近の会議結論をコンテキストとして取得（30日以内）
    final meetingContext =
        await _fetchRecentMeetingConclusion(userId, characterId);

    // 案2: 悩み系キーワードを検出して会議への誘導フラグを立てる
    final meetingSuggested = _containsConcernKeyword(trimmed);

    final callable = _functions.httpsCallable('generateCharacterReply');
    final params = <String, dynamic>{
      'characterId': characterId,
      'userMessage': trimmed,
      'userId': userId,
      'isPremium': isPremium,
      'chatHistory': chatHistory,
    };
    if (meetingContext != null) {
      params['meetingContext'] = meetingContext;
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
      final dataTypes = _detectDataTypes(userMessage);
      final callable = _functions.httpsCallable('answerAppQuestion');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'userMessage': userMessage,
        'dataTypes': dataTypes,
      });
      return result.data['reply'] as String? ?? 'うまく答えられなかったよ、ごめんね。';
    } catch (e) {
      debugPrint('⚠️ answerAppQuestionエラー: $e');
      return 'うまく答えられなかったよ、ごめんね。';
    }
  }

  /// Cloud Functionで予定を抽出（複数件対応）
  Future<List<ScheduleModel>> _extractSchedule({
    required String userId,
    required String userMessage,
  }) async {
    final callable = _functions.httpsCallable('extractSchedule');
    final result = await callable.call<Map<String, dynamic>>({
      'userId': userId,
      'userMessage': userMessage,
    });

    final data = result.data;
    final scheduleList = data['schedules'] as List<dynamic>? ?? [];

    return scheduleList.map((item) {
      final s = item as Map<String, dynamic>;
      final startDate = _parseDateField(s['startDate']) ?? DateTime.now();
      final endDate = _parseDateField(s['endDate']) ?? startDate;
      return ScheduleModel(
        id: '',
        title: s['title'] as String? ?? '',
        startDate: startDate,
        endDate: endDate,
        isAllDay: s['isAllDay'] as bool? ?? false,
        location: s['location'] as String? ?? '',
        tag: s['tag'] as String? ?? '',
        memo: s['memo'] as String? ?? '',
        repeatOption: s['repeatOption'] as String? ?? '',
        remindValue: s['remindValue'] as int? ?? 0,
        remindUnit: s['remindUnit'] as String? ?? '',
      );
    }).toList();
  }

  /// 日付フィールドをパース（ISO文字列 or Timestampオブジェクト対応）
  DateTime? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    // FirebaseのTimestampがMapとして返ってくる場合
    if (value is Map) {
      final seconds = value['_seconds'] as int? ?? value['seconds'] as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
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
