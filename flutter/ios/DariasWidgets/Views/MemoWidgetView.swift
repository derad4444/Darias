//
//  MemoWidgetView.swift
//  DariasWidgets
//

import SwiftUI
import UIKit
import WidgetKit

// MARK: - Tag Badge

private struct TagBadge: View {
    let name: String
    let color: Color
    var fontSize: CGFloat = 9

    var body: some View {
        Text(name)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Main View

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

// MARK: - Memo Item Block
// 件数に応じて均等分割されるメモ1件分のブロック

private struct MemoItemBlock: View {
    let memo: WidgetMemo
    let titleFontSize: CGFloat
    let contentFontSize: CGFloat
    let showDate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // タイトル行
            HStack(spacing: 4) {
                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: titleFontSize - 2))
                        .foregroundColor(.orange)
                }
                Text(memo.title)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .foregroundColor(WidgetColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !memo.tag.isEmpty, let color = memo.tagColor {
                    TagBadge(name: memo.tag, color: color, fontSize: contentFontSize - 1)
                }
            }
            // 本文（残り空間をすべて使う）
            Text(memo.content.isEmpty ? "内容なし" : memo.content)
                .font(.system(size: contentFontSize))
                .foregroundColor(WidgetColors.textSecondary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // 更新日
            if showDate {
                Text(memo.updatedText)
                    .font(.system(size: contentFontSize - 1))
                    .foregroundColor(WidgetColors.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Adaptive Memo List
// 件数に応じて均等分割レイアウトを組む共通ビュー

private struct AdaptiveMemoList: View {
    let memos: [WidgetMemo]
    let titleFontSize: CGFloat
    let contentFontSize: CGFloat
    let showDate: Bool
    let spacing: CGFloat

    var body: some View {
        if memos.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.title2)
                    .foregroundStyle(WidgetColors.accentGradient)
                Text("ウィジェット表示メモなし")
                    .font(.caption2)
                    .foregroundColor(WidgetColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(memos.enumerated()), id: \.element.id) { index, memo in
                    MemoItemBlock(
                        memo: memo,
                        titleFontSize: titleFontSize,
                        contentFontSize: contentFontSize,
                        showDate: showDate
                    )
                    // 最後のアイテム以外に区切り線
                    if index < memos.count - 1 {
                        Divider()
                            .background(WidgetColors.primaryPink.opacity(0.25))
                            .padding(.vertical, spacing / 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Small

struct SmallMemoView: View {
    var entry: MemoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ヘッダー
            HStack(spacing: 6) {
                Image("DariasIcon")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("メモ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(WidgetColors.primaryPink)
                Spacer()
                if !entry.memos.isEmpty {
                    Text("\(entry.memos.count)件")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetColors.primaryPink)
                }
            }

            // メモ一覧（均等分割）
            AdaptiveMemoList(
                memos: entry.memos,
                titleFontSize: 11,
                contentFontSize: 10,
                showDate: false,
                spacing: 4
            )
        }
        .padding(10)
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
            // ヘッダー
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
                if !entry.memos.isEmpty {
                    Text("\(entry.memos.count)件")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WidgetColors.primaryPink.opacity(0.15))
                        .foregroundColor(WidgetColors.primaryPink)
                        .clipShape(Capsule())
                }
            }

            // メモ一覧（均等分割）
            AdaptiveMemoList(
                memos: entry.memos,
                titleFontSize: 12,
                contentFontSize: 11,
                showDate: entry.memos.count <= 2,
                spacing: 6
            )
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
            // ヘッダー
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
                if !entry.memos.isEmpty {
                    Text("\(entry.memos.count)件")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WidgetColors.primaryPink.opacity(0.15))
                        .foregroundColor(WidgetColors.primaryPink)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 10)

            // メモ一覧（均等分割）
            AdaptiveMemoList(
                memos: entry.memos,
                titleFontSize: 13,
                contentFontSize: 12,
                showDate: true,
                spacing: 8
            )
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
        .widgetURL(URL(string: "darias://open/?page=memo&homeWidget"))
    }
}
