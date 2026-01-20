import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/todo_datasource.dart';
import '../../data/models/todo_model.dart';
import 'auth_provider.dart';

/// TodoDatasourceのプロバイダー
final todoDatasourceProvider = Provider<TodoDatasource>((ref) {
  return TodoDatasource(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Todoリストのストリームプロバイダー
final todosProvider = StreamProvider<List<TodoModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final datasource = ref.watch(todoDatasourceProvider);
  return datasource.watchTodos(userId: userId);
});

/// Todoフィルター
enum TodoFilter {
  all('すべて'),
  incomplete('未完了'),
  completed('完了済み');

  final String displayName;
  const TodoFilter(this.displayName);
}

/// 選択中のフィルター
final todoFilterProvider = StateProvider<TodoFilter>((ref) => TodoFilter.all);

/// フィルター済みTodoリスト
final filteredTodosProvider = Provider<AsyncValue<List<TodoModel>>>((ref) {
  final todosAsync = ref.watch(todosProvider);
  final filter = ref.watch(todoFilterProvider);

  return todosAsync.when(
    data: (todos) {
      final filtered = switch (filter) {
        TodoFilter.all => todos,
        TodoFilter.incomplete => todos.where((t) => !t.isCompleted).toList(),
        TodoFilter.completed => todos.where((t) => t.isCompleted).toList(),
      };
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Todo統計
class TodoStats {
  final int total;
  final int incomplete;
  final int completed;
  final int overdue;

  TodoStats({
    required this.total,
    required this.incomplete,
    required this.completed,
    required this.overdue,
  });

  factory TodoStats.fromTodos(List<TodoModel> todos) {
    return TodoStats(
      total: todos.length,
      incomplete: todos.where((t) => !t.isCompleted).length,
      completed: todos.where((t) => t.isCompleted).length,
      overdue: todos.where((t) => t.isOverdue).length,
    );
  }
}

/// Todo統計プロバイダー
final todoStatsProvider = Provider<AsyncValue<TodoStats>>((ref) {
  final todosAsync = ref.watch(todosProvider);
  return todosAsync.when(
    data: (todos) => AsyncValue.data(TodoStats.fromTodos(todos)),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Todoコントローラー
class TodoController extends StateNotifier<AsyncValue<void>> {
  final TodoDatasource _datasource;
  final Ref _ref;

  TodoController(this._datasource, this._ref) : super(const AsyncValue.data(null));

  /// Todoを追加
  Future<void> addTodo(TodoModel todo) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.addTodo(
        userId: userId,
        todo: todo,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Todoを更新
  Future<void> updateTodo(TodoModel todo) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    try {
      await _datasource.updateTodo(
        userId: userId,
        todo: todo,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Todoの完了状態を切り替え
  Future<void> toggleComplete(String todoId, bool isCompleted) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _datasource.toggleTodoComplete(
        userId: userId,
        todoId: todoId,
        isCompleted: isCompleted,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Todoを削除
  Future<void> deleteTodo(String todoId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _datasource.deleteTodo(
        userId: userId,
        todoId: todoId,
      );
    } catch (e) {
      rethrow;
    }
  }
}

/// Todoコントローラーのプロバイダー
final todoControllerProvider =
    StateNotifierProvider<TodoController, AsyncValue<void>>((ref) {
  return TodoController(
    ref.watch(todoDatasourceProvider),
    ref,
  );
});
