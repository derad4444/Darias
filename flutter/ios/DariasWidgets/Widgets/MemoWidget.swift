//
//  MemoWidget.swift
//  DariasWidgets
//

import SwiftUI
import WidgetKit

struct MemoWidget: Widget {
    let kind: String = "MemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoWidgetProvider()) { entry in
            MemoWidgetView(entry: entry)
        }
        .configurationDisplayName("メモ")
        .description("最新のメモを確認できます")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
