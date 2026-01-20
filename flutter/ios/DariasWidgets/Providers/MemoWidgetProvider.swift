//
//  MemoWidgetProvider.swift
//  DariasWidgets
//

import WidgetKit
import SwiftUI

struct MemoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoWidgetEntry {
        MemoWidgetEntry(
            date: Date(),
            memos: [
                WidgetMemo(
                    id: "1",
                    title: "サンプルメモ",
                    content: "メモの内容がここに表示されます",
                    updatedAt: Date(),
                    tag: "",
                    isPinned: true
                )
            ],
            totalCount: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoWidgetEntry) -> Void) {
        let memos = WidgetDataCache.shared.loadMemos()
        let totalCount = WidgetDataCache.shared.loadMemosTotalCount()
        let entry = MemoWidgetEntry(date: Date(), memos: memos, totalCount: totalCount)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoWidgetEntry>) -> Void) {
        let memos = WidgetDataCache.shared.loadMemos()
        let totalCount = WidgetDataCache.shared.loadMemosTotalCount()
        let entry = MemoWidgetEntry(date: Date(), memos: memos, totalCount: totalCount)

        // 15分ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}
