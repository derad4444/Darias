import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/todo_model.dart';

/// Todo関連のリモートデータソース
class TodoDatasource {
  final FirebaseFirestore _firestore;

  TodoDatasource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Todoリストをリアルタイムで取得
  Stream<List<TodoModel>> watchTodos({
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TodoModel.fromFirestore(doc)).toList();
    });
  }

  /// Todoを追加
  Future<String> addTodo({
    required String userId,
    required TodoModel todo,
  }) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .add(todo.toMap());
    return docRef.id;
  }

  /// Todoを更新
  Future<void> updateTodo({
    required String userId,
    required TodoModel todo,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .doc(todo.id)
        .update(todo.copyWith(updatedAt: DateTime.now()).toMap());
  }

  /// Todoの完了状態を切り替え
  Future<void> toggleTodoComplete({
    required String userId,
    required String todoId,
    required bool isCompleted,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .doc(todoId)
        .update({
      'isCompleted': isCompleted,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Todoを削除
  Future<void> deleteTodo({
    required String userId,
    required String todoId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .doc(todoId)
        .delete();
  }
}
