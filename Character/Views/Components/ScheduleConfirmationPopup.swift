import SwiftUI
import FirebaseFirestore

struct ScheduleConfirmationPopup: View {
    let scheduleData: ExtractedScheduleData
    let onConfirm: (ExtractedScheduleData) -> Void
    let onCancel: () -> Void
    
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
                    
                    if !scheduleData.date.isEmpty {
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
                HStack(spacing: 16) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray4))
                    )
                    
                    Button("追加する") {
                        onConfirm(scheduleData)
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
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.systemBackground) : Color.white)
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 32)
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
        
        if let startTimestamp = dict["startDate"] as? Timestamp {
            self.startDate = startTimestamp.dateValue()
        } else {
            self.startDate = nil
        }
        
        if let endTimestamp = dict["endDate"] as? Timestamp {
            self.endDate = endTimestamp.dateValue()
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
        onCancel: { }
    )
    .environmentObject(FontSettingsManager())
}