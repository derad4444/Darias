//
//  CalendarWidgetView.swift
//  DariasWidgets
//

import SwiftUI
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
        default:
            SmallCalendarView(entry: entry)
        }
    }
}

struct SmallCalendarView: View {
    var entry: CalendarWidgetEntry

    private var todaySchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { schedule in
            calendar.isDateInToday(schedule.startDate)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.red)
                Text("今日")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            if todaySchedules.isEmpty {
                Spacer()
                Text("予定なし")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ForEach(todaySchedules.prefix(3)) { schedule in
                    HStack(spacing: 4) {
                        Text(schedule.timeText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(schedule.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumCalendarView: View {
    var entry: CalendarWidgetEntry

    private var todaySchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { schedule in
            calendar.isDateInToday(schedule.startDate)
        }
    }

    private var tomorrowSchedules: [WidgetSchedule] {
        let calendar = Calendar.current
        return entry.schedules.filter { schedule in
            calendar.isDateInTomorrow(schedule.startDate)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // 今日
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.red)
                    Text("今日")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                if todaySchedules.isEmpty {
                    Text("予定なし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(todaySchedules.prefix(3)) { schedule in
                        HStack(spacing: 4) {
                            Text(schedule.timeText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .leading)
                            Text(schedule.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 明日
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("明日")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                if tomorrowSchedules.isEmpty {
                    Text("予定なし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(tomorrowSchedules.prefix(3)) { schedule in
                        HStack(spacing: 4) {
                            Text(schedule.timeText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .leading)
                            Text(schedule.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
