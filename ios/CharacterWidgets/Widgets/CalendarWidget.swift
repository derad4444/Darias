//
//  CalendarWidget.swift
//  CharacterWidgets
//
//  カレンダーウィジェットの定義
//

import WidgetKit
import SwiftUI

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                CalendarWidgetEntryView(entry: entry)
                    .environment(\.colorScheme, .light)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                CalendarWidgetEntryView(entry: entry)
                    .environment(\.colorScheme, .light)
            }
        }
        .configurationDisplayName("DARIAS カレンダー")
        .description("DARIASのスケジュールを確認できます")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    CalendarWidget()
} timeline: {
    let today = Date()
    let sampleSchedule = WidgetSchedule(
        id: "1",
        title: "チーム会議",
        startDate: today.addingTimeInterval(3600),
        endDate: today.addingTimeInterval(5400),
        location: "会議室A",
        isAllDay: false
    )

    CalendarWidgetEntry(
        date: today,
        schedules: [sampleSchedule],
        calendarData: nil
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    CalendarWidget()
} timeline: {
    let today = Date()
    let schedules = [
        WidgetSchedule(
            id: "1",
            title: "チーム会議",
            startDate: today.addingTimeInterval(3600),
            endDate: today.addingTimeInterval(5400),
            location: "会議室A",
            isAllDay: false
        ),
        WidgetSchedule(
            id: "2",
            title: "ランチ",
            startDate: today.addingTimeInterval(7200),
            endDate: today.addingTimeInterval(9000),
            location: nil,
            isAllDay: false
        )
    ]

    CalendarWidgetEntry(
        date: today,
        schedules: schedules,
        calendarData: nil
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    CalendarWidget()
} timeline: {
    let today = Date()
    let calendar = Calendar.current
    let year = calendar.component(.year, from: today)
    let month = calendar.component(.month, from: today)

    let schedules = [
        WidgetSchedule(
            id: "1",
            title: "チーム会議",
            startDate: today,
            endDate: today.addingTimeInterval(1800),
            location: nil,
            isAllDay: false
        ),
        WidgetSchedule(
            id: "2",
            title: "打ち合わせ",
            startDate: today.addingTimeInterval(86400 * 2),
            endDate: today.addingTimeInterval(86400 * 2 + 1800),
            location: nil,
            isAllDay: false
        )
    ]

    let calendarData = CalendarMonthData(
        year: year,
        month: month,
        schedules: schedules,
        today: today
    )

    CalendarWidgetEntry(
        date: today,
        schedules: schedules,
        calendarData: calendarData
    )
}
