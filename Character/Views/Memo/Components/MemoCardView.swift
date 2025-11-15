import SwiftUI

struct MemoCardView: View {
    let memo: Memo
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var tagSettings = TagSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    // タグの色を取得（設定されていない場合はアクセントカラー）
    private var tagColor: Color {
        if !memo.tag.isEmpty, let tag = tagSettings.getTag(by: memo.tag) {
            return tag.color
        }
        return colorSettings.getCurrentAccentColor()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー（タイトル+ピン）
            HStack {
                Text(memo.title)
                    .dynamicHeadline()
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if memo.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                        .font(.caption)
                }
            }

            // 内容プレビュー（マークダウン対応）
            MarkdownText(memo.content, fontSize: 16, color: .secondary, lineLimit: 2)
                .multilineTextAlignment(.leading)
                .environmentObject(fontSettings)

            // フッター（日付+タグ）
            HStack {
                if !memo.tag.isEmpty {
                    Text(memo.tag)
                        .dynamicCaption()
                        .foregroundColor(tagColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tagColor.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()

                Text(formatDate(memo.updatedAt))
                    .dynamicCaption()
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

// マークダウンレンダリング用ヘルパーView
struct MarkdownText: View {
    let text: String
    let fontSize: CGFloat
    let color: Color
    let lineLimit: Int?
    @EnvironmentObject var fontSettings: FontSettingsManager

    init(_ text: String, fontSize: CGFloat = 16, color: Color = .primary, lineLimit: Int? = nil) {
        self.text = text
        self.fontSize = fontSize
        self.color = color
        self.lineLimit = lineLimit
    }

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        let displayLines = lineLimit != nil ? Array(lines.prefix(lineLimit!)) : lines

        // 全ての行を一つのAttributedStringとして構築
        let combinedText = buildCombinedAttributedString(from: displayLines)

        Text(combinedText)
            .font(.system(size: fontSize * fontSettings.fontSize.scale))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private func buildCombinedAttributedString(from lines: [String]) -> AttributedString {
        var result = AttributedString()

        for (index, line) in lines.enumerated() {
            if index > 0 {
                result += AttributedString("\n")
            }

            if line.isEmpty {
                // 空行
                result += AttributedString(" ")
            } else if line.hasPrefix("### ") {
                // 見出し3
                var content = AttributedString(String(line.dropFirst(4)))
                content.font = .system(size: (fontSize + 2) * fontSettings.fontSize.scale, weight: .semibold)
                result += content
            } else if line.hasPrefix("## ") {
                // 見出し2
                var content = AttributedString(String(line.dropFirst(3)))
                content.font = .system(size: (fontSize + 4) * fontSettings.fontSize.scale, weight: .semibold)
                result += content
            } else if line.hasPrefix("# ") {
                // 見出し1
                var content = AttributedString(String(line.dropFirst(2)))
                content.font = .system(size: (fontSize + 6) * fontSettings.fontSize.scale, weight: .bold)
                result += content
            } else if line.hasPrefix("> ") {
                // 引用
                var quoteMark = AttributedString("│ ")
                quoteMark.foregroundColor = .gray
                var content = AttributedString(String(line.dropFirst(2)))
                if let attributedContent = try? AttributedString(markdown: String(line.dropFirst(2))) {
                    content = attributedContent
                }
                content.inlinePresentationIntent = .emphasized
                result += quoteMark + content
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                // 箇条書き
                var bullet = AttributedString("  • ")
                var content = AttributedString(String(line.dropFirst(2)))
                if let attributedContent = try? AttributedString(markdown: String(line.dropFirst(2))) {
                    content = attributedContent
                }
                result += bullet + content
            } else if let match = line.range(of: #"^(\d+)\. "#, options: .regularExpression),
                      match.lowerBound == line.startIndex {
                // 番号付きリスト
                var number = AttributedString("  " + String(line[match]))
                var content = AttributedString(String(line[match.upperBound...]))
                if let attributedContent = try? AttributedString(markdown: String(line[match.upperBound...])) {
                    content = attributedContent
                }
                result += number + content
            } else {
                // 通常の行（マークダウン対応）
                if let attributedString = try? AttributedString(markdown: line) {
                    result += attributedString
                } else {
                    result += AttributedString(line)
                }
            }
        }

        return result
    }
}
