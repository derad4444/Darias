//
//  AppGroupConstants.swift
//  Character
//
//  Created for Widget Data Sharing
//

import Foundation

struct AppGroupConstants {
    /// App Group ID for sharing data between main app and widgets
    static let suiteName = "group.com.darias.character"

    // MARK: - UserDefaults Keys for Widget Data Cache

    /// Key for cached schedule data
    static let schedulesCacheKey = "widget_schedules_cache"

    /// Key for cached memo data
    static let memosCacheKey = "widget_memos_cache"

    /// Key for memo total count
    static let memosTotalCountKey = "widget_memos_total_count"

    /// Key for cached todo data
    static let todosCacheKey = "widget_todos_cache"

    /// Key for Big5 progress data
    static let big5ProgressKey = "widget_big5_progress"

    /// Key for last update timestamp
    static let lastUpdateKey = "widget_last_update"
}
