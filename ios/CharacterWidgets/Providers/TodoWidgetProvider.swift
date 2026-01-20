//
//  TodoWidgetProvider.swift
//  CharacterWidgets
//
//  ToDoウィジェット用のTimelineProvider
//

import WidgetKit
import SwiftUI

struct TodoWidgetProvider: TimelineProvider {

    // MARK: - Placeholder

    func placeholder(in context: Context) -> TodoWidgetEntry {
        let sampleTodos = [
            WidgetTodo(
                id: "1",
                title: "サンプルタスク",
                priority: .high,
                dueDate: Date().addingTimeInterval(86400)
            )
        ]

        return TodoWidgetEntry(
            date: Date(),
            todos: sampleTodos
        )
    }

    // MARK: - Snapshot

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let todos = WidgetDataCache.shared.getTodos()
        let entry = TodoWidgetEntry(
            date: Date(),
            todos: todos
        )
        completion(entry)
    }

    // MARK: - Timeline

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let todos = WidgetDataCache.shared.getTodos()
        let currentDate = Date()

        let entry = TodoWidgetEntry(
            date: currentDate,
            todos: todos
        )

        // 15分ごとに更新
        let calendar = Calendar.current
        let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
