//
//  MemoWidget.swift
//  CharacterWidgets
//
//  メモウィジェットの定義
//

import WidgetKit
import SwiftUI

struct MemoWidget: Widget {
    let kind: String = "MemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                MemoWidgetEntryView(entry: entry)
                    .environment(\.colorScheme, .light)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MemoWidgetEntryView(entry: entry)
                    .environment(\.colorScheme, .light)
            }
        }
        .configurationDisplayName("DARIAS メモ")
        .description("最新のメモを確認できます")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    MemoWidget()
} timeline: {
    let sampleMemo = WidgetMemo(
        id: "1",
        title: "サンプルメモ",
        content: "これはサンプルのメモです。",
        updatedAt: Date(),
        tag: "仕事",
        isPinned: true
    )

    MemoWidgetEntry(
        date: Date(),
        memos: [sampleMemo],
        totalCount: 1
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    MemoWidget()
} timeline: {
    let memos = [
        WidgetMemo(
            id: "1",
            title: "重要なメモ",
            content: "これは重要なメモです。",
            updatedAt: Date(),
            tag: "重要",
            isPinned: true
        ),
        WidgetMemo(
            id: "2",
            title: "買い物リスト",
            content: "牛乳、卵、パン",
            updatedAt: Date().addingTimeInterval(-3600),
            tag: "買い物",
            isPinned: false
        )
    ]

    MemoWidgetEntry(
        date: Date(),
        memos: memos,
        totalCount: 5
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    MemoWidget()
} timeline: {
    let memos = [
        WidgetMemo(
            id: "1",
            title: "重要なメモ",
            content: "これは重要なメモです。\n詳細な内容がここに表示されます。",
            updatedAt: Date(),
            tag: "重要",
            isPinned: true
        ),
        WidgetMemo(
            id: "2",
            title: "買い物リスト",
            content: "牛乳、卵、パン、バナナ、りんご",
            updatedAt: Date().addingTimeInterval(-3600),
            tag: "買い物",
            isPinned: false
        ),
        WidgetMemo(
            id: "3",
            title: "アイデア",
            content: "新しいプロジェクトのアイデアをメモ",
            updatedAt: Date().addingTimeInterval(-7200),
            tag: "アイデア",
            isPinned: false
        )
    ]

    MemoWidgetEntry(
        date: Date(),
        memos: memos,
        totalCount: 10
    )
}
