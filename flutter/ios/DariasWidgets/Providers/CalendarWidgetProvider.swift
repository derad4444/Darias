//
//  CalendarWidgetProvider.swift
//  DariasWidgets
//

import WidgetKit
import SwiftUI

struct CalendarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayNoon = cal.date(byAdding: .hour, value: 12, to: today)!
        let todayEnd = cal.date(byAdding: .hour, value: 1, to: todayNoon)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let tomorrowMorning = cal.date(byAdding: .hour, value: 10, to: tomorrow)!
        let tomorrowMorningEnd = cal.date(byAdding: .hour, value: 1, to: tomorrowMorning)!

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return CalendarWidgetEntry(
            date: Date(),
            schedules: [
                WidgetSchedule(
                    id: "1",
                    title: "サンプル予定",
                    startDate: fmt.string(from: todayNoon),
                    endDate: fmt.string(from: todayEnd),
                    location: nil,
                    isAllDay: false,
                    colorHex: nil
                ),
                WidgetSchedule(
                    id: "2",
                    title: "明日の予定",
                    startDate: fmt.string(from: tomorrowMorning),
                    endDate: fmt.string(from: tomorrowMorningEnd),
                    location: nil,
                    isAllDay: false,
                    colorHex: nil
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
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

// MARK: - CalendarGridProvider

struct CalendarGridProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        CalendarWidgetEntry(date: Date(), schedules: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let schedules = WidgetDataCache.shared.loadSchedules()
        completion(CalendarWidgetEntry(date: Date(), schedules: schedules))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        let schedules = WidgetDataCache.shared.loadSchedules()
        let entry = CalendarWidgetEntry(date: Date(), schedules: schedules)
        // 1時間ごとに更新（日付変更に対応）
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
