//
//  MemoWidgetProvider.swift
//  CharacterWidgets
//
//  メモウィジェット用のTimelineProvider
//

import WidgetKit
import SwiftUI

struct MemoWidgetProvider: TimelineProvider {

    // MARK: - Placeholder

    func placeholder(in context: Context) -> MemoWidgetEntry {
        let sampleMemos = [
            WidgetMemo(
                id: "1",
                title: "サンプルメモ",
                content: "これはサンプルのメモです。\n実際のメモがここに表示されます。",
                updatedAt: Date(),
                tag: "仕事",
                isPinned: true
            )
        ]

        return MemoWidgetEntry(
            date: Date(),
            memos: sampleMemos,
            totalCount: 1
        )
    }

    // MARK: - Snapshot

    func getSnapshot(in context: Context, completion: @escaping (MemoWidgetEntry) -> Void) {
        let (memos, totalCount) = WidgetDataCache.shared.getMemos()
        let entry = MemoWidgetEntry(
            date: Date(),
            memos: memos,
            totalCount: totalCount
        )
        completion(entry)
    }

    // MARK: - Timeline

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoWidgetEntry>) -> Void) {
        let (memos, totalCount) = WidgetDataCache.shared.getMemos()
        let currentDate = Date()

        let entry = MemoWidgetEntry(
            date: currentDate,
            memos: memos,
            totalCount: totalCount
        )

        // 15分ごとに更新
        let calendar = Calendar.current
        let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
