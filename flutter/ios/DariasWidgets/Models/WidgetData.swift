//
//  WidgetData.swift
//  DariasWidgets
//
//  Widget用の軽量データモデル（日付はStringで保持してデコードエラーを回避）
//

import Foundation
import WidgetKit

// MARK: - Calendar Widget Models

/// ウィジェット用のスケジュールデータ
struct WidgetSchedule: Codable, Identifiable {
    let id: String
    let title: String
    let startDate: String  // ISO8601 String
    let endDate: String    // ISO8601 String
    let location: String?
    let isAllDay: Bool
    let colorHex: String?

    var timeText: String {
        if isAllDay { return "終日" }
        // "2026-03-20T13:00:00.000" → "13:00"
        let parts = startDate.split(separator: "T")
        guard parts.count == 2 else { return "" }
        let timePart = String(parts[1].prefix(5))
        return timePart
    }

    var startDateParsed: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: startDate) { return d }
        // タイムゾーン情報なし → ローカルタイム（JST）として解釈
        // 誤って"Z"を付けるとUTCになり+9時間ずれて日付が変わるため使わない
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return fmt.date(from: String(startDate.prefix(23)))
    }
}

// MARK: - Memo Widget Models

/// ウィジェット用のメモデータ
struct WidgetMemo: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let updatedAt: String  // ISO8601 String
    let tag: String
    let isPinned: Bool

    var updatedText: String {
        // "2026-03-08T00:26:37.745" → "3/8更新"
        let parts = updatedAt.split(separator: "T")
        guard parts.count >= 1 else { return "" }
        let datePart = parts[0].split(separator: "-")
        guard datePart.count == 3 else { return "" }
        let month = Int(datePart[1]) ?? 0
        let day = Int(datePart[2]) ?? 0
        return "\(month)/\(day)更新"
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
    let dueDate: String?   // ISO8601 String or null

    var priorityEnum: TodoPriority {
        return TodoPriority(rawValue: priority) ?? .medium
    }

    var priorityIcon: String {
        return priorityEnum.icon
    }

    var dueDateText: String {
        guard let dueDate = dueDate else { return "期限なし" }
        // "2025-11-22T22:00:00.000" → "11/22まで"
        let parts = dueDate.split(separator: "T")
        guard parts.count >= 1 else { return "期限なし" }
        let datePart = parts[0].split(separator: "-")
        guard datePart.count == 3 else { return "期限なし" }
        let month = Int(datePart[1]) ?? 0
        let day = Int(datePart[2]) ?? 0
        return "\(month)/\(day)まで"
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
