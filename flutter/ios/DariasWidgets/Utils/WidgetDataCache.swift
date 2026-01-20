//
//  WidgetDataCache.swift
//  DariasWidgets
//
//  App Groupからデータを読み取るユーティリティ
//

import Foundation

class WidgetDataCache {
    static let shared = WidgetDataCache()

    private let sharedDefaults: UserDefaults?

    private init() {
        sharedDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    // MARK: - Schedule

    func loadSchedules() -> [WidgetSchedule] {
        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.schedulesCacheKey),
              let schedules = try? JSONDecoder().decode([WidgetSchedule].self, from: data) else {
            return []
        }
        return schedules
    }

    // MARK: - Memo

    func loadMemos() -> [WidgetMemo] {
        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.memosCacheKey),
              let memos = try? JSONDecoder().decode([WidgetMemo].self, from: data) else {
            return []
        }
        return memos
    }

    func loadMemosTotalCount() -> Int {
        return sharedDefaults?.integer(forKey: AppGroupConstants.memosTotalCountKey) ?? 0
    }

    // MARK: - Todo

    func loadTodos() -> [WidgetTodo] {
        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.todosCacheKey),
              let todos = try? JSONDecoder().decode([WidgetTodo].self, from: data) else {
            return []
        }
        return todos
    }

    // MARK: - Big5 Progress

    func loadBig5Progress() -> WidgetBig5Progress {
        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.big5ProgressKey),
              let progress = try? JSONDecoder().decode(WidgetBig5Progress.self, from: data) else {
            return WidgetBig5Progress(answered: 0, total: 100)
        }
        return progress
    }

    // MARK: - Last Update

    func loadLastUpdate() -> Date? {
        return sharedDefaults?.object(forKey: AppGroupConstants.lastUpdateKey) as? Date
    }
}
