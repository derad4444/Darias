//
//  WidgetDataCache.swift
//  CharacterWidgets
//
//  ウィジェット側でキャッシュデータを読み込むユーティリティ
//

import Foundation

class WidgetDataCache {
    static let shared = WidgetDataCache()

    private let sharedDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName)

    private init() {}

    // MARK: - Schedule Data

    /// キャッシュからスケジュールデータを取得
    func getSchedules() -> [WidgetSchedule] {
        print("📅 [WidgetDataCache] getSchedules called")
        print("📅 [WidgetDataCache] App Group: \(AppGroupConstants.suiteName ?? "nil")")
        print("📅 [WidgetDataCache] Key: \(AppGroupConstants.schedulesCacheKey)")

        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.schedulesCacheKey) else {
            print("❌ [WidgetDataCache] No data found for key")
            return []
        }

        print("📅 [WidgetDataCache] Found data: \(data.count) bytes")

        guard let schedules = try? JSONDecoder().decode([WidgetSchedule].self, from: data) else {
            print("❌ [WidgetDataCache] Failed to decode schedules")
            return []
        }

        print("✅ [WidgetDataCache] Successfully loaded \(schedules.count) schedules")
        return schedules
    }

    // MARK: - Memo Data

    /// キャッシュからメモデータを取得
    func getMemos() -> ([WidgetMemo], Int) {
        print("📝 [WidgetDataCache] getMemos called")

        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.memosCacheKey) else {
            print("❌ [WidgetDataCache] No memo data found")
            return ([], 0)
        }

        guard let memos = try? JSONDecoder().decode([WidgetMemo].self, from: data) else {
            print("❌ [WidgetDataCache] Failed to decode memos")
            return ([], 0)
        }

        let totalCount = sharedDefaults?.integer(forKey: AppGroupConstants.memosTotalCountKey) ?? memos.count
        print("✅ [WidgetDataCache] Successfully loaded \(memos.count) memos (total: \(totalCount))")
        return (memos, totalCount)
    }

    // MARK: - Todo Data

    /// キャッシュからToDoデータを取得
    func getTodos() -> [WidgetTodo] {
        print("✅ [WidgetDataCache] getTodos called")

        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.todosCacheKey) else {
            print("❌ [WidgetDataCache] No todo data found")
            return []
        }

        guard let todos = try? JSONDecoder().decode([WidgetTodo].self, from: data) else {
            print("❌ [WidgetDataCache] Failed to decode todos")
            return []
        }

        print("✅ [WidgetDataCache] Successfully loaded \(todos.count) todos")
        return todos
    }

    // MARK: - Big5 Progress Data

    /// キャッシュからBig5進捗データを取得
    func getBig5Progress() -> WidgetBig5Progress {
        guard let data = sharedDefaults?.data(forKey: AppGroupConstants.big5ProgressKey),
              let progress = try? JSONDecoder().decode(WidgetBig5Progress.self, from: data) else {
            return WidgetBig5Progress(answered: 0, total: 100)
        }
        return progress
    }

    // MARK: - Last Update Time

    /// 最後にキャッシュが更新された時刻を取得
    func getLastUpdateTime() -> Date? {
        return sharedDefaults?.object(forKey: AppGroupConstants.lastUpdateKey) as? Date
    }
}
