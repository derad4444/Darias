import 'package:cloud_firestore/cloud_firestore.dart';

/// メモモデル
class MemoModel {
  final String id;
  final String title;
  final String content;
  final String tag;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoModel({
    required this.id,
    required this.title,
    this.content = '',
    this.tag = '',
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return MemoModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      tag: data['tag'] as String? ?? '',
      isPinned: data['isPinned'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'tag': tag,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MemoModel copyWith({
    String? id,
    String? title,
    String? content,
    String? tag,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tag: tag ?? this.tag,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 新規作成用ファクトリ
  factory MemoModel.create({
    required String title,
    String content = '',
    String tag = '',
    bool isPinned = false,
  }) {
    final now = DateTime.now();
    return MemoModel(
      id: '',
      title: title,
      content: content,
      tag: tag,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );
  }
}
