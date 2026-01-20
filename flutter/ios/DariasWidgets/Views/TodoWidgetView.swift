//
//  TodoWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import WidgetKit

struct TodoWidgetView: View {
    var entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodoView(entry: entry)
        case .systemMedium:
            MediumTodoView(entry: entry)
        default:
            SmallTodoView(entry: entry)
        }
    }
}

struct SmallTodoView: View {
    var entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Todo")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            if entry.todos.isEmpty {
                Spacer()
                Text("タスクなし")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ForEach(entry.todos.prefix(3)) { todo in
                    HStack(spacing: 4) {
                        Text(todo.priorityIcon)
                            .font(.caption2)
                        Text(todo.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumTodoView: View {
    var entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                Text("Todo")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(entry.todos.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if entry.todos.isEmpty {
                HStack {
                    Spacer()
                    Text("タスクなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical)
            } else {
                ForEach(entry.todos.prefix(4)) { todo in
                    HStack {
                        Text(todo.priorityIcon)
                            .font(.caption)
                        Text(todo.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(todo.dueDateText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
