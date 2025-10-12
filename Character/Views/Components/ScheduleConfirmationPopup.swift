import SwiftUI
import FirebaseFirestore

struct ScheduleConfirmationPopup: View {
    let scheduleData: ExtractedScheduleData
    let onConfirm: (ExtractedScheduleData, String) -> Void  // タグを追加
    let onCancel: () -> Void
    let onEdit: (ExtractedScheduleData) -> Void

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var selectedTag: String = ""

    private var tagSettings: TagSettingsManager {
        TagSettingsManager.shared
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20) {
                // タイトル
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("予定を追加しますか？")
                        .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                
                // 予定内容表示
                VStack(alignment: .leading, spacing: 12) {
                    if !scheduleData.title.isEmpty {
                        ScheduleInfoRow(icon: "textformat", title: "予定", content: scheduleData.title)
                    }

                    // 詳細な日時表示
                    if let startDate = scheduleData.startDate {
                        VStack(alignment: .leading, spacing: 8) {
                            ScheduleInfoRow(
                                icon: "calendar",
                                title: "開始",
                                content: formatDateTime(startDate, isAllDay: scheduleData.isAllDay)
                            )

                            if let endDate = scheduleData.endDate {
                                ScheduleInfoRow(
                                    icon: "calendar",
                                    title: "終了",
                                    content: formatDateTime(endDate, isAllDay: scheduleData.isAllDay)
                                )
                            }
                        }
                    } else if !scheduleData.date.isEmpty {
                        ScheduleInfoRow(icon: "calendar", title: "日時", content: scheduleData.date)
                    } else {
                        // デバッグ用：日時情報がない場合
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                                .frame(width: 20)

                            Text("⚠️ 日時情報を取得できませんでした")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                    }

                    if !scheduleData.location.isEmpty {
                        ScheduleInfoRow(icon: "location", title: "場所", content: scheduleData.location)
                    }

                    // タグ選択
                    tagSelectionRow

                    if !scheduleData.memo.isEmpty {
                        ScheduleInfoRow(icon: "note.text", title: "メモ", content: scheduleData.memo)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                )
                
                // ボタン
                VStack(spacing: 12) {
                    // 編集と追加ボタン
                    HStack(spacing: 12) {
                        Button {
                            onEdit(scheduleData)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14 * fontSettings.fontSize.scale))
                                Text("編集")
                                    .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange)
                            )
                        }

                        Button {
                            onConfirm(scheduleData, selectedTag)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14 * fontSettings.fontSize.scale))
                                Text("追加する")
                                    .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                        }
                    }

                    // キャンセルボタン
                    Button("キャンセル") {
                        onCancel()
                    }
                    .font(.system(size: 16 * fontSettings.fontSize.scale))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.systemBackground) : Color.white)
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 32)
        }
    }

    // タグ選択行
    private var tagSelectionRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 14 * fontSettings.fontSize.scale))
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("タグ")
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .medium))
                    .foregroundColor(.secondary)

                tagPicker
            }

            Spacer()
        }
    }

    // タグピッカー
    private var tagPicker: some View {
        Picker("", selection: $selectedTag) {
            Text("タグを選択").tag("")
            ForEach(tagSettings.tags) { tag in
                Text(tag.name).tag(tag.name)
            }
        }
        .pickerStyle(.menu)
        .tint(.primary)
    }

    // 日時フォーマット用ヘルパー関数
    private func formatDateTime(_ date: Date, isAllDay: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current

        if isAllDay {
            formatter.dateFormat = "yyyy年M月d日(E)"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yyyy年M月d日(E) HH:mm"
            return formatter.string(from: date)
        }
    }
}

struct ScheduleInfoRow: View {
    let icon: String
    let title: String
    let content: String
    
    @EnvironmentObject var fontSettings: FontSettingsManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14 * fontSettings.fontSize.scale))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(content)
                    .font(.system(size: 16 * fontSettings.fontSize.scale))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

struct ExtractedScheduleData {
    let title: String
    let date: String
    let location: String
    let memo: String
    let isAllDay: Bool
    let startDate: Date?
    let endDate: Date?

    // ISO8601文字列をパースするヘルパーメソッド
    private static func parseISODate(_ dateString: String) -> Date? {
        print("🔍 Parsing date string: \(dateString)")

        // 方法1: ISO8601DateFormatterでタイムゾーン付き形式をパース
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            print("✅ Parsed with method 1 (ISO8601 with fractional seconds): \(date)")
            return date
        }

        // 方法2: タイムゾーン付き（秒まで）の形式を試す
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            print("✅ Parsed with method 2 (ISO8601 standard): \(date)")
            return date
        }

        // 方法3: タイムゾーンなしの場合、DateFormatterでJSTとして解釈
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        fallbackFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = fallbackFormatter.date(from: dateString) {
            print("✅ Parsed with method 3 (DateFormatter no timezone): \(date)")
            return date
        }

        // 方法4: タイムゾーン付きの形式を手動でパース
        // "2025-10-13T15:00:00+09:00" の形式
        let manualFormatter = DateFormatter()
        manualFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        manualFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = manualFormatter.date(from: dateString) {
            print("✅ Parsed with method 4 (DateFormatter with Z): \(date)")
            return date
        }

        print("❌ Failed to parse date string with all methods")
        return nil
    }

    init(from dict: [String: Any]) {
        print("📦 ExtractedScheduleData init with dict: \(dict)")

        self.title = dict["title"] as? String ?? ""
        self.date = dict["date"] as? String ?? ""
        self.location = dict["location"] as? String ?? ""
        self.memo = dict["memo"] as? String ?? ""
        self.isAllDay = dict["isAllDay"] as? Bool ?? false

        // Cloud Functionから返される日付データの処理
        print("🔍 startDate type: \(type(of: dict["startDate"]))")
        if let startTimestamp = dict["startDate"] as? Timestamp {
            print("✅ startDate is Timestamp")
            self.startDate = startTimestamp.dateValue()
        } else if let startDateString = dict["startDate"] as? String {
            print("✅ startDate is String: \(startDateString)")
            self.startDate = Self.parseISODate(startDateString)
        } else if let timestampDict = dict["startDate"] as? [String: Any],
                  let seconds = timestampDict["_seconds"] as? TimeInterval {
            // Firebase Timestampが辞書として返される場合
            print("✅ startDate is Timestamp dict with _seconds: \(seconds)")
            self.startDate = Date(timeIntervalSince1970: seconds)
        } else {
            print("❌ startDate could not be parsed")
            self.startDate = nil
        }

        print("🔍 endDate type: \(type(of: dict["endDate"]))")
        if let endTimestamp = dict["endDate"] as? Timestamp {
            print("✅ endDate is Timestamp")
            self.endDate = endTimestamp.dateValue()
        } else if let endDateString = dict["endDate"] as? String {
            print("✅ endDate is String: \(endDateString)")
            self.endDate = Self.parseISODate(endDateString)
        } else if let timestampDict = dict["endDate"] as? [String: Any],
                  let seconds = timestampDict["_seconds"] as? TimeInterval {
            // Firebase Timestampが辞書として返される場合
            print("✅ endDate is Timestamp dict with _seconds: \(seconds)")
            self.endDate = Date(timeIntervalSince1970: seconds)
        } else {
            print("❌ endDate could not be parsed")
            self.endDate = nil
        }

        print("📊 Final parsed dates - startDate: \(String(describing: self.startDate)), endDate: \(String(describing: self.endDate))")
    }
}

#Preview {
    ScheduleConfirmationPopup(
        scheduleData: ExtractedScheduleData(from: [
            "title": "会議",
            "date": "2024年1月15日 14:00",
            "location": "会議室A",
            "memo": "プロジェクトの進捗確認",
            "isAllDay": false
        ]),
        onConfirm: { _, _ in },
        onCancel: { },
        onEdit: { _ in }
    )
    .environmentObject(FontSettingsManager())
}