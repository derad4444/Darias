//
//  CalendarWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import UIKit
import WidgetKit
import Foundation

struct CalendarWidgetView: View {
    var entry: CalendarWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalendarView(entry: entry)
        case .systemMedium:
            MediumCalendarView(entry: entry)
        case .systemLarge:
            LargeCalendarView(entry: entry)
        default:
            SmallCalendarView(entry: entry)
        }
    }
}

// MARK: - Small

struct SmallCalendarView: View {
    var entry: CalendarWidgetEntry

    private var todaySchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { $0.startDateParsed.map { calendar.isDateInToday($0) } ?? false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("今日")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
            }

            if todaySchedules.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(WidgetColors.accentGradient)
                    Text("予定なし")
                        .font(.caption2)
                        .foregroundColor(WidgetColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(todaySchedules.prefix(3)) { schedule in
                    HStack(spacing: 5) {
                        Text(schedule.timeText)
                            .font(.caption2)
                            .foregroundColor(WidgetColors.primaryPink)
                        Text(schedule.title)
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
        .widgetURL(URL(string: "darias://open/?page=calendar&homeWidget"))
    }
}

// MARK: - Medium

struct MediumCalendarView: View {
    var entry: CalendarWidgetEntry

    private var todaySchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { $0.startDateParsed.map { calendar.isDateInToday($0) } ?? false }
    }

    private var tomorrowSchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { $0.startDateParsed.map { calendar.isDateInTomorrow($0) } ?? false }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 今日
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image("DariasIcon")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("今日")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(WidgetColors.primaryPink)
                }

                if todaySchedules.isEmpty {
                    Text("予定なし")
                        .font(.caption)
                        .foregroundColor(WidgetColors.textSecondary)
                } else {
                    ForEach(todaySchedules.prefix(3)) { schedule in
                        HStack(spacing: 4) {
                            Text(schedule.timeText)
                                .font(.caption2)
                                .foregroundColor(WidgetColors.primaryPink)
                                .frame(width: 36, alignment: .leading)
                            Text(schedule.title)
                                .font(.caption)
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(WidgetColors.primaryPink.opacity(0.3))

            // 明日
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundColor(WidgetColors.lavender)
                    Text("明日")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(WidgetColors.lavender)
                }

                if tomorrowSchedules.isEmpty {
                    Text("予定なし")
                        .font(.caption)
                        .foregroundColor(WidgetColors.textSecondary)
                } else {
                    ForEach(tomorrowSchedules.prefix(3)) { schedule in
                        HStack(spacing: 4) {
                            Text(schedule.timeText)
                                .font(.caption2)
                                .foregroundColor(WidgetColors.lavender)
                                .frame(width: 36, alignment: .leading)
                            Text(schedule.title)
                                .font(.caption)
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=calendar&homeWidget"))
    }
}

// MARK: - Large

struct LargeCalendarView: View {
    var entry: CalendarWidgetEntry

    private var todaySchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { $0.startDateParsed.map { calendar.isDateInToday($0) } ?? false }
            .sorted { $0.startDate < $1.startDate }
    }

    private var tomorrowSchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { $0.startDateParsed.map { calendar.isDateInTomorrow($0) } ?? false }
            .sorted { $0.startDate < $1.startDate }
    }

    private var dayAfterSchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        guard let dayAfter = calendar.date(byAdding: .day, value: 2, to: Date()) else { return [] }
        return entry.schedules.filter {
            $0.startDateParsed.map { calendar.isDate($0, inSameDayAs: dayAfter) } ?? false
        }.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scheduleSection(title: "今日", color: WidgetColors.primaryPink, schedules: todaySchedules, limit: 5)
            Divider().padding(.vertical, 8)
            scheduleSection(title: "明日", color: WidgetColors.lavender, schedules: tomorrowSchedules, limit: 4)
            Divider().padding(.vertical, 8)
            scheduleSection(title: "明後日", color: Color.purple.opacity(0.7), schedules: dayAfterSchedules, limit: 3)
            Spacer()
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=calendar&homeWidget"))
    }

    @ViewBuilder
    private func scheduleSection(title: String, color: Color, schedules: [WidgetSchedule], limit: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.bottom, 4)

        if schedules.isEmpty {
            Text("予定なし")
                .font(.caption)
                .foregroundColor(WidgetColors.textSecondary)
                .padding(.bottom, 4)
        } else {
            ForEach(schedules.prefix(limit)) { schedule in
                HStack(spacing: 6) {
                    Text(schedule.timeText)
                        .font(.caption2)
                        .foregroundColor(color)
                        .frame(width: 36, alignment: .leading)
                    Text(schedule.title)
                        .font(.caption)
                        .foregroundColor(WidgetColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.bottom, 3)
            }
        }
    }
}

// MARK: - Japanese Holidays

private func isJapaneseHoliday(year: Int, month: Int, day: Int) -> Bool {
    // 毎年固定の祝日
    switch (month, day) {
    case (1, 1):   return true  // 元日
    case (2, 11):  return true  // 建国記念の日
    case (2, 23):  return true  // 天皇誕生日
    case (4, 29):  return true  // 昭和の日
    case (5, 3):   return true  // 憲法記念日
    case (5, 4):   return true  // みどりの日
    case (5, 5):   return true  // こどもの日
    case (8, 11):  return true  // 山の日
    case (11, 3):  return true  // 文化の日
    case (11, 23): return true  // 勤労感謝の日
    default: break
    }
    // 年ごとに変わる祝日・振替休日
    switch (year, month, day) {
    case (2024, 1, 8):   return true  // 成人の日
    case (2024, 2, 12):  return true  // 振替休日
    case (2024, 3, 20):  return true  // 春分の日
    case (2024, 5, 6):   return true  // 振替休日
    case (2024, 7, 15):  return true  // 海の日
    case (2024, 8, 12):  return true  // 振替休日
    case (2024, 9, 16):  return true  // 敬老の日
    case (2024, 9, 22):  return true  // 秋分の日
    case (2024, 9, 23):  return true  // 振替休日
    case (2024, 10, 14): return true  // スポーツの日
    case (2024, 11, 4):  return true  // 振替休日
    case (2025, 1, 13):  return true  // 成人の日
    case (2025, 2, 24):  return true  // 振替休日
    case (2025, 3, 20):  return true  // 春分の日
    case (2025, 5, 6):   return true  // 振替休日
    case (2025, 7, 21):  return true  // 海の日
    case (2025, 9, 15):  return true  // 敬老の日
    case (2025, 9, 23):  return true  // 秋分の日
    case (2025, 10, 13): return true  // スポーツの日
    case (2025, 11, 24): return true  // 振替休日
    case (2026, 1, 12):  return true  // 成人の日
    case (2026, 3, 20):  return true  // 春分の日
    case (2026, 5, 6):   return true  // 振替休日
    case (2026, 7, 20):  return true  // 海の日
    case (2026, 9, 21):  return true  // 敬老の日
    case (2026, 9, 23):  return true  // 秋分の日
    case (2026, 10, 12): return true  // スポーツの日
    case (2027, 1, 11):  return true  // 成人の日
    case (2027, 3, 21):  return true  // 春分の日
    case (2027, 7, 19):  return true  // 海の日
    case (2027, 9, 20):  return true  // 敬老の日
    case (2027, 9, 23):  return true  // 秋分の日
    case (2027, 10, 11): return true  // スポーツの日
    default: return false
    }
}

private func getJapaneseHolidayName(year: Int, month: Int, day: Int) -> String? {
    switch (month, day) {
    case (1, 1):   return "元日"
    case (2, 11):  return "建国記念の日"
    case (2, 23):  return "天皇誕生日"
    case (4, 29):  return "昭和の日"
    case (5, 3):   return "憲法記念日"
    case (5, 4):   return "みどりの日"
    case (5, 5):   return "こどもの日"
    case (8, 11):  return "山の日"
    case (11, 3):  return "文化の日"
    case (11, 23): return "勤労感謝の日"
    default: break
    }
    switch (year, month, day) {
    case (2024, 1, 8):   return "成人の日"
    case (2024, 2, 12):  return "振替休日"
    case (2024, 3, 20):  return "春分の日"
    case (2024, 5, 6):   return "振替休日"
    case (2024, 7, 15):  return "海の日"
    case (2024, 8, 12):  return "振替休日"
    case (2024, 9, 16):  return "敬老の日"
    case (2024, 9, 22):  return "振替休日"
    case (2024, 9, 23):  return "秋分の日"
    case (2024, 10, 14): return "スポーツの日"
    case (2024, 11, 4):  return "振替休日"
    case (2025, 1, 13):  return "成人の日"
    case (2025, 2, 24):  return "振替休日"
    case (2025, 3, 20):  return "春分の日"
    case (2025, 5, 6):   return "振替休日"
    case (2025, 7, 21):  return "海の日"
    case (2025, 9, 15):  return "敬老の日"
    case (2025, 9, 23):  return "秋分の日"
    case (2025, 10, 13): return "スポーツの日"
    case (2025, 11, 24): return "振替休日"
    case (2026, 1, 12):  return "成人の日"
    case (2026, 3, 20):  return "春分の日"
    case (2026, 5, 6):   return "振替休日"
    case (2026, 7, 20):  return "海の日"
    case (2026, 9, 21):  return "敬老の日"
    case (2026, 9, 23):  return "秋分の日"
    case (2026, 10, 12): return "スポーツの日"
    case (2027, 1, 11):  return "成人の日"
    case (2027, 3, 21):  return "春分の日"
    case (2027, 7, 19):  return "海の日"
    case (2027, 9, 20):  return "敬老の日"
    case (2027, 9, 23):  return "秋分の日"
    case (2027, 10, 11): return "スポーツの日"
    default: return nil
    }
}

private func schedulesPerDay(in date: Date, schedules: [WidgetSchedule]) -> [Int: [WidgetSchedule]] {
    let cal = Calendar.current
    var result: [Int: [WidgetSchedule]] = [:]
    for s in schedules {
        guard let d = s.startDateParsed, cal.isDate(d, equalTo: date, toGranularity: .month) else { continue }
        let day = cal.component(.day, from: d)
        result[day, default: []].append(s)
    }
    for day in result.keys {
        result[day]?.sort { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
    }
    return result
}

private func holidayDays(in date: Date) -> Set<Int> {
    let cal = Calendar(identifier: .gregorian)
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date)
    let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 31
    var days = Set<Int>()
    for day in 1...daysInMonth {
        if isJapaneseHoliday(year: year, month: month, day: day) {
            days.insert(day)
        }
    }
    return days
}

// MARK: - Calendar Grid Helpers

private func calendarGridData(for date: Date) -> (firstWeekday: Int, daysInMonth: Int, rows: Int) {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month], from: date)
    let monthStart = cal.date(from: comps)!
    let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)!.count
    let firstWeekday = cal.component(.weekday, from: monthStart) - 1 // 0=Sun
    let rows = Int(ceil(Double(firstWeekday + daysInMonth) / 7.0))
    return (firstWeekday, daysInMonth, rows)
}

private func scheduledDays(in date: Date, schedules: [WidgetSchedule]) -> Set<Int> {
    let cal = Calendar.current
    var days = Set<Int>()
    for s in schedules {
        if let d = s.startDateParsed, cal.isDate(d, equalTo: date, toGranularity: .month) {
            days.insert(cal.component(.day, from: d))
        }
    }
    return days
}

private func monthLabel(_ date: Date, format: String = "M月") -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.dateFormat = format
    return f.string(from: date)
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let hasEvent: Bool
    let isSunday: Bool
    let isSaturday: Bool
    let isHoliday: Bool
    let cellSize: CGFloat

    var textColor: Color {
        if isToday { return .white }
        if isSunday || isHoliday { return Color.red.opacity(0.8) }
        if isSaturday { return Color.blue.opacity(0.8) }
        return WidgetColors.textPrimary
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(WidgetColors.primaryPink)
                        .frame(width: cellSize, height: cellSize)
                }
                Text("\(day)")
                    .font(.system(size: cellSize * 0.62, weight: isToday ? .bold : .regular))
                    .foregroundColor(textColor)
            }
            .frame(width: cellSize, height: cellSize)
            Circle()
                .fill(hasEvent && !isToday ? WidgetColors.primaryPink : Color.clear)
                .frame(width: 3, height: 3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Large Grid Day Cell (with schedule items)

private struct LargeGridDayCell: View {
    let day: Int
    let isToday: Bool
    let isSunday: Bool
    let isSaturday: Bool
    let holidayName: String?
    let schedules: [WidgetSchedule]
    let cellSize: CGFloat

    private enum CellItem: Identifiable {
        case holiday(String)
        case schedule(WidgetSchedule)
        case overflow(Int)
        var id: String {
            switch self {
            case .holiday(let n): return "h_\(n)"
            case .schedule(let s): return "s_\(s.id)"
            case .overflow(let n): return "o_\(n)"
            }
        }
    }

    private var textColor: Color {
        if isToday { return .white }
        if isSunday || holidayName != nil { return Color.red.opacity(0.8) }
        if isSaturday { return Color.blue.opacity(0.8) }
        return WidgetColors.textPrimary
    }

    private var displayItems: [CellItem] {
        var items: [CellItem] = []
        if let name = holidayName { items.append(.holiday(name)) }
        for s in schedules { items.append(.schedule(s)) }
        let total = items.count
        let maxDisplay = 3
        if total > maxDisplay {
            let remaining = total - (maxDisplay - 1)
            return Array(items.prefix(maxDisplay - 1)) + [.overflow(remaining)]
        }
        return Array(items.prefix(maxDisplay))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(WidgetColors.primaryPink)
                        .frame(width: cellSize, height: cellSize)
                }
                Text("\(day)")
                    .font(.system(size: cellSize * 0.62, weight: isToday ? .bold : .regular))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellSize)

            ForEach(displayItems) { item in
                switch item {
                case .holiday(let name):
                    Text(name)
                        .font(.system(size: 6.5))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 1)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(2)
                case .schedule(let s):
                    let color = s.colorHex.flatMap { Color(hex: $0) } ?? WidgetColors.primaryPink
                    if s.isAllDay {
                        Text(s.title)
                            .font(.system(size: 6.5))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 1)
                            .background(color)
                            .cornerRadius(2)
                    } else {
                        Text(s.title)
                            .font(.system(size: 6.5))
                            .foregroundColor(color)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 1)
                    }
                case .overflow(let n):
                    Text("+\(n)")
                        .font(.system(size: 6.5))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - CalendarGridWidgetView

struct CalendarGridWidgetView: View {
    var entry: CalendarWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalendarGridView(entry: entry)
        case .systemMedium:
            MediumCalendarGridView(entry: entry)
        case .systemLarge:
            LargeCalendarGridView(entry: entry)
        default:
            SmallCalendarGridView(entry: entry)
        }
    }
}

// MARK: - Small Grid

struct SmallCalendarGridView: View {
    var entry: CalendarWidgetEntry
    private let dayHeaders = ["日", "月", "火", "水", "木", "金", "土"]
    private var calYear: Int { Calendar(identifier: .gregorian).component(.year, from: entry.date) }
    private var calMonth: Int { Calendar(identifier: .gregorian).component(.month, from: entry.date) }

    var body: some View {
        let cal = Calendar.current
        let (firstWeekday, daysInMonth, rows) = calendarGridData(for: entry.date)
        let events = scheduledDays(in: entry.date, schedules: entry.schedules)
        let todayDay = cal.component(.day, from: entry.date)
        let cellSize: CGFloat = 14

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(monthLabel(entry.date))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.system(size: 7))
                        .foregroundColor(i == 0 ? Color.red.opacity(0.8) : i == 6 ? Color.blue.opacity(0.8) : WidgetColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col - firstWeekday + 1
                            if day >= 1 && day <= daysInMonth {
                                CalendarDayCell(day: day, isToday: day == todayDay,
                                    hasEvent: events.contains(day), isSunday: col == 0,
                                    isSaturday: col == 6, isHoliday: isJapaneseHoliday(year: calYear, month: calMonth, day: day),
                                    cellSize: cellSize)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: cellSize + 4)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
        .widgetURL(URL(string: "darias://open/?page=calendar&homeWidget"))
    }
}

// MARK: - Medium Grid

struct MediumCalendarGridView: View {
    var entry: CalendarWidgetEntry
    private let dayHeaders = ["日", "月", "火", "水", "木", "金", "土"]
    private var calYear: Int { Calendar(identifier: .gregorian).component(.year, from: entry.date) }
    private var calMonth: Int { Calendar(identifier: .gregorian).component(.month, from: entry.date) }

    private var upcomingSchedules: [WidgetSchedule] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: entry.date)
        return entry.schedules.filter {
            guard let d = $0.startDateParsed else { return false }
            return d >= start
        }.sorted { ($0.startDateParsed ?? Date()) < ($1.startDateParsed ?? Date()) }
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今日" }
        if cal.isDateInTomorrow(date) { return "明日" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    var body: some View {
        let cal = Calendar.current
        let (firstWeekday, daysInMonth, rows) = calendarGridData(for: entry.date)
        let events = scheduledDays(in: entry.date, schedules: entry.schedules)
        let todayDay = cal.component(.day, from: entry.date)
        let cellSize: CGFloat = 15

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image("DariasIcon")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text(monthLabel(entry.date))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(WidgetColors.primaryPink)
                }
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayHeaders[i])
                            .font(.system(size: 7))
                            .foregroundColor(i == 0 ? Color.red.opacity(0.8) : i == 6 ? Color.blue.opacity(0.8) : WidgetColors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { col in
                                let day = row * 7 + col - firstWeekday + 1
                                if day >= 1 && day <= daysInMonth {
                                    CalendarDayCell(day: day, isToday: day == todayDay,
                                        hasEvent: events.contains(day), isSunday: col == 0,
                                        isSaturday: col == 6, isHoliday: isJapaneseHoliday(year: calYear, month: calMonth, day: day),
                                        cellSize: cellSize)
                                } else {
                                    Color.clear.frame(maxWidth: .infinity).frame(height: cellSize + 4)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(WidgetColors.primaryPink.opacity(0.3))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(WidgetColors.primaryPink)
                    Text("直近の予定")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(WidgetColors.primaryPink)
                }
                if upcomingSchedules.isEmpty {
                    Spacer()
                    Text("予定なし")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetColors.textSecondary)
                    Spacer()
                } else {
                    ForEach(upcomingSchedules.prefix(4)) { schedule in
                        HStack(spacing: 3) {
                            Text(schedule.startDateParsed.map { shortDate($0) } ?? "")
                                .font(.system(size: 9))
                                .foregroundColor(WidgetColors.primaryPink)
                                .frame(width: 28, alignment: .leading)
                            Text(schedule.title)
                                .font(.system(size: 10))
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
        .widgetURL(URL(string: "darias://open/?page=calendar&homeWidget"))
    }
}

// MARK: - Large Grid

struct LargeCalendarGridView: View {
    var entry: CalendarWidgetEntry
    private let dayHeaders = ["日", "月", "火", "水", "木", "金", "土"]
    private var calYear: Int { Calendar(identifier: .gregorian).component(.year, from: entry.date) }
    private var calMonth: Int { Calendar(identifier: .gregorian).component(.month, from: entry.date) }

    var body: some View {
        let cal = Calendar.current
        let (firstWeekday, daysInMonth, rows) = calendarGridData(for: entry.date)
        let todayDay = cal.component(.day, from: entry.date)
        let cellSize: CGFloat = 20
        let dayScheds = schedulesPerDay(in: entry.date, schedules: entry.schedules)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(monthLabel(entry.date, format: "yyyy年M月"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.system(size: 10))
                        .foregroundColor(i == 0 ? Color.red.opacity(0.8) : i == 6 ? Color.blue.opacity(0.8) : WidgetColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col - firstWeekday + 1
                            if day >= 1 && day <= daysInMonth {
                                LargeGridDayCell(
                                    day: day,
                                    isToday: day == todayDay,
                                    isSunday: col == 0,
                                    isSaturday: col == 6,
                                    holidayName: getJapaneseHolidayName(year: calYear, month: calMonth, day: day),
                                    schedules: dayScheds[day] ?? [],
                                    cellSize: cellSize
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                                )
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
        .widgetURL(URL(string: "darias://open/?page=calendar&homeWidget"))
    }
}
