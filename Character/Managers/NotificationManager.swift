import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // 通知許可の確認
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // 通知許可をリクエスト
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    // Notification permission error handled silently
                }
            }
        }
    }
    
    // 予定の通知を設定
    func scheduleNotification(for schedule: ScheduleItem, notificationSettings: NotificationSettings) {
        guard isAuthorized else { return }
        
        // 既存の通知を削除
        removeNotification(for: schedule.id)
        
        // 通知が無効の場合は何もしない
        guard notificationSettings.isEnabled else { return }
        
        // 通知時刻を計算
        let notificationDate = calculateNotificationDate(
            scheduleDate: schedule.startDate,
            value: notificationSettings.value,
            unit: notificationSettings.unit
        )
        
        // 過去の時刻の場合は通知しない
        guard notificationDate > Date() else { return }
        
        // 通知コンテンツを作成
        let content = UNMutableNotificationContent()
        content.title = "予定の通知"
        content.body = schedule.title
        content.sound = .default
        
        // 場所がある場合は追加
        if !schedule.location.isEmpty {
            content.body += "\n場所: \(schedule.location)"
        }
        
        // 通知時刻を設定
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // 通知リクエストを作成
        let request = UNNotificationRequest(
            identifier: "schedule_\(schedule.id)",
            content: content,
            trigger: trigger
        )
        
        // 通知を登録
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // Notification registration error handled silently
            }
        }
    }
    
    // 通知時刻を計算
    private func calculateNotificationDate(scheduleDate: Date, value: Int, unit: NotificationUnit) -> Date {
        let calendar = Calendar.current
        
        switch unit {
        case .minutes:
            return calendar.date(byAdding: .minute, value: -value, to: scheduleDate) ?? scheduleDate
        case .hours:
            return calendar.date(byAdding: .hour, value: -value, to: scheduleDate) ?? scheduleDate
        case .days:
            return calendar.date(byAdding: .day, value: -value, to: scheduleDate) ?? scheduleDate
        }
    }
    
    // 特定の予定の通知を削除
    func removeNotification(for scheduleId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["schedule_\(scheduleId)"])
    }
    
    // 全ての通知を削除
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // 登録済み通知を確認（デバッグ用）
    func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Debug: Pending notification count: \(requests.count)
            for request in requests {
                // Debug: \(request.identifier): \(request.content.title)
            }
        }
    }
}

// 通知単位の列挙型
enum NotificationUnit: String, CaseIterable {
    case minutes = "分前"
    case hours = "時間前"
    case days = "日前"
    
    var displayName: String {
        return self.rawValue
    }
}

// 通知設定の構造体
struct NotificationSettings {
    var isEnabled: Bool = false
    var value: Int = 15
    var unit: NotificationUnit = .minutes
    
    func getDescription() -> String {
        if !isEnabled {
            return "通知しない"
        }
        return "\(value)\(unit.displayName)"
    }
}