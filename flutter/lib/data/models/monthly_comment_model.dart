import 'package:cloud_firestore/cloud_firestore.dart';

/// iOS版の月次コメントモデル
class MonthlyCommentModel {
  final String id; // "YYYY-MM"形式
  final String comment;
  final DateTime? createdAt;

  MonthlyCommentModel({
    required this.id,
    required this.comment,
    this.createdAt,
  });

  factory MonthlyCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MonthlyCommentModel(
      id: doc.id,
      comment: data['comment'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'comment': comment,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// デフォルトのメッセージ
  static String get defaultComment =>
      '今月もあなたらしく、素敵な時間を過ごしてくださいね！新しい発見や楽しい出来事があることを願っています。';
}
