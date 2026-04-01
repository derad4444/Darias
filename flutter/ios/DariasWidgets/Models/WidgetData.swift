//
//  WidgetData.swift
//  DariasWidgets
//
//  Widget用の軽量データモデル（日付はStringで保持してデコードエラーを回避）
//

import Foundation
import SwiftUI
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

    var tagColor: Color? {
        guard let hex = colorHex else { return nil }
        return Color(hex: hex)
    }

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
    let colorHex: String?

    init(id: String, title: String, content: String, updatedAt: String, tag: String, isPinned: Bool, colorHex: String? = nil) {
        self.id = id; self.title = title; self.content = content
        self.updatedAt = updatedAt; self.tag = tag; self.isPinned = isPinned
        self.colorHex = colorHex
    }

    // colorHex はキー自体が存在しない古いキャッシュでも失敗しないよう decodeIfPresent を使う
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        title     = try c.decode(String.self, forKey: .title)
        content   = try c.decode(String.self, forKey: .content)
        updatedAt = try c.decode(String.self, forKey: .updatedAt)
        tag       = try c.decode(String.self, forKey: .tag)
        isPinned  = try c.decode(Bool.self,   forKey: .isPinned)
        colorHex  = try c.decodeIfPresent(String.self, forKey: .colorHex)
    }

    var tagColor: Color? {
        guard let hex = colorHex else { return nil }
        return Color(hex: hex)
    }

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
    let colorHex: String?
    let tag: String

    init(id: String, title: String, priority: String, dueDate: String?, colorHex: String? = nil, tag: String = "") {
        self.id = id; self.title = title; self.priority = priority
        self.dueDate = dueDate; self.colorHex = colorHex; self.tag = tag
    }

    // colorHex・dueDate・tag はキー自体が存在しない古いキャッシュでも失敗しないよう decodeIfPresent を使う
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        title    = try c.decode(String.self, forKey: .title)
        priority = try c.decode(String.self, forKey: .priority)
        dueDate  = try c.decodeIfPresent(String.self, forKey: .dueDate)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        tag      = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
    }

    var tagColor: Color? {
        guard let hex = colorHex else { return nil }
        return Color(hex: hex)
    }

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
