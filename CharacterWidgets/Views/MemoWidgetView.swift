//
//  MemoWidgetView.swift
//  CharacterWidgets
//
//  メモウィジェットのビュー
//

import SwiftUI
import WidgetKit

// MARK: - Entry View

struct MemoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MemoWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            MemoWidgetSmallView(entry: entry)
        case .systemMedium:
            MemoWidgetMediumView(entry: entry)
        case .systemLarge:
            MemoWidgetLargeView(entry: entry)
        @unknown default:
            MemoWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Small View

struct MemoWidgetSmallView: View {
    let entry: MemoWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FFE8B8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                // ヘッダー
                HStack {
                    Text("📝")
                        .font(.system(size: 20))
                    Text("メモ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    if entry.totalCount > 0 {
                        Text("\(entry.totalCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // 最新のメモ
                if let memo = entry.memos.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memo.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text(memo.contentOneLine)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .minimumScaleFactor(0.9)

                        Spacer(minLength: 0)

                        HStack {
                            if memo.isPinned {
                                Text("📌")
                                    .font(.system(size: 10))
                            }
                            if !memo.tag.isEmpty {
                                Text(memo.tag)
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Text(memo.updatedText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 12)
                } else {
                    Spacer()
                    Text("メモなし")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Medium View

struct MemoWidgetMediumView: View {
    let entry: MemoWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FFE8B8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 4) {
                // ヘッダー
                HStack {
                    Text("📝")
                        .font(.system(size: 16))
                    Text("メモ")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    if entry.totalCount > 0 {
                        Text("\(entry.totalCount)件")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                // メモリスト
                if entry.memos.isEmpty {
                    Spacer()
                    Text("メモなし")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entry.memos.prefix(3)) { memo in
                            HStack(alignment: .top, spacing: 6) {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        if memo.isPinned {
                                            Text("📌")
                                                .font(.system(size: 9))
                                        }
                                        Text(memo.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                    }

                                    Text(memo.contentOneLine)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)

                                    HStack(spacing: 4) {
                                        if !memo.tag.isEmpty {
                                            Text(memo.tag)
                                                .font(.system(size: 8))
                                                .foregroundColor(.orange)
                                        }
                                        Spacer()
                                        Text(memo.updatedText)
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)

                            if memo.id != entry.memos.prefix(3).last?.id {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Large View

struct MemoWidgetLargeView: View {
    let entry: MemoWidgetEntry

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color(hex: "FFF9E6"), Color(hex: "FFE8B8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 6) {
                // ヘッダー
                HStack {
                    Text("📝")
                        .font(.system(size: 20))
                    Text("メモ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    if entry.totalCount > 0 {
                        Text("\(entry.totalCount)件")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // メモリスト
                if entry.memos.isEmpty {
                    Spacer()
                    Text("メモなし")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entry.memos.prefix(5)) { memo in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    if memo.isPinned {
                                        Text("📌")
                                            .font(.system(size: 11))
                                    }
                                    Text(memo.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }

                                Text(memo.contentPreview)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)

                                HStack {
                                    if !memo.tag.isEmpty {
                                        Text(memo.tag)
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                    }
                                    Spacer()
                                    Text(memo.updatedText)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)

                            if memo.id != entry.memos.prefix(5).last?.id {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 6)
        }
    }
}
