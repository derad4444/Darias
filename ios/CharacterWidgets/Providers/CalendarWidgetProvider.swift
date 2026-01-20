//
//  CalendarWidgetProvider.swift
//  CharacterWidgets
//
//  カレンダーウィジェット用のTimelineProvider
//

import WidgetKit
import SwiftUI

struct CalendarWidgetProvider: TimelineProvider {

    // MARK: - Placeholder

    func placeholder(in context: Context) -> CalendarWidgetEntry {
        let today = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)

        // サンプルスケジュール
        let sampleSchedules = [
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

        let calendarData = CalendarMonthData(
            year: year,
            month: month,
            schedules: sampleSchedules,
            today: today
        )

        return CalendarWidgetEntry(
            date: today,
            schedules: sampleSchedules,
            calendarData: calendarData
        )
    }

    // MARK: - Snapshot

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        let schedules = WidgetDataCache.shared.getSchedules()
        let entry = createEntry(from: schedules)
        completion(entry)
    }

    // MARK: - Timeline

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        let schedules = WidgetDataCache.shared.getSchedules()
        let currentDate = Date()

        var entries: [CalendarWidgetEntry] = []

        // 現在のエントリー
        let currentEntry = createEntry(from: schedules)
        entries.append(currentEntry)

        // 次の予定開始時刻にエントリー追加（予定が切り替わるタイミング）
        let todaySchedules = getTodaySchedules(from: schedules)
        if let nextSchedule = todaySchedules.first {
            let nextUpdate = nextSchedule.startDate.addingTimeInterval(60) // 1分後
            let nextEntry = createEntry(from: schedules, date: nextUpdate)
            entries.append(nextEntry)
        }

        // デフォルトの更新時刻（15分後）
        let calendar = Calendar.current
        let nextRefresh = calendar.date(byAdding: .minute, value: 15, to: currentDate)!

        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }

    // MARK: - Helper Methods

    /// スケジュールからエントリーを作成
    private func createEntry(from schedules: [WidgetSchedule], date: Date = Date()) -> CalendarWidgetEntry {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        // カレンダーデータ作成
        let calendarData = CalendarMonthData(
            year: year,
            month: month,
            schedules: schedules,
            today: date
        )

        return CalendarWidgetEntry(
            date: date,
            schedules: schedules,
            calendarData: calendarData
        )
    }

    /// 今日のスケジュールを取得
    private func getTodaySchedules(from schedules: [WidgetSchedule]) -> [WidgetSchedule] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return schedules.filter { schedule in
            schedule.startDate >= today && schedule.startDate < tomorrow
        }.sorted { $0.startDate < $1.startDate }
    }
}
