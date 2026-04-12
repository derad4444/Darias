import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/big5_model.dart';

/// BIG5診断関連のリモートデータソース
class Big5Datasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Big5Datasource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// BIG5進捗をリアルタイムで取得
  Stream<Big5Progress> watchBig5Progress({
    required String userId,
    required String characterId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('big5Progress')
        .doc('current')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return Big5Progress.initial();
      }
      return Big5Progress.fromMap(snapshot.data()!);
    });
  }

  /// BIG5回答を送信
  Future<Big5AnswerResult> submitAnswer({
    required String userId,
    required String characterId,
    required int answerValue,
    required bool isPremium,
  }) async {
    final callable = _functions.httpsCallable('generateCharacterReply');
    final result = await callable.call<Map<String, dynamic>>({
      'characterId': characterId,
      'userMessage': '$answerValue',
      'userId': userId,
      'isPremium': isPremium,
    });

    final data = result.data;
    final reply = data['reply'] as String? ?? '';
    final isBig5Question = data['isBig5Question'];
    final hasNextQuestion = isBig5Question == 1 || isBig5Question == true;

    Big5Question? nextQuestion;
    if (hasNextQuestion) {
      final questionId = data['questionId'] as String?;
      final questionText = data['questionText'] as String?;
      if (questionId != null && questionText != null) {
        nextQuestion = Big5Question(
          id: questionId,
          question: questionText,
        );
      }
    }

    final stageCompleted = data['stageCompleted'] as int?;

    return Big5AnswerResult(
      reply: reply,
      nextQuestion: nextQuestion,
      stageCompleted: stageCompleted,
    );
  }

  /// BIG5診断を開始（メッセージで「性格診断して」を送信）
  Future<Big5StartResult> startDiagnosis({
    required String userId,
    required String characterId,
    required bool isPremium,
  }) async {
    final callable = _functions.httpsCallable('generateCharacterReply');
    final result = await callable.call<Map<String, dynamic>>({
      'characterId': characterId,
      'userMessage': '性格診断して',
      'userId': userId,
      'isPremium': isPremium,
      'chatHistory': <Map<String, String>>[],
    });

    final data = result.data;
    final reply = data['reply'] as String? ?? '';
    final isBig5Question = data['isBig5Question'];
    final hasQuestion = isBig5Question == 1 || isBig5Question == true;

    Big5Question? question;
    if (hasQuestion) {
      final questionId = data['questionId'] as String?;
      final questionText = data['questionText'] as String?;
      if (questionId != null && questionText != null) {
        question = Big5Question(
          id: questionId,
          question: questionText,
        );
      }
    }

    return Big5StartResult(
      reply: reply,
      question: question,
    );
  }

  /// BIG5解析データを取得
  Future<Big5AnalysisData?> fetchAnalysisData({
    required String personalityKey,
  }) async {
    final doc = await _firestore
        .collection('Big5Analysis')
        .doc(personalityKey)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final data = doc.data()!;
    final lastUpdated = (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Big5AnalysisData(
      personalityKey: personalityKey,
      lastUpdated: lastUpdated,
      analysis20: _parseAnalysisLevel(data, 'analysis_20', Big5AnalysisLevel.basic),
      analysis50: _parseAnalysisLevel(data, 'analysis_50', Big5AnalysisLevel.detailed),
      analysis100: _parseAnalysisLevel(data, 'analysis_100', Big5AnalysisLevel.complete),
    );
  }

  Map<Big5AnalysisCategory, Big5DetailedAnalysis>? _parseAnalysisLevel(
    Map<String, dynamic> data,
    String level,
    Big5AnalysisLevel analysisLevel,
  ) {
    final levelData = data[level] as Map<String, dynamic>?;
    if (levelData == null) return null;

    final result = <Big5AnalysisCategory, Big5DetailedAnalysis>{};

    for (final category in Big5AnalysisCategory.values) {
      final categoryData = levelData[category.value] as Map<String, dynamic>?;
      if (categoryData != null) {
        result[category] = Big5DetailedAnalysis.fromMap(
          categoryData,
          category,
          analysisLevel,
        );
      }
    }

    return result.isEmpty ? null : result;
  }

  /// Big5診断結果を完全リセット
  Future<void> resetDiagnosis({
    required String userId,
    required String characterId,
  }) async {
    // 1. big5Progress/current を削除（進捗・回答履歴・完了フラグすべて）
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('big5Progress')
        .doc('current')
        .delete();

    // 2. details/current の診断・属性関連フィールドをすべて削除
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .update({
      'confirmedBig5Scores': FieldValue.delete(),
      'personalityKey': FieldValue.delete(),
      'analysis_level': FieldValue.delete(),
      'sixPersonalities': FieldValue.delete(),
      'favorite_color': FieldValue.delete(),
      'favorite_place': FieldValue.delete(),
      'favorite_word': FieldValue.delete(),
      'word_tendency': FieldValue.delete(),
      'strength': FieldValue.delete(),
      'weakness': FieldValue.delete(),
      'skill': FieldValue.delete(),
      'hobby': FieldValue.delete(),
      'aptitude': FieldValue.delete(),
      'dream': FieldValue.delete(),
      'favorite_entertainment_genre': FieldValue.delete(),
    });

    // 3. generationStatus/current を削除（再生成を許可）
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('generationStatus')
        .doc('current')
        .delete();
  }

  /// キャラクター詳細からpersonalityKeyを取得
  Future<String?> fetchPersonalityKey({
    required String userId,
    required String characterId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return doc.data()!['personalityKey'] as String?;
  }
}

/// BIG5回答結果
class Big5AnswerResult {
  final String reply;
  final Big5Question? nextQuestion;
  final int? stageCompleted; // 1=20問完了, 2=50問完了, null=通常回答

  Big5AnswerResult({
    required this.reply,
    this.nextQuestion,
    this.stageCompleted,
  });
}

/// BIG5診断開始結果
class Big5StartResult {
  final String reply;
  final Big5Question? question;

  Big5StartResult({
    required this.reply,
    this.question,
  });
}
