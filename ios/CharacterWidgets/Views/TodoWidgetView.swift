//
//  TodoWidgetView.swift
//  CharacterWidgets
//
//  ToDoウィジェットのビュー
//

import SwiftUI
import WidgetKit

// MARK: - Entry View

struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodoWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            TodoWidgetSmallView(entry: entry)
        case .systemMedium:
            TodoWidgetMediumView(entry: entry)
        case .systemLarge:
            TodoWidgetLargeView(entry: entry)
        @unknown default:
            TodoWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Small View

struct TodoWidgetSmallView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "E8F5FF"), Color(hex: "D0E8FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                // ヘッダー
                HStack {
                    Text("✓")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    Text("ToDo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(entry.todos.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // 次のToDo
                if let todo = entry.todos.first {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(priorityColor(todo.priority))
                                .frame(width: 8, height: 8)
                            Text(todo.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .minimumScaleFactor(0.85)
                        }

                        Spacer(minLength: 0)

                        if let dueDate = todo.dueDate {
                            HStack {
                                Text("📅")
                                    .font(.system(size: 10))
                                Text(todo.dueDateText)
                                    .font(.system(size: 11))
                                    .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 12)
                } else {
                    Spacer()
                    Text("すべて完了！")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("🎉")
                        .font(.system(size: 30))
                    Spacer()
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func priorityColor(_ priority: TodoPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
}

// MARK: - Medium View

struct TodoWidgetMediumView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "E8F5FF"), Color(hex: "D0E8FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                // ヘッダー
                HStack {
                    Text("✓")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    Text("ToDo")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(entry.todos.count)件")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // ToDoリスト
                if entry.todos.isEmpty {
                    Spacer()
                    Text("すべて完了！")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("🎉")
                        .font(.system(size: 30))
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entry.todos.prefix(4)) { todo in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(priorityColor(todo.priority))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(todo.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)

                                    if let dueDate = todo.dueDate {
                                        HStack(spacing: 4) {
                                            Text("📅")
                                                .font(.system(size: 9))
                                            Text(todo.dueDateText)
                                                .font(.system(size: 10))
                                                .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)

                            if todo.id != entry.todos.prefix(4).last?.id {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func priorityColor(_ priority: TodoPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
}

// MARK: - Large View

struct TodoWidgetLargeView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "E8F5FF"), Color(hex: "D0E8FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                // ヘッダー
                HStack {
                    Text("✓")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    Text("ToDo")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(entry.todos.count)件")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // ToDoリスト
                if entry.todos.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("🎉")
                            .font(.system(size: 40))
                        Text("すべて完了！")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Text("お疲れ様でした")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    // 優先度別セクション
                    VStack(alignment: .leading, spacing: 6) {
                        let highPriority = entry.todos.filter { $0.priority == .high }
                        let mediumPriority = entry.todos.filter { $0.priority == .medium }
                        let lowPriority = entry.todos.filter { $0.priority == .low }

                        if !highPriority.isEmpty {
                            PrioritySection(title: "高", color: .red, todos: Array(highPriority.prefix(3)))
                        }

                        if !mediumPriority.isEmpty {
                            PrioritySection(title: "中", color: .orange, todos: Array(mediumPriority.prefix(3)))
                        }

                        if !lowPriority.isEmpty {
                            PrioritySection(title: "低", color: .green, todos: Array(lowPriority.prefix(3)))
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 12)

                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Priority Section

struct PrioritySection: View {
    let title: String
    let color: Color
    let todos: [WidgetTodo]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text("優先度: \(title)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            ForEach(todos) { todo in
                HStack(alignment: .top, spacing: 6) {
                    Text("・")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(todo.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        if let dueDate = todo.dueDate {
                            HStack(spacing: 3) {
                                Text("📅")
                                    .font(.system(size: 8))
                                Text(todo.dueDateText)
                                    .font(.system(size: 9))
                                    .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
}
