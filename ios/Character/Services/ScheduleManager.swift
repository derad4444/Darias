import Foundation
import FirebaseFirestore
import FirebaseAuth

class ScheduleManager: ObservableObject {
    private let db = Firestore.firestore()
    
    func saveSchedule(from scheduleData: ExtractedScheduleData, tag: String = "") {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            Logger.error("User not authenticated or invalid userId", category: Logger.authentication)
            return
        }

        // Firestoreに予定を保存
        let scheduleRef = db.collection("users").document(userId).collection("schedules").document()
        let scheduleDoc: [String: Any] = [
            "id": scheduleRef.documentID,
            "title": scheduleData.title,
            "isAllDay": scheduleData.isAllDay,
            "startDate": Timestamp(date: scheduleData.startDate ?? Date()),
            "endDate": Timestamp(date: scheduleData.endDate ?? Date()),
            "location": scheduleData.location,
            "tag": tag, // ポップアップで選択されたタグ
            "memo": scheduleData.memo,
            "repeatOption": "none", // デフォルト値
            "created_at": Timestamp(date: Date())
        ]
        
        scheduleRef.setData(scheduleDoc) { error in
            if let error = error {
            } else {
                
                // 通知設定
                self.scheduleNotification(for: scheduleData)
                
                // カレンダーのリフレッシュを通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .init("ScheduleAdded"),
                        object: nil
                    )
                }
            }
        }
    }
    
    
    private func scheduleNotification(for scheduleData: ExtractedScheduleData) {
        guard let startDate = scheduleData.startDate else { return }
        
        // 5分前に通知を設定
        let notificationDate = Calendar.current.date(byAdding: .minute, value: -5, to: startDate)
        
        guard let notificationDate = notificationDate, notificationDate > Date() else {
            return
        }
        
        let notificationManager = NotificationManager.shared
        let timing = NotificationTiming(value: 5, unit: .minutes)
        let notificationSettings = NotificationSettings(
            isEnabled: true,
            notifications: [timing]
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
        )
        
        notificationManager.scheduleNotification(for: scheduleItem, notificationSettings: notificationSettings)
    }
}