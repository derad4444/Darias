//
//  TodoWidget.swift
//  CharacterWidgets
//
//  ToDoウィジェットの定義
//

import WidgetKit
import SwiftUI

struct TodoWidget: Widget {
    let kind: String = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                TodoWidgetEntryView(entry: entry)
                    .environment(\.colorScheme, .light)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TodoWidgetEntryView(entry: entry)
                    .environment(\.colorScheme, .light)
            }
        }
        .configurationDisplayName("DARIAS ToDo")
        .description("未完了のタスクを確認できます")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    TodoWidget()
} timeline: {
    let sampleTodo = WidgetTodo(
        id: "1",
        title: "重要なタスク",
        priority: .high,
        dueDate: Date().addingTimeInterval(86400)
    )

    TodoWidgetEntry(
        date: Date(),
        todos: [sampleTodo]
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    TodoWidget()
} timeline: {
    let todos = [
        WidgetTodo(
            id: "1",
            title: "重要なタスク",
            priority: .high,
            dueDate: Date().addingTimeInterval(86400)
        ),
        WidgetTodo(
            id: "2",
            title: "ミーティングの準備",
            priority: .medium,
            dueDate: Date().addingTimeInterval(172800)
        ),
        WidgetTodo(
            id: "3",
            title: "買い物",
            priority: .low,
            dueDate: nil
        )
    ]

    TodoWidgetEntry(
        date: Date(),
        todos: todos
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    TodoWidget()
} timeline: {
    let todos = [
        WidgetTodo(
            id: "1",
            title: "緊急タスク",
            priority: .high,
            dueDate: Date().addingTimeInterval(86400)
        ),
        WidgetTodo(
            id: "2",
            title: "プロジェクト進行",
            priority: .high,
            dueDate: Date().addingTimeInterval(172800)
        ),
        WidgetTodo(
            id: "3",
            title: "ミーティング準備",
            priority: .medium,
            dueDate: Date().addingTimeInterval(259200)
        ),
        WidgetTodo(
            id: "4",
            title: "レポート作成",
            priority: .medium,
            dueDate: Date().addingTimeInterval(345600)
        ),
        WidgetTodo(
            id: "5",
            title: "買い物",
            priority: .low,
            dueDate: nil
        )
    ]

    TodoWidgetEntry(
        date: Date(),
        todos: todos
    )
}
