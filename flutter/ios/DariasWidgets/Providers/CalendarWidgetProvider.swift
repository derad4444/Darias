//
//  CalendarWidgetProvider.swift
//  DariasWidgets
//

import WidgetKit
import SwiftUI

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
