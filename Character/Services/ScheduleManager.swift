import Foundation
import FirebaseFirestore
import FirebaseAuth

class ScheduleManager: ObservableObject {
    private let db = Firestore.firestore()
    
    func saveSchedule(from scheduleData: ExtractedScheduleData) {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ ユーザーが認証されていません")
            return
        }
        
        let userId = currentUser.uid
        
        // Schedule ドキュメントの作成
        let scheduleDocument = db.collection("Schedule").document()
        let scheduleId = scheduleDocument.documentID
        
        var scheduleDataDict: [String: Any] = [
            "id": scheduleId,
            "user_id": userId,
            "title": scheduleData.title,
            "isAllDay": scheduleData.isAllDay,
            "tag": "", // デフォルトは空文字
            "created_at": Timestamp()
        ]
        
        // 開始日時の設定
        if let startDate = scheduleData.startDate {
            scheduleDataDict["date"] = Timestamp(date: startDate)
        } else {
            // startDateがない場合は現在時刻を使用
            scheduleDataDict["date"] = Timestamp()
        }
        
        // Schedule コレクションに保存
        scheduleDocument.setData(scheduleDataDict) { [weak self] error in
            if let error = error {
                print("❌ Schedule保存エラー: \(error.localizedDescription)")
            } else {
                print("✅ Schedule保存成功: \(scheduleId)")
                
                // ScheduleItem サブコレクションに詳細情報を保存
                self?.saveScheduleItem(scheduleId: scheduleId, scheduleData: scheduleData)
            }
        }
    }
    
    private func saveScheduleItem(scheduleId: String, scheduleData: ExtractedScheduleData) {
        let scheduleItemDocument = db.collection("Schedule").document(scheduleId)
            .collection("ScheduleItem").document()
        
        var scheduleItemData: [String: Any] = [
            "id": scheduleItemDocument.documentID,
            "schedule_id": scheduleId,
            "title": scheduleData.title,
            "location": scheduleData.location,
            "memo": scheduleData.memo,
            "isAllDay": scheduleData.isAllDay,
            "repeatOption": "none", // デフォルト値
            "remindValue": 15, // デフォルト15分前
            "remindUnit": "minutes", // デフォルト分単位
            "created_at": Timestamp()
        ]
        
        // 開始日時の設定
        if let startDate = scheduleData.startDate {
            scheduleItemData["startDate"] = Timestamp(date: startDate)
        }
        
        // 終了日時の設定
        if let endDate = scheduleData.endDate {
            scheduleItemData["endDate"] = Timestamp(date: endDate)
        } else if let startDate = scheduleData.startDate {
            // 終了日時が指定されていない場合は開始日時の1時間後を設定
            let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
            scheduleItemData["endDate"] = Timestamp(date: endDate)
        }
        
        // ScheduleItem サブコレクションに保存
        scheduleItemDocument.setData(scheduleItemData) { error in
            if let error = error {
                print("❌ ScheduleItem保存エラー: \(error.localizedDescription)")
            } else {
                print("✅ ScheduleItem保存成功: \(scheduleItemDocument.documentID)")
                
                // 通知を設定
                self.scheduleNotification(for: scheduleData)
            }
        }
    }
    
    private func scheduleNotification(for scheduleData: ExtractedScheduleData) {
        guard let startDate = scheduleData.startDate else { return }
        
        // 15分前に通知を設定
        let notificationDate = Calendar.current.date(byAdding: .minute, value: -15, to: startDate)
        
        guard let notificationDate = notificationDate, notificationDate > Date() else {
            print("⚠️ 通知時刻が過去のため、通知を設定しませんでした")
            return
        }
        
        let notificationManager = NotificationManager.shared
        let notificationSettings = NotificationSettings(
            isEnabled: true,
            value: 15,
            unit: .minutes
        )
        
        // 仮のScheduleItemを作成（通知設定用）
        let scheduleItem = ScheduleItem(
            id: UUID().uuidString,
            title: scheduleData.title,
            isAllDay: scheduleData.isAllDay,
            startDate: startDate,
            endDate: scheduleData.endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!,
            location: scheduleData.location,
            tag: "", // デフォルト値
            memo: scheduleData.memo,
            repeatOption: "none",
            remindValue: 15,
            remindUnit: "minutes"
        )
        
        notificationManager.scheduleNotification(for: scheduleItem, notificationSettings: notificationSettings)
        print("✅ 通知設定完了: \(scheduleData.title)")
    }
}