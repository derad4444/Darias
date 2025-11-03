import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    let onToggleComplete: (Bool) -> Void

    @StateObject private var colorSettings = ColorSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    var body: some View {
        HStack(spacing: 12) {
            // チェックボックス
            Button(action: {
                onToggleComplete(!todo.isCompleted)
            }) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                // タイトル
                Text(todo.title)
                    .dynamicBody()
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)

                // 期限と優先度
                HStack(spacing: 8) {
                    // 優先度バッジ
                    Text(todo.priority.displayName)
                        .dynamicCaption()
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(todo.priority))
                        .cornerRadius(4)

                    // 期限
                    if let dueDate = todo.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: todo.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.caption2)
                            Text(formatDate(dueDate))
                                .dynamicCaption()
                        }
                        .foregroundColor(todo.isOverdue ? .red : .secondary)
                    }

                    // タグ
                    if !todo.tag.isEmpty {
                        Text(todo.tag)
                            .dynamicCaption()
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorSettings.getCurrentAccentColor().opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // 矢印
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(12)
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
    }

    private func priorityColor(_ priority: TodoItem.TodoPriority) -> Color {
        switch priority {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
