//
//  WidgetDataCache.swift
//  DariasWidgets
//
//  App Groupからデータを読み取るユーティリティ
//

import Foundation

class WidgetDataCache {
    static let shared = WidgetDataCache()

    private var sharedDefaults: UserDefaults? {
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName)
        defaults?.synchronize()
        return defaults
    }

    private init() {}

    // MARK: - Schedule

    func loadSchedules() -> [WidgetSchedule] {
        guard let jsonString = sharedDefaults?.string(forKey: AppGroupConstants.schedulesCacheKey),
              let data = jsonString.data(using: .utf8),
              let schedules = try? JSONDecoder().decode([WidgetSchedule].self, from: data) else {
            return []
        }
        return schedules
    }

    // MARK: - Memo

    func loadMemos() -> [WidgetMemo] {
        guard let jsonString = sharedDefaults?.string(forKey: AppGroupConstants.memosCacheKey),
              let data = jsonString.data(using: .utf8),
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
        guard let jsonString = sharedDefaults?.string(forKey: AppGroupConstants.todosCacheKey),
              let data = jsonString.data(using: .utf8),
              let todos = try? JSONDecoder().decode([WidgetTodo].self, from: data) else {
            return []
        }
        return todos
    }

    // MARK: - Big5 Progress

    func loadBig5Progress() -> WidgetBig5Progress {
        guard let jsonString = sharedDefaults?.string(forKey: AppGroupConstants.big5ProgressKey),
              let data = jsonString.data(using: .utf8),
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
