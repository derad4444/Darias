//
//  MemoWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import WidgetKit

struct MemoWidgetView: View {
    var entry: MemoWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallMemoView(entry: entry)
        case .systemMedium:
            MediumMemoView(entry: entry)
        default:
            SmallMemoView(entry: entry)
        }
    }
}

struct SmallMemoView: View {
    var entry: MemoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.orange)
                Text("メモ")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            if let memo = entry.memos.first {
                VStack(alignment: .leading, spacing: 4) {
                    if memo.isPinned {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(memo.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    } else {
                        Text(memo.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    Text(memo.contentOneLine)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            } else {
                Spacer()
                Text("メモなし")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumMemoView: View {
    var entry: MemoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.orange)
                Text("メモ")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(entry.totalCount)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if entry.memos.isEmpty {
                HStack {
                    Spacer()
                    Text("メモなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical)
            } else {
                ForEach(entry.memos.prefix(3)) { memo in
                    HStack {
                        if memo.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(memo.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(memo.contentOneLine)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(memo.updatedText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
