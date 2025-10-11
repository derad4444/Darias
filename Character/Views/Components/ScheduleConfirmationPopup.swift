import SwiftUI
import FirebaseFirestore

struct ScheduleConfirmationPopup: View {
    let scheduleData: ExtractedScheduleData
    let onConfirm: (ExtractedScheduleData) -> Void
    let onCancel: () -> Void
    let onEdit: (ExtractedScheduleData) -> Void

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var fontSettings: FontSettingsManager
    
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
                                title: "開始日時",
                                content: formatDateTime(startDate, isAllDay: scheduleData.isAllDay)
                            )

                            if let endDate = scheduleData.endDate {
                                ScheduleInfoRow(
                                    icon: "calendar",
                                    title: "終了日時",
                                    content: formatDateTime(endDate, isAllDay: scheduleData.isAllDay)
                                )
                            }
                        }
                    } else if !scheduleData.date.isEmpty {
                        ScheduleInfoRow(icon: "calendar", title: "日時", content: scheduleData.date)
                    }

                    if !scheduleData.location.isEmpty {
                        ScheduleInfoRow(icon: "location", title: "場所", content: scheduleData.location)
                    }

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
                            onConfirm(scheduleData)
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
    
    init(from dict: [String: Any]) {
        self.title = dict["title"] as? String ?? ""
        self.date = dict["date"] as? String ?? ""
        self.location = dict["location"] as? String ?? ""
        self.memo = dict["memo"] as? String ?? ""
        self.isAllDay = dict["isAllDay"] as? Bool ?? false
        
        // Cloud Functionから返される日付データの処理
        if let startTimestamp = dict["startDate"] as? Timestamp {
            self.startDate = startTimestamp.dateValue()
        } else if let startDateString = dict["startDate"] as? String {
            let formatter = ISO8601DateFormatter()
            self.startDate = formatter.date(from: startDateString)
        } else {
            self.startDate = nil
        }
        
        if let endTimestamp = dict["endDate"] as? Timestamp {
            self.endDate = endTimestamp.dateValue()
        } else if let endDateString = dict["endDate"] as? String {
            let formatter = ISO8601DateFormatter()
            self.endDate = formatter.date(from: endDateString)
        } else {
            self.endDate = nil
        }
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
        onConfirm: { _ in },
        onCancel: { },
        onEdit: { _ in }
    )
    .environmentObject(FontSettingsManager())
}