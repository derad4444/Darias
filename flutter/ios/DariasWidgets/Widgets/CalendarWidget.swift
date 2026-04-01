//
//  CalendarWidget.swift
//  DariasWidgets
//

import SwiftUI
import WidgetKit


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
