import 'package:cloud_firestore/cloud_firestore.dart';

/// 日記モデル
class DiaryModel {
  final String id;
  final String content;
  final DateTime date;
  final String userComment;

  const DiaryModel({
    required this.id,
    required this.content,
    required this.date,
    this.userComment = '',
  });

  factory DiaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return DiaryModel(
      id: doc.id,
      content: data['content'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userComment: data['user_comment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'date': Timestamp.fromDate(date),
      'user_comment': userComment,
    };
  }

  DiaryModel copyWith({
    String? id,
    String? content,
    DateTime? date,
    String? userComment,
  }) {
    return DiaryModel(
      id: id ?? this.id,
      content: content ?? this.content,
      date: date ?? this.date,
      userComment: userComment ?? this.userComment,
    );
  }

  /// 表示用の日付文字列
  String get dateString {
    return '${date.year}年${date.month}月${date.day}日';
  }
}
