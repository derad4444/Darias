//
//  MemoWidgetViewTest.swift
//  CharacterWidgets
//
//  テスト用の簡素なメモウィジェットビュー
//

import SwiftUI
import WidgetKit

struct MemoWidgetEntryViewTest: View {
    var entry: MemoWidgetEntry

    var body: some View {
        ZStack {
            Color.yellow

            VStack {
                Text("📝 メモ")
                    .font(.headline)
                Text("\(entry.memos.count)件")
                    .font(.caption)

                if let memo = entry.memos.first {
                    Text(memo.title)
                        .font(.caption)
                        .padding()
                }
            }
        }
    }
}
