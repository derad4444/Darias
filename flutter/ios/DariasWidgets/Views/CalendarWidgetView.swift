//
//  CalendarWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import UIKit
import WidgetKit

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
                Image(uiImage: UIImage(contentsOfFile: Bundle.main.path(forResource: "DariasIcon", ofType: "png") ?? "") ?? UIImage())
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
                    Image(uiImage: UIImage(contentsOfFile: Bundle.main.path(forResource: "DariasIcon", ofType: "png") ?? "") ?? UIImage())
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
