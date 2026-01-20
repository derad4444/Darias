import 'package:cloud_firestore/cloud_firestore.dart';

/// Todo優先度
enum TodoPriority {
  low('低', 'gray'),
  medium('中', 'blue'),
  high('高', 'red');

  final String displayName;
  final String colorName;

  const TodoPriority(this.displayName, this.colorName);

  static TodoPriority fromString(String value) {
    return TodoPriority.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => TodoPriority.medium,
    );
  }
}

/// Todoアイテムモデル
class TodoModel {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String tag;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodoModel({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.dueDate,
    this.priority = TodoPriority.medium,
    this.tag = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// 期限切れかどうか
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  factory TodoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return TodoModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      isCompleted: data['isCompleted'] as bool? ?? false,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      priority: TodoPriority.fromString(data['priority'] as String? ?? '中'),
      tag: data['tag'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'priority': priority.displayName,
      'tag': tag,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TodoModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    TodoPriority? priority,
    String? tag,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      tag: tag ?? this.tag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 新規作成用ファクトリ
  factory TodoModel.create({
    required String title,
    String description = '',
    DateTime? dueDate,
    TodoPriority priority = TodoPriority.medium,
    String tag = '',
  }) {
    final now = DateTime.now();
    return TodoModel(
      id: '',
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      tag: tag,
      createdAt: now,
      updatedAt: now,
    );
  }
}
