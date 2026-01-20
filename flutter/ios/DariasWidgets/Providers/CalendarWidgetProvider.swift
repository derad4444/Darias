//
//  CalendarWidgetProvider.swift
//  DariasWidgets
//

import WidgetKit
import SwiftUI

struct CalendarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        CalendarWidgetEntry(
            date: Date(),
            schedules: [
                WidgetSchedule(
                    id: "1",
                    title: "サンプル予定",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600),
                    location: nil,
                    isAllDay: false
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        let schedules = WidgetDataCache.shared.loadSchedules()
        let entry = CalendarWidgetEntry(date: Date(), schedules: schedules)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        let schedules = WidgetDataCache.shared.loadSchedules()
        let entry = CalendarWidgetEntry(date: Date(), schedules: schedules)

        // 15分ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}
