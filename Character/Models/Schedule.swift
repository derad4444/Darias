import Foundation

struct Schedule: Identifiable, Equatable {
    let id: String
    let title: String
    let date: Date
    var isAllDay: Bool
    var tag: String = ""
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