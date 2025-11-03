import SwiftUI

struct MemoCardView: View {
    let memo: Memo
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

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

            // 内容プレビュー
            Text(memo.content)
                .dynamicBody()
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // フッター（日付+タグ）
            HStack {
                if !memo.tag.isEmpty {
                    Text(memo.tag)
                        .dynamicCaption()
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorSettings.getCurrentAccentColor().opacity(0.1))
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
