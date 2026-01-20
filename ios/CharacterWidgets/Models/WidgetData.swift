//
//  WidgetData.swift
//  CharacterWidgets
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

/// カレンダー月間表示用のデータ構造
struct CalendarMonthData: Codable {
    let yearMonth: String // "2024-11"
    let scheduleDates: Set<Int> // 予定がある日付のSet（1-31）
    let todayDate: Int // 今日の日付（1-31）
    let totalDays: Int // その月の日数
    let firstWeekday: Int // 月初の曜日（1=日曜, 7=土曜）

    init(year: Int, month: Int, schedules: [WidgetSchedule], today: Date) {
        self.yearMonth = String(format: "%04d-%02d", year, month)

        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = 1

        guard let firstDay = calendar.date(from: dateComponents) else {
            self.scheduleDates = []
            self.todayDate = 1
            self.totalDays = 30
            self.firstWeekday = 1
            return
        }

        // その月の日数を計算
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        self.totalDays = range.count

        // 月初の曜日（1=日曜）
        self.firstWeekday = calendar.component(.weekday, from: firstDay)

        // 予定がある日付を抽出（期間予定の場合は全日程にマーク）
        var dates = Set<Int>()
        for schedule in schedules {
            // 期間予定の場合、開始日から終了日までのすべての日付を追加
            var currentDate = schedule.startDate
            let endDate = schedule.endDate

            while currentDate <= endDate {
                let scheduleYear = calendar.component(.year, from: currentDate)
                let scheduleMonth = calendar.component(.month, from: currentDate)

                // この月に該当する日付のみ追加
                if scheduleYear == year && scheduleMonth == month {
                    let day = calendar.component(.day, from: currentDate)
                    dates.insert(day)
                }

                // 次の日へ
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate

                // 無限ループ防止（最大31日まで）
                if dates.count > 31 {
                    break
                }
            }
        }
        self.scheduleDates = dates

        // 今日の日付
        let todayYear = calendar.component(.year, from: today)
        let todayMonth = calendar.component(.month, from: today)
        if todayYear == year && todayMonth == month {
            self.todayDate = calendar.component(.day, from: today)
        } else {
            self.todayDate = -1 // 今月でない場合
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

    var contentPreviewMedium: String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(10).joined(separator: "\n")
        if preview.count > 100 {
            return String(preview.prefix(100)) + "..."
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

/// ToDoの優先度（メインアプリのモデルと同期）
enum TodoPriority: String, Codable {
    case low = "低"
    case medium = "中"
    case high = "高"

    var rawValue: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

/// ウィジェット用のToDoデータ
struct WidgetTodo: Codable, Identifiable {
    let id: String
    let title: String
    let priority: TodoPriority
    let dueDate: Date?

    var priorityIcon: String {
        switch priority {
        case .high: return "🔴"
        case .medium: return "🟡"
        case .low: return "⚪"
        }
    }

    var dueDateText: String {
        guard let dueDate = dueDate else { return "期限なし" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: dueDate) + "まで"
    }
}

// MARK: - Big5 Progress Widget Models

/// Big5解析レベル
enum Big5Level {
    case notStarted
    case basic      // 20問
    case detailed   // 50問
    case complete   // 100問

    var icon: String {
        switch self {
        case .notStarted: return "🤖"
        case .basic: return "🤖"
        case .detailed: return "🧠"
        case .complete: return "👤"
        }
    }

    var displayName: String {
        switch self {
        case .notStarted: return "未開始"
        case .basic: return "基本プログラム解析"
        case .detailed: return "学習進化解析"
        case .complete: return "完全人格解析"
        }
    }

    var description: String {
        switch self {
        case .notStarted: return "性格分析を始めましょう"
        case .basic: return "アンドロイドとして起動したばかりの基本設定"
        case .detailed: return "多くの経験を積み、人間らしい感情が発達"
        case .complete: return "完全な人間へと進化した豊かな人格"
        }
    }
}

/// Big5マイルストーン
struct Big5Milestone {
    let level: Big5Level
    let requiredCount: Int
    let achieved: Bool
    let remaining: Int

    var statusIcon: String {
        return achieved ? "✅" : "🔒"
    }

    var displayText: String {
        if achieved {
            return "\(requiredCount)問達成"
        } else {
            return "\(requiredCount)問 (あと\(remaining)問)"
        }
    }
}

/// ウィジェット用のBig5進捗データ
struct WidgetBig5Progress: Codable {
    let answered: Int
    let total: Int // 常に100

    var percentage: Double {
        return Double(answered) / Double(total)
    }

    var currentLevel: Big5Level {
        switch answered {
        case 0..<20:
            return .notStarted
        case 20..<50:
            return .basic
        case 50..<100:
            return .detailed
        case 100:
            return .complete
        default:
            return .notStarted
        }
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
        return currentLevel.icon
    }

    var milestones: [Big5Milestone] {
        return [
            Big5Milestone(
                level: .basic,
                requiredCount: 20,
                achieved: answered >= 20,
                remaining: max(0, 20 - answered)
            ),
            Big5Milestone(
                level: .detailed,
                requiredCount: 50,
                achieved: answered >= 50,
                remaining: max(0, 50 - answered)
            ),
            Big5Milestone(
                level: .complete,
                requiredCount: 100,
                achieved: answered >= 100,
                remaining: max(0, 100 - answered)
            )
        ]
    }
}

// MARK: - Timeline Entries

/// カレンダーウィジェットのエントリー
struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let schedules: [WidgetSchedule]
    let calendarData: CalendarMonthData?
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
