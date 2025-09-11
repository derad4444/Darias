import Foundation

struct Schedule: Identifiable, Equatable {
    let id: String
    let title: String
    let date: Date  // 下位互換性のため残す（startDateと同じ値）
    let startDate: Date
    let endDate: Date
    var isAllDay: Bool
    var tag: String = ""
    var location: String = ""
    var memo: String = ""
    var repeatOption: String = ""
    var remindValue: Int = 0
    var remindUnit: String = ""
    
    // 期間が複数日にわたるかどうかを判定
    var isMultiDay: Bool {
        let calendar = Calendar.current
        return !calendar.isDate(startDate, inSameDayAs: endDate)
    }
    
    // 表示用の日付範囲文字列
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        if isMultiDay {
            formatter.dateFormat = "M/d"
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        } else {
            formatter.dateFormat = "M/d"
            return formatter.string(from: startDate)
        }
    }
}

struct ScheduleItem: Identifiable {
    var id: String
    var title: String
    var isAllDay: Bool
    var startDate: Date
    var endDate: Date
    var location: String
    var tag: String
    var memo: String
    var repeatOption: String
    var remindValue: Int
    var remindUnit: String
}