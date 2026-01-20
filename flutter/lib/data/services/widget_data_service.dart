import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/memo_model.dart';
import '../models/schedule_model.dart';
import '../models/todo_model.dart';

/// ウィジェット用のスケジュールデータ
class WidgetSchedule {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final bool isAllDay;

  WidgetSchedule({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.location,
    required this.isAllDay,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'location': location,
        'isAllDay': isAllDay,
      };
}

/// ウィジェット用のメモデータ
class WidgetMemo {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;
  final String tag;
  final bool isPinned;

  WidgetMemo({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.tag,
    required this.isPinned,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'tag': tag,
        'isPinned': isPinned,
      };
}

/// ウィジェット用のToDoデータ
class WidgetTodo {
  final String id;
  final String title;
  final String priority;
  final DateTime? dueDate;

  WidgetTodo({
    required this.id,
    required this.title,
    required this.priority,
    this.dueDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
      };
}

/// ウィジェット用のBIG5進捗データ
class WidgetBig5Progress {
  final int answered;
  final int total;

  WidgetBig5Progress({
    required this.answered,
    this.total = 100,
  });

  Map<String, dynamic> toJson() => {
        'answered': answered,
        'total': total,
      };
}

/// ウィジェットデータサービス
/// メインアプリとホーム画面ウィジェット間でデータを共有
class WidgetDataService {
  static final WidgetDataService shared = WidgetDataService._();

  // App Group ID (iOS) / SharedPreferences (Android)
  static const String _appGroupId = 'group.com.derad.Character';

  // Widget名
  static const String _calendarWidgetName = 'CalendarWidget';
  static const String _memoWidgetName = 'MemoWidget';
  static const String _todoWidgetName = 'TodoWidget';
  static const String _big5WidgetName = 'Big5ProgressWidget';

  // キャッシュキー
  static const String _schedulesKey = 'widget_schedules_cache';
  static const String _memosKey = 'widget_memos_cache';
  static const String _memosTotalCountKey = 'widget_memos_total_count';
  static const String _todosKey = 'widget_todos_cache';
  static const String _big5ProgressKey = 'widget_big5_progress';
  static const String _lastUpdateKey = 'widget_last_update';

  WidgetDataService._();

  /// 初期化
  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  // MARK: - Schedule Caching

  /// スケジュールをウィジェット用にキャッシュ
  Future<void> cacheSchedules(List<ScheduleModel> schedules) async {
    debugPrint('📅 [WidgetDataService] cacheSchedules called with ${schedules.length} schedules');

    // 過去30日〜未来のスケジュールのみキャッシュ
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final widgetSchedules = schedules
        .where((s) => s.startDate.isAfter(thirtyDaysAgo))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final limitedSchedules = widgetSchedules.take(50).map((schedule) {
      return WidgetSchedule(
        id: schedule.id,
        title: schedule.title,
        startDate: schedule.startDate,
        endDate: schedule.endDate,
        location: schedule.location.isEmpty ? null : schedule.location,
        isAllDay: schedule.isAllDay,
      );
    }).toList();

    debugPrint('📅 [WidgetDataService] Filtered to ${limitedSchedules.length} widget schedules');

    final encoded = jsonEncode(limitedSchedules.map((s) => s.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(_schedulesKey, encoded);
    await HomeWidget.saveWidgetData<String>(
      _lastUpdateKey,
      DateTime.now().toIso8601String(),
    );

    // カレンダーウィジェットを更新
    await HomeWidget.updateWidget(
      name: _calendarWidgetName,
      iOSName: _calendarWidgetName,
      androidName: _calendarWidgetName,
    );

    debugPrint('📅 [WidgetDataService] Successfully cached schedules');
  }

  // MARK: - Memo Caching

  /// メモをウィジェット用にキャッシュ
  Future<void> cacheMemos(List<MemoModel> memos) async {
    debugPrint('📝 [WidgetDataService] cacheMemos called with ${memos.length} memos');

    // ピン留め優先、次に更新日時順
    final sortedMemos = List<MemoModel>.from(memos)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final widgetMemos = sortedMemos.take(10).map((memo) {
      return WidgetMemo(
        id: memo.id,
        title: memo.title,
        content: memo.content,
        updatedAt: memo.updatedAt,
        tag: memo.tag,
        isPinned: memo.isPinned,
      );
    }).toList();

    final encoded = jsonEncode(widgetMemos.map((m) => m.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(_memosKey, encoded);
    await HomeWidget.saveWidgetData<int>(_memosTotalCountKey, memos.length);

    // メモウィジェットを更新
    await HomeWidget.updateWidget(
      name: _memoWidgetName,
      iOSName: _memoWidgetName,
      androidName: _memoWidgetName,
    );

    debugPrint('✅ [WidgetDataService] Successfully cached ${widgetMemos.length} memos');
  }

  // MARK: - Todo Caching

  /// ToDoをウィジェット用にキャッシュ
  Future<void> cacheTodos(List<TodoModel> todos) async {
    debugPrint('✅ [WidgetDataService] cacheTodos called with ${todos.length} todos');

    // 未完了のみ、優先度順→期日順
    final incompleteTodos = todos.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        final priorityA = _priorityOrder(a.priority);
        final priorityB = _priorityOrder(b.priority);
        if (priorityA != priorityB) {
          return priorityB.compareTo(priorityA);
        }
        final dateA = a.dueDate ?? DateTime(9999);
        final dateB = b.dueDate ?? DateTime(9999);
        return dateA.compareTo(dateB);
      });

    final widgetTodos = incompleteTodos.take(10).map((todo) {
      return WidgetTodo(
        id: todo.id,
        title: todo.title,
        priority: todo.priority.name,
        dueDate: todo.dueDate,
      );
    }).toList();

    final encoded = jsonEncode(widgetTodos.map((t) => t.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(_todosKey, encoded);

    // ToDoウィジェットを更新
    await HomeWidget.updateWidget(
      name: _todoWidgetName,
      iOSName: _todoWidgetName,
      androidName: _todoWidgetName,
    );

    debugPrint('✅ [WidgetDataService] Successfully cached ${widgetTodos.length} todos');
  }

  int _priorityOrder(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return 3;
      case TodoPriority.medium:
        return 2;
      case TodoPriority.low:
        return 1;
    }
  }

  // MARK: - Big5 Progress Caching

  /// Big5進捗をウィジェット用にキャッシュ
  Future<void> cacheBig5Progress({
    required int answeredCount,
    int totalCount = 100,
  }) async {
    final progress = WidgetBig5Progress(
      answered: answeredCount,
      total: totalCount,
    );

    final encoded = jsonEncode(progress.toJson());
    await HomeWidget.saveWidgetData<String>(_big5ProgressKey, encoded);

    // Big5進捗ウィジェットを更新
    await HomeWidget.updateWidget(
      name: _big5WidgetName,
      iOSName: _big5WidgetName,
      androidName: _big5WidgetName,
    );

    debugPrint('🧠 [WidgetDataService] Successfully cached Big5 progress: $answeredCount/$totalCount');
  }

  // MARK: - Reload All Widgets

  /// 全てのウィジェットをリロード
  Future<void> reloadAllWidgets() async {
    await HomeWidget.updateWidget(
      name: _calendarWidgetName,
      iOSName: _calendarWidgetName,
      androidName: _calendarWidgetName,
    );
    await HomeWidget.updateWidget(
      name: _memoWidgetName,
      iOSName: _memoWidgetName,
      androidName: _memoWidgetName,
    );
    await HomeWidget.updateWidget(
      name: _todoWidgetName,
      iOSName: _todoWidgetName,
      androidName: _todoWidgetName,
    );
    await HomeWidget.updateWidget(
      name: _big5WidgetName,
      iOSName: _big5WidgetName,
      androidName: _big5WidgetName,
    );

    debugPrint('🔄 [WidgetDataService] Reloaded all widgets');
  }

  /// ウィジェットからのインタラクションを処理
  Future<void> handleWidgetAction(Uri? uri) async {
    if (uri == null) return;

    debugPrint('🔗 [WidgetDataService] Widget action: $uri');

    // URIに基づいてアクションを処理
    // 例: darias://widget/todo/123 → Todo詳細画面へ遷移
    // 実際のナビゲーションはアプリのルーターで処理
  }

  /// ウィジェットアクションのストリームを取得
  Stream<Uri?> get widgetActionStream => HomeWidget.widgetClicked;
}
