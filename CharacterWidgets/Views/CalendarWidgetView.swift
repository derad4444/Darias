//
//  CalendarWidgetView.swift
//  CharacterWidgets
//
//  カレンダーウィジェットのビュー
//

import SwiftUI
import WidgetKit

// MARK: - Entry View

struct CalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CalendarWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            CalendarWidgetSmallView(entry: entry)
        case .systemMedium:
            CalendarWidgetMediumView(entry: entry)
        case .systemLarge:
            CalendarWidgetLargeView(entry: entry)
        @unknown default:
            CalendarWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Small View

struct CalendarWidgetSmallView: View {
    let entry: CalendarWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "FFF5F7"), Color(hex: "FFE4E9")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                // ヘッダー
                HStack {
                    Text("📅")
                        .font(.system(size: 20))
                    Text("次の予定")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer()

                // 次の予定
                if let nextSchedule = getNextSchedule() {
                    VStack(spacing: 6) {
                        Text(nextSchedule.timeText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.pink)

                        Text(nextSchedule.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        if let location = nextSchedule.location {
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer()

                    // 残り時間
                    Text(nextSchedule.timeUntilStart)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 12)
                } else {
                    VStack(spacing: 4) {
                        Text("予定なし")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func getNextSchedule() -> WidgetSchedule? {
        let now = Date()
        return entry.schedules
            .filter { $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
}

// MARK: - Medium View

struct CalendarWidgetMediumView: View {
    let entry: CalendarWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "FFF5F7"), Color(hex: "FFE4E9")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                // ヘッダー
                HStack {
                    Text("📅")
                        .font(.system(size: 18))
                    Text("今日の予定")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                // 今日の予定リスト
                let todaySchedules = getTodaySchedules()
                if todaySchedules.isEmpty {
                    Spacer()
                    Text("予定なし")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(todaySchedules.prefix(3)) { schedule in
                            HStack(spacing: 8) {
                                Text(schedule.timeText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.pink)
                                    .frame(width: 50, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(schedule.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let location = schedule.location, !location.isEmpty {
                                        Text(location)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    Spacer()
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func getTodaySchedules() -> [WidgetSchedule] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return entry.schedules.filter { schedule in
            schedule.startDate >= today && schedule.startDate < tomorrow
        }.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Large View (Calendar Display)

struct CalendarWidgetLargeView: View {
    let entry: CalendarWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "FFF5F7"), Color(hex: "FFE4E9")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // ヘッダー
                HStack {
                    Text("📅")
                        .font(.system(size: 20))
                    if let calendarData = entry.calendarData {
                        let yearMonth = calendarData.yearMonth.components(separatedBy: "-")
                        if yearMonth.count == 2 {
                            Text("\(yearMonth[0])年\(Int(yearMonth[1]) ?? 1)月")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // カレンダーグリッド
                if let calendarData = entry.calendarData {
                    CalendarGridView(calendarData: calendarData)
                        .padding(.horizontal, 8)

                    // 凡例
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 6, height: 6)
                            Text("予定あり")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Circle()
                                .stroke(Color.pink, lineWidth: 2)
                                .frame(width: 6, height: 6)
                            Text("今日")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }

                Divider()
                    .padding(.horizontal, 12)

                // 今日の予定
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日の予定:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)

                    let todaySchedules = getTodaySchedules()
                    if todaySchedules.isEmpty {
                        Text("予定なし")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(todaySchedules.prefix(2)) { schedule in
                            HStack(spacing: 6) {
                                Text(schedule.timeText)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.pink)
                                    .frame(width: 40, alignment: .leading)

                                Text(schedule.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
    }

    private func getTodaySchedules() -> [WidgetSchedule] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return entry.schedules.filter { schedule in
            schedule.startDate >= today && schedule.startDate < tomorrow
        }.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Calendar Grid Component

struct CalendarGridView: View {
    let calendarData: CalendarMonthData

    let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            // 曜日ヘッダー
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(weekday == "日" ? .red : weekday == "土" ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日付グリッド
            LazyVGrid(columns: columns, spacing: 6) {
                // 月初の空白セル
                ForEach(0..<(calendarData.firstWeekday - 1), id: \.self) { _ in
                    Text("")
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }

                // 日付セル
                ForEach(1...calendarData.totalDays, id: \.self) { day in
                    DayCell(
                        day: day,
                        hasSchedule: calendarData.scheduleDates.contains(day),
                        isToday: day == calendarData.todayDate
                    )
                }
            }
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let day: Int
    let hasSchedule: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            // 今日のハイライト
            if isToday {
                Circle()
                    .stroke(Color.pink, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }

            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? .pink : .primary)

                // 予定があるマーク
                if hasSchedule {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
    }
}
