//
//  TodoWidget.swift
//  DariasWidgets
//

import SwiftUI
import WidgetKit

struct TodoWidget: Widget {
    let kind: String = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("Todo")
        .description("今日のタスクを確認できます")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
