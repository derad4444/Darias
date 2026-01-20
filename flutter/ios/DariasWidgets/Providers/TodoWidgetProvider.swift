//
//  TodoWidgetProvider.swift
//  DariasWidgets
//

import WidgetKit
import SwiftUI

struct TodoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            todos: [
                WidgetTodo(id: "1", title: "サンプルタスク", priority: "high", dueDate: Date()),
                WidgetTodo(id: "2", title: "もう一つのタスク", priority: "medium", dueDate: nil)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let todos = WidgetDataCache.shared.loadTodos()
        let entry = TodoWidgetEntry(date: Date(), todos: todos)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let todos = WidgetDataCache.shared.loadTodos()
        let entry = TodoWidgetEntry(date: Date(), todos: todos)

        // 15分ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}
