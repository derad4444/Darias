//
//  TodoWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import UIKit
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
        case .systemLarge:
            LargeTodoView(entry: entry)
        default:
            SmallTodoView(entry: entry)
        }
    }
}

// MARK: - Small

struct SmallTodoView: View {
    var entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(uiImage: UIImage(contentsOfFile: Bundle.main.path(forResource: "DariasIcon", ofType: "png") ?? "") ?? UIImage())
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("Todo")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
            }

            if entry.todos.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(WidgetColors.accentGradient)
                    Text("タスクなし")
                        .font(.caption2)
                        .foregroundColor(WidgetColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.todos.prefix(3)) { todo in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(WidgetColors.accentGradient)
                            .frame(width: 6, height: 6)
                        Text(todo.title)
                            .font(.caption)
                            .foregroundColor(WidgetColors.textPrimary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=todo&homeWidget"))
    }
}

// MARK: - Medium

struct MediumTodoView: View {
    var entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(uiImage: UIImage(contentsOfFile: Bundle.main.path(forResource: "DariasIcon", ofType: "png") ?? "") ?? UIImage())
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("Todo")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
                Text("\(entry.todos.count)件")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WidgetColors.primaryPink.opacity(0.15))
                    .foregroundColor(WidgetColors.primaryPink)
                    .clipShape(Capsule())
            }

            if entry.todos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WidgetColors.accentGradient)
                        Text("タスクなし")
                            .font(.caption)
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(entry.todos.prefix(4)) { todo in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(WidgetColors.accentGradient)
                            .frame(width: 7, height: 7)
                        Text(todo.title)
                            .font(.subheadline)
                            .foregroundColor(WidgetColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(todo.dueDateText)
                            .font(.caption2)
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=todo&homeWidget"))
    }
}

// MARK: - Large

struct LargeTodoView: View {
    var entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(uiImage: UIImage(contentsOfFile: Bundle.main.path(forResource: "DariasIcon", ofType: "png") ?? "") ?? UIImage())
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Todo")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
                Text("\(entry.todos.count)件")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WidgetColors.primaryPink.opacity(0.15))
                    .foregroundColor(WidgetColors.primaryPink)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 10)

            if entry.todos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(WidgetColors.accentGradient)
                        Text("タスクなし")
                            .font(.subheadline)
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(entry.todos.prefix(8)) { todo in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(WidgetColors.accentGradient)
                                .frame(width: 8, height: 8)
                            Text(todo.title)
                                .font(.subheadline)
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(todo.dueDateText)
                                .font(.caption2)
                                .foregroundColor(WidgetColors.textSecondary)
                        }
                        .padding(.vertical, 7)
                        Divider()
                            .background(WidgetColors.primaryPink.opacity(0.2))
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=todo&homeWidget"))
    }
}
