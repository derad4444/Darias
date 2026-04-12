import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/memo_model.dart';
import '../models/schedule_model.dart';
import '../models/todo_model.dart';
import '../../utils/memo_content_utils.dart';

/// ウィジェット用のスケジュールデータ
class WidgetSchedule {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final bool isAllDay;
  final String? colorHex;

  WidgetSchedule({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.location,
    required this.isAllDay,
    this.colorHex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'location': location,
        'isAllDay': isAllDay,
        'colorHex': colorHex,
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
  final String? colorHex;

  WidgetMemo({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.tag,
    required this.isPinned,
    this.colorHex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'tag': tag,
        'isPinned': isPinned,
        'colorHex': colorHex,
      };
}

/// ウィジェット用のToDoデータ
class WidgetTodo {
  final String id;
  final String title;
  final String priority;
  final DateTime? dueDate;
  final String? colorHex;
  final String tag;

  WidgetTodo({
    required this.id,
    required this.title,
    required this.priority,
    this.dueDate,
    this.colorHex,
    this.tag = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'colorHex': colorHex,
        'tag': tag,
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

  // Widget名（Android: AndroidManifestのreceiver android:nameと一致、iOS: Widgetのkind文字列と一致）
  static const String _calendarWidgetAndroidName = 'CalendarWidgetProvider';
  static const String _calendarWidgetIosName = 'CalendarWidget';
  static const String _calendarGridWidgetAndroidName = 'CalendarGridWidgetProvider';
  static const String _calendarGridWidgetIosName = 'CalendarGridWidget';
  static const String _memoWidgetAndroidName = 'MemoWidgetProvider';
  static const String _memoWidgetIosName = 'MemoWidget';
  static const String _todoWidgetAndroidName = 'TodoWidgetProvider';
  static const String _todoWidgetIosName = 'TodoWidget';
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
    if (kIsWeb) return;
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  // MARK: - Schedule Caching

  /// スケジュールをウィジェット用にキャッシュ
  Future<void> cacheSchedules(List<ScheduleModel> schedules, {Map<String, String> tagColors = const {}}) async {
    if (kIsWeb) return;
    debugPrint('📅 [WidgetDataService] cacheSchedules called with ${schedules.length} schedules');

    // 過去30日〜未来のスケジュールのみキャッシュ
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final widgetSchedules = schedules
        .where((s) => s.startDate.isAfter(thirtyDaysAgo))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final limitedSchedules = widgetSchedules.take(50).map((schedule) {
      final colorHex = schedule.tag.isNotEmpty ? tagColors[schedule.tag] : null;
      return WidgetSchedule(
        id: schedule.id,
        title: schedule.title,
        startDate: schedule.startDate,
        endDate: schedule.endDate,
        location: schedule.location.isEmpty ? null : schedule.location,
        isAllDay: schedule.isAllDay,
        colorHex: colorHex,
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
      iOSName: _calendarWidgetIosName,
      androidName: _calendarWidgetAndroidName,
    );
    await HomeWidget.updateWidget(
      iOSName: _calendarGridWidgetIosName,
      androidName: _calendarGridWidgetAndroidName,
    );

    debugPrint('📅 [WidgetDataService] Successfully cached schedules');
  }

  // MARK: - Memo Caching

  /// メモをウィジェット用にキャッシュ（showInWidget==trueのメモのみ）
  Future<void> cacheMemos(List<MemoModel> memos, {Map<String, String> tagColors = const {}}) async {
    if (kIsWeb) return;
    debugPrint('📝 [WidgetDataService] cacheMemos called with ${memos.length} memos');

    // ウィジェット表示フラグが立っているメモのみ対象
    final widgetTargetMemos = memos.where((m) => m.showInWidget).toList();

    // ピン留め優先、次に更新日時順
    widgetTargetMemos.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    final widgetMemos = widgetTargetMemos.map((memo) {
      return WidgetMemo(
        id: memo.id,
        title: memo.title,
        content: extractPlainText(memo.content),
        updatedAt: memo.updatedAt,
        tag: memo.tag,
        isPinned: memo.isPinned,
        colorHex: memo.tag.isNotEmpty ? tagColors[memo.tag] : null,
      );
    }).toList();

    final encoded = jsonEncode(widgetMemos.map((m) => m.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(_memosKey, encoded);
    await HomeWidget.saveWidgetData<int>(_memosTotalCountKey, widgetTargetMemos.length);

    // メモウィジェットを更新
    await HomeWidget.updateWidget(
      iOSName: _memoWidgetIosName,
      androidName: _memoWidgetAndroidName,
    );

    debugPrint('✅ [WidgetDataService] Successfully cached ${widgetMemos.length} memos');
  }

  // MARK: - Todo Caching

  /// ToDoをウィジェット用にキャッシュ
  Future<void> cacheTodos(List<TodoModel> todos, {Map<String, String> tagColors = const {}}) async {
    if (kIsWeb) return;
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
        colorHex: todo.tag.isNotEmpty ? tagColors[todo.tag] : null,
        tag: todo.tag,
      );
    }).toList();

    final encoded = jsonEncode(widgetTodos.map((t) => t.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(_todosKey, encoded);

    // ToDoウィジェットを更新
    await HomeWidget.updateWidget(
      iOSName: _todoWidgetIosName,
      androidName: _todoWidgetAndroidName,
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
    if (kIsWeb) return;
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
      iOSName: _calendarWidgetIosName,
      androidName: _calendarWidgetAndroidName,
    );
    await HomeWidget.updateWidget(
      iOSName: _memoWidgetIosName,
      androidName: _memoWidgetAndroidName,
    );
    await HomeWidget.updateWidget(
      iOSName: _todoWidgetIosName,
      androidName: _todoWidgetAndroidName,
    );
    await HomeWidget.updateWidget(
      iOSName: _big5WidgetName,
      androidName: _big5WidgetName,
    );
    await HomeWidget.updateWidget(
      iOSName: _calendarGridWidgetIosName,
      androidName: _calendarGridWidgetAndroidName,
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
