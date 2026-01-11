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
    
    // 予定の通知を設定（新しいバージョン）
    func scheduleNotifications(for schedule: ScheduleItem) {
        guard isAuthorized else { return }

        // 予定通知が無効化されている場合は何もしない
        let scheduleNotificationEnabled = UserDefaults.standard.bool(forKey: "scheduleNotificationEnabled")
        guard scheduleNotificationEnabled else {
            // 設定が無効の場合、既存の通知のみ削除して終了
            removeNotifications(for: schedule.id)
            return
        }

        // 既存の通知を削除
        removeNotifications(for: schedule.id)

        // 通知設定がない、または無効の場合は何もしない
        guard let notificationSettings = schedule.notificationSettings,
              notificationSettings.isEnabled,
              !notificationSettings.notifications.isEmpty else { return }

        // 各通知タイミングに対して通知を設定
        for (index, notification) in notificationSettings.notifications.enumerated() {
            let notificationDate = calculateNotificationDate(
                scheduleDate: schedule.startDate,
                value: notification.value,
                unit: notification.unit
            )

            // 過去の時刻の場合はスキップ
            guard notificationDate > Date() else { continue }

            // 通知コンテンツを作成
            let content = UNMutableNotificationContent()
            content.title = "予定の通知"
            content.body = schedule.title
            content.sound = .default
            content.userInfo = [
                "scheduleId": schedule.id,
                "notificationIndex": index
            ]

            // 場所がある場合は追加
            if !schedule.location.isEmpty {
                content.body += "\n場所: \(schedule.location)"
            }

            // メモがある場合は追加
            if !schedule.memo.isEmpty {
                content.subtitle = schedule.memo
            }

            // 通知時刻を設定
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            // 通知リクエストを作成（ユニークなIDを使用）
            let request = UNNotificationRequest(
                identifier: "schedule_\(schedule.id)_\(index)",
                content: content,
                trigger: trigger
            )

            // 通知を登録
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                }
            }
        }
    }

    // 既存のバージョン（下位互換性のため保持）
    func scheduleNotification(for schedule: ScheduleItem, notificationSettings: NotificationSettings) {
        // 新しいバージョンを使用
        var updatedSchedule = schedule
        updatedSchedule.notificationSettings = notificationSettings
        scheduleNotifications(for: updatedSchedule)
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
    
    // 特定の予定の通知を削除（新しいバージョン）
    func removeNotifications(for scheduleId: String) {
        // 予定IDで始まる全ての通知を取得して削除
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.compactMap { request in
                return request.identifier.hasPrefix("schedule_\(scheduleId)") ? request.identifier : nil
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }

    // 既存のバージョン（下位互換性のため保持）
    func removeNotification(for scheduleId: String) {
        removeNotifications(for: scheduleId)
    }
    
    // 全ての通知を削除
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // 繰り返し予定の通知を一括設定
    func scheduleRecurringNotifications(for schedules: [ScheduleItem]) {
        guard isAuthorized else { return }

        // iOSの通知制限（64件）を考慮
        let maxNotifications = 60 // 余裕を持って設定
        var totalNotifications = 0

        for schedule in schedules {
            guard let notificationSettings = schedule.notificationSettings,
                  notificationSettings.isEnabled,
                  !notificationSettings.notifications.isEmpty else { continue }

            // 制限に達した場合は停止
            if totalNotifications + notificationSettings.notifications.count > maxNotifications {
                break
            }

            scheduleNotifications(for: schedule)
            totalNotifications += notificationSettings.notifications.count
        }
    }

    // 予定の更新時の通知管理
    func updateNotifications(for schedule: ScheduleItem) {
        removeNotifications(for: schedule.id)
        scheduleNotifications(for: schedule)
    }

    // 登録済み通知を確認（デバッグ用）
    func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                }
            }
        }
    }

    // MARK: - Diary Notifications

    /// 新しい日記が作成されたときに通知を送信
    func sendDiaryNotification(characterName: String, diaryId: String, characterId: String, userId: String, date: Date) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "新しい日記が届きました"
        content.body = "\(characterName)が日記を書きました"
        content.sound = .default
        content.badge = 1

        // 日記を開くための情報を追加
        content.userInfo = [
            "type": "diary",
            "diaryId": diaryId,
            "characterId": characterId,
            "userId": userId
        ]

        // 即座に通知を表示（1秒後）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "diary_\(diaryId)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 日記通知エラー: \(error.localizedDescription)")
            } else {
                print("✅ 日記通知を送信しました: \(diaryId)")
            }
        }
    }

    /// 毎日の日記通知をスケジュール（毎日23:55）
    func scheduleDailyDiaryNotification(characterName: String, characterId: String, userId: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "新しい日記が届きました"
        content.body = "\(characterName)が今日の日記を書きました"
        content.sound = .default
        content.badge = 1

        // 日記画面を開くための情報を追加
        content.userInfo = [
            "type": "daily_diary",
            "characterId": characterId,
            "userId": userId
        ]

        // 毎日23:55に通知（日記生成完了の5分後）
        var dateComponents = DateComponents()
        dateComponents.hour = 23
        dateComponents.minute = 55

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_diary_\(characterId)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 日記定期通知エラー: \(error.localizedDescription)")
            } else {
                print("✅ 日記定期通知をスケジュールしました: 毎日23:55")
            }
        }
    }

    /// 日記の定期通知をキャンセル
    func cancelDailyDiaryNotification(characterId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_diary_\(characterId)"]
        )
        print("📝 日記定期通知をキャンセルしました: \(characterId)")
    }

    /// バッジをクリア
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// 通知単位の列挙型
enum NotificationUnit: String, CaseIterable, Codable {
    case minutes = "分前"
    case hours = "時間前"
    case days = "日前"

    var displayName: String {
        return self.rawValue
    }
}

// 通知設定の構造体
struct NotificationSettings: Codable, Equatable {
    var isEnabled: Bool = false
    var notifications: [NotificationTiming] = []

    // 下位互換性のため保持（UI用）
    var value: Int = 5
    var unit: NotificationUnit = .minutes

    init() {
        self.isEnabled = false
        self.notifications = []
        self.value = 5
        self.unit = .minutes
    }

    init(isEnabled: Bool, notifications: [NotificationTiming]) {
        self.isEnabled = isEnabled
        self.notifications = notifications
        // 最初の通知を下位互換用に設定
        if let first = notifications.first {
            self.value = first.value
            self.unit = first.unit
        } else {
            self.value = 5
            self.unit = .minutes
        }
    }

    func getDescription() -> String {
        if !isEnabled || notifications.isEmpty {
            return "通知しない"
        }
        if notifications.count == 1 {
            return notifications[0].getDescription()
        }
        return "\(notifications.count)件の通知"
    }

    // 既存UIとの互換性のため
    func getSingleDescription() -> String {
        if !isEnabled {
            return "通知しない"
        }
        return "\(value)\(unit.displayName)"
    }
}