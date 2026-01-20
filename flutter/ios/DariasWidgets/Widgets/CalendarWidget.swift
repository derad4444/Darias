//
//  CalendarWidget.swift
//  DariasWidgets
//

import SwiftUI
import WidgetKit

struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("カレンダー")
        .description("今日と明日の予定を確認できます")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
