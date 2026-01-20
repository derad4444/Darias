//
//  WidgetData.swift
//  DariasWidgets
//
//  Widget用の軽量データモデル
//

import Foundation
import WidgetKit

// MARK: - Calendar Widget Models

/// ウィジェット用のスケジュールデータ
struct WidgetSchedule: Codable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool

    var timeText: String {
        if isAllDay {
            return "終日"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }

    var timeUntilStart: String {
        let interval = startDate.timeIntervalSince(Date())
        if interval < 0 {
            return "開催中"
        }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)時間\(minutes)分後"
        } else {
            return "\(minutes)分後"
        }
    }
}

// MARK: - Memo Widget Models

/// ウィジェット用のメモデータ
struct WidgetMemo: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let updatedAt: Date
    let tag: String
    let isPinned: Bool

    var updatedText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d更新"
        return formatter.string(from: updatedAt)
    }

    var contentPreview: String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(5).joined(separator: "\n")
        if preview.count > 50 {
            return String(preview.prefix(50)) + "..."
        }
        return preview
    }

    var contentOneLine: String {
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        if firstLine.count > 30 {
            return String(firstLine.prefix(30)) + "..."
        }
        return firstLine
    }
}

// MARK: - Todo Widget Models

/// ToDoの優先度
enum TodoPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayText: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var icon: String {
        switch self {
        case .high: return "🔴"
        case .medium: return "🟡"
        case .low: return "⚪"
        }
    }
}

/// ウィジェット用のToDoデータ
struct WidgetTodo: Codable, Identifiable {
    let id: String
    let title: String
    let priority: String
    let dueDate: Date?

    var priorityEnum: TodoPriority {
        return TodoPriority(rawValue: priority) ?? .medium
    }

    var priorityIcon: String {
        return priorityEnum.icon
    }

    var dueDateText: String {
        guard let dueDate = dueDate else { return "期限なし" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: dueDate) + "まで"
    }
}

// MARK: - Big5 Progress Widget Models

/// ウィジェット用のBig5進捗データ
struct WidgetBig5Progress: Codable {
    let answered: Int
    let total: Int

    var percentage: Double {
        return Double(answered) / Double(total)
    }

    var currentLevelText: String {
        switch answered {
        case 0..<20:
            return "未開始"
        case 20..<50:
            return "基本解析完了"
        case 50..<100:
            return "学習進化解析完了"
        case 100:
            return "完全人格解析完了"
        default:
            return ""
        }
    }

    var currentIcon: String {
        switch answered {
        case 0..<20: return "🤖"
        case 20..<50: return "🤖"
        case 50..<100: return "🧠"
        case 100: return "👤"
        default: return "🤖"
        }
    }
}

// MARK: - Timeline Entries

/// カレンダーウィジェットのエントリー
struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let schedules: [WidgetSchedule]
}

/// メモウィジェットのエントリー
struct MemoWidgetEntry: TimelineEntry {
    let date: Date
    let memos: [WidgetMemo]
    let totalCount: Int
}

/// ToDoウィジェットのエントリー
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [WidgetTodo]
}

/// Big5進捗ウィジェットのエントリー
struct Big5ProgressEntry: TimelineEntry {
    let date: Date
    let progress: WidgetBig5Progress
}
