import 'package:cloud_firestore/cloud_firestore.dart';

/// 日記モデル
class DiaryModel {
  final String id;
  final String content;
  final DateTime date;
  final String userComment;

  // アクティビティ型日記の追加フィールド
  final String? diaryType;
  final List<String>? facts;
  final String? aiComment;

  const DiaryModel({
    required this.id,
    required this.content,
    required this.date,
    this.userComment = '',
    this.diaryType,
    this.facts,
    this.aiComment,
  });

  bool get isActivityType => diaryType == 'activity';

  factory DiaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    List<String>? facts;
    final rawFacts = data['facts'];
    if (rawFacts is List) {
      facts = rawFacts.map((f) => f.toString()).toList();
    }

    return DiaryModel(
      id: doc.id,
      content: data['content'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userComment: data['user_comment'] as String? ?? '',
      diaryType: data['diary_type'] as String?,
      facts: facts,
      aiComment: data['ai_comment'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'date': Timestamp.fromDate(date),
      'user_comment': userComment,
      if (diaryType != null) 'diary_type': diaryType,
      if (facts != null) 'facts': facts,
      if (aiComment != null) 'ai_comment': aiComment,
    };
  }

  DiaryModel copyWith({
    String? id,
    String? content,
    DateTime? date,
    String? userComment,
    String? diaryType,
    List<String>? facts,
    String? aiComment,
  }) {
    return DiaryModel(
      id: id ?? this.id,
      content: content ?? this.content,
      date: date ?? this.date,
      userComment: userComment ?? this.userComment,
      diaryType: diaryType ?? this.diaryType,
      facts: facts ?? this.facts,
      aiComment: aiComment ?? this.aiComment,
    );
  }

  /// 表示用の日付文字列
  String get dateString {
    return '${date.year}年${date.month}月${date.day}日';
  }
}
