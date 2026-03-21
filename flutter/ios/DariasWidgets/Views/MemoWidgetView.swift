//
//  MemoWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import UIKit
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
        case .systemLarge:
            LargeMemoView(entry: entry)
        default:
            SmallMemoView(entry: entry)
        }
    }
}

// MARK: - Small

struct SmallMemoView: View {
    var entry: MemoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("メモ")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
            }

            if let memo = entry.memos.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        if memo.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(memo.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(WidgetColors.textPrimary)
                            .lineLimit(1)
                    }
                    Text(memo.contentOneLine)
                        .font(.caption2)
                        .foregroundColor(WidgetColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundStyle(WidgetColors.accentGradient)
                    Text("メモなし")
                        .font(.caption2)
                        .foregroundColor(WidgetColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=memo&homeWidget"))
    }
}

// MARK: - Medium

struct MediumMemoView: View {
    var entry: MemoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("メモ")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
                Text("\(entry.totalCount)件")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WidgetColors.primaryPink.opacity(0.15))
                    .foregroundColor(WidgetColors.primaryPink)
                    .clipShape(Capsule())
            }

            if entry.memos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundStyle(WidgetColors.accentGradient)
                        Text("メモなし")
                            .font(.caption)
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(entry.memos.prefix(3)) { memo in
                    HStack(spacing: 6) {
                        if memo.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(memo.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(1)
                            Text(memo.contentOneLine)
                                .font(.caption)
                                .foregroundColor(WidgetColors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(memo.updatedText)
                            .font(.caption2)
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=memo&homeWidget"))
    }
}

// MARK: - Large

struct LargeMemoView: View {
    var entry: MemoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("メモ")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
                Text("\(entry.totalCount)件")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WidgetColors.primaryPink.opacity(0.15))
                    .foregroundColor(WidgetColors.primaryPink)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 10)

            if entry.memos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.largeTitle)
                            .foregroundStyle(WidgetColors.accentGradient)
                        Text("メモなし")
                            .font(.subheadline)
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(entry.memos.prefix(5)) { memo in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                if memo.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                Text(memo.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(WidgetColors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(memo.updatedText)
                                    .font(.caption2)
                                    .foregroundColor(WidgetColors.textSecondary)
                            }
                            Text(memo.contentOneLine)
                                .font(.caption)
                                .foregroundColor(WidgetColors.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 7)
                        Divider()
                            .background(WidgetColors.primaryPink.opacity(0.2))
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=memo&homeWidget"))
    }
}
