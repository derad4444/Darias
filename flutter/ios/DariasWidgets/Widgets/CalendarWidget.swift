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
        .configurationDisplayName("予定")
        .description("今日と明日の予定を確認できます")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CalendarGridWidget: Widget {
    let kind: String = "CalendarGridWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarGridProvider()) { entry in
            CalendarGridWidgetView(entry: entry)
        }
        .configurationDisplayName("カレンダー")
        .description("月間カレンダーで予定を確認できます")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
