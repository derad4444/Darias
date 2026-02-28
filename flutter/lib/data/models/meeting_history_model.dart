import 'package:cloud_firestore/cloud_firestore.dart';

/// 会議履歴モデル（iOS版MeetingHistoryと同じ構造）
class MeetingHistoryModel {
  final String id;
  final String sharedMeetingId;
  final String userConcern;
  final String concernCategory;
  final bool cacheHit;
  final DateTime createdAt;

  const MeetingHistoryModel({
    required this.id,
    required this.sharedMeetingId,
    required this.userConcern,
    required this.concernCategory,
    required this.cacheHit,
    required this.createdAt,
  });

  factory MeetingHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return MeetingHistoryModel(
      id: doc.id,
      sharedMeetingId: data['sharedMeetingId'] as String? ?? '',
      userConcern: data['userConcern'] as String? ?? '',
      concernCategory: data['concernCategory'] as String? ?? 'other',
      cacheHit: data['cacheHit'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// カテゴリの表示名を取得
  String get categoryDisplayName {
    const categoryNames = {
      'career': 'キャリア・仕事',
      'romance': '恋愛・人間関係',
      'money': 'お金・経済',
      'health': '健康・ライフスタイル',
      'family': '家族・子育て',
      'future': '将来・人生設計',
      'hobby': '趣味・自己実現',
      'study': '学習・スキル',
      'moving': '引っ越し・住居',
      'other': 'その他',
    };
    return categoryNames[concernCategory] ?? 'その他';
  }
}
