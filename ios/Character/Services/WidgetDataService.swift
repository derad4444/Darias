//
//  WidgetDataService.swift
//  Character
//
//  メインアプリ側でウィジェット用のデータをキャッシュするサービス
//

import Foundation
import WidgetKit

class WidgetDataService {
    static let shared = WidgetDataService()

    private let sharedDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName)

    private init() {}

    // MARK: - Schedule Caching

    /// スケジュールをウィジェット用にキャッシュ
    /// - Parameter schedules: メインアプリのSchedule配列
    func cacheSchedules(_ schedules: [Schedule]) {
        print("📅 [WidgetDataService] cacheSchedules called with \(schedules.count) schedules")

        // 過去30日〜未来のスケジュールのみキャッシュ（パフォーマンス対策）
        let thirtyDaysAgo = Date().addingTimeInterval(-86400 * 30)

        let widgetSchedules = schedules
            .filter { $0.startDate >= thirtyDaysAgo }
            .sorted { $0.startDate < $1.startDate }
            .prefix(50) // 最大50件
            .map { schedule in
                WidgetSchedule(
                    id: schedule.id,
                    title: schedule.title,
                    startDate: schedule.startDate,
                    endDate: schedule.endDate,
                    location: schedule.location.isEmpty ? nil : schedule.location,
                    isAllDay: schedule.isAllDay
                )
            }

        print("📅 [WidgetDataService] Filtered to \(widgetSchedules.count) widget schedules")

        if let encoded = try? JSONEncoder().encode(Array(widgetSchedules)) {
            sharedDefaults?.set(encoded, forKey: AppGroupConstants.schedulesCacheKey)
            sharedDefaults?.set(Date(), forKey: AppGroupConstants.lastUpdateKey)
            print("📅 [WidgetDataService] Successfully saved to UserDefaults with key: \(AppGroupConstants.schedulesCacheKey)")
            print("📅 [WidgetDataService] App Group: \(AppGroupConstants.suiteName)")

            // カレンダーウィジェットをリロード
            WidgetCenter.shared.reloadTimelines(ofKind: "CalendarWidget")
        } else {
            print("❌ [WidgetDataService] Failed to encode schedules")
        }
    }

    // MARK: - Memo Caching

    /// メモをウィジェット用にキャッシュ
    /// - Parameter memos: メインアプリのMemo配列
    func cacheMemos(_ memos: [Memo]) {
        print("📝 [WidgetDataService] cacheMemos called with \(memos.count) memos")
        let widgetMemos = memos
            .sorted { memo1, memo2 in
                // ピン留め優先、次に更新日時順
                if memo1.isPinned != memo2.isPinned {
                    return memo1.isPinned
                }
                return memo1.updatedAt > memo2.updatedAt
            }
            .prefix(10) // 最大10件
            .map { memo in
                WidgetMemo(
                    id: memo.id,
                    title: memo.title,
                    content: memo.content,
                    updatedAt: memo.updatedAt,
                    tag: memo.tag,
                    isPinned: memo.isPinned
                )
            }

        if let encoded = try? JSONEncoder().encode(Array(widgetMemos)) {
            sharedDefaults?.set(encoded, forKey: AppGroupConstants.memosCacheKey)
            sharedDefaults?.set(memos.count, forKey: AppGroupConstants.memosTotalCountKey)
            print("✅ [WidgetDataService] Successfully cached \(widgetMemos.count) memos")

            // メモウィジェットをリロード
            WidgetCenter.shared.reloadTimelines(ofKind: "MemoWidget")
        } else {
            print("❌ [WidgetDataService] Failed to encode memos")
        }
    }

    // MARK: - Todo Caching

    /// ToDoをウィジェット用にキャッシュ
    /// - Parameter todos: メインアプリのTodoItem配列
    func cacheTodos(_ todos: [TodoItem]) {
        print("✅ [WidgetDataService] cacheTodos called with \(todos.count) todos")
        let widgetTodos = todos
            .filter { !$0.isCompleted } // 未完了のみ
            .sorted { (todo1: TodoItem, todo2: TodoItem) -> Bool in
                // 優先度順 → 期日順
                let priority1Order = self.priorityOrder(todo1.priority)
                let priority2Order = self.priorityOrder(todo2.priority)

                if priority1Order != priority2Order {
                    return priority1Order > priority2Order
                }
                return (todo1.dueDate ?? .distantFuture) < (todo2.dueDate ?? .distantFuture)
            }
            .prefix(10) // 最大10件
            .map { todo in
                // TodoItem.priority → WidgetTodo.priority に変換
                let widgetPriority: TodoPriority
                switch todo.priority {
                case .high:
                    widgetPriority = .high
                case .medium:
                    widgetPriority = .medium
                case .low:
                    widgetPriority = .low
                }

                return WidgetTodo(
                    id: todo.id,
                    title: todo.title,
                    priority: widgetPriority,
                    dueDate: todo.dueDate
                )
            }

        if let encoded = try? JSONEncoder().encode(Array(widgetTodos)) {
            sharedDefaults?.set(encoded, forKey: AppGroupConstants.todosCacheKey)
            print("✅ [WidgetDataService] Successfully cached \(widgetTodos.count) todos")

            // ToDoウィジェットをリロード
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
        } else {
            print("❌ [WidgetDataService] Failed to encode todos")
        }
    }

    // MARK: - Helper Methods

    /// 優先度のソート順を返す（高い方が大きい値）
    private func priorityOrder(_ priority: TodoItem.TodoPriority) -> Int {
        switch priority {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    // MARK: - Big5 Progress Caching

    /// Big5進捗をウィジェット用にキャッシュ
    /// - Parameters:
    ///   - answeredCount: 回答済み問題数
    ///   - totalCount: 総問題数（通常100）
    func cacheBig5Progress(answeredCount: Int, totalCount: Int = 100) {
        let progress = WidgetBig5Progress(answered: answeredCount, total: totalCount)

        if let encoded = try? JSONEncoder().encode(progress) {
            sharedDefaults?.set(encoded, forKey: AppGroupConstants.big5ProgressKey)

            // Big5進捗ウィジェットをリロード
            WidgetCenter.shared.reloadTimelines(ofKind: "Big5ProgressWidget")
        }
    }

    // MARK: - Reload All Widgets

    /// 全てのウィジェットをリロード
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
