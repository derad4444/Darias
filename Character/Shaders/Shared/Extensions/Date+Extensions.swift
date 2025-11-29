//
//  Date+Extensions.swift
//  Character
//
//  Created for Widget Utilities
//

import Foundation

extension Date {
    /// 今日の開始時刻（0:00:00）を返す
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    /// 今日の終了時刻（23:59:59）を返す
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    /// 指定した日数後の日付を返す
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self)!
    }

    /// 指定した日付が今日かどうかを判定
    func isToday() -> Bool {
        return Calendar.current.isDateInToday(self)
    }

    /// 指定した日付が明日かどうかを判定
    func isTomorrow() -> Bool {
        return Calendar.current.isDateInTomorrow(self)
    }

    /// 日本語の曜日文字列を返す（例: "月"）
    func weekdayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }

    /// 日本語の日付文字列を返す（例: "11月16日"）
    func shortDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }

    /// 日本語の日付+曜日文字列を返す（例: "11月16日(土)"）
    func dateWithWeekdayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: self)
    }

    /// 時刻文字列を返す（例: "14:30"）
    func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}
