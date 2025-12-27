import Foundation
import os.log

/// アプリ全体で使用するログ管理システム
/// デバッグビルドでは詳細ログ、本番ビルドでは最小限のログを出力
struct Logger {

    private static let subsystem = "com.Derao.Character"

    // カテゴリ別のロガー
    static let firestore = OSLog(subsystem: subsystem, category: "Firestore")
    static let notification = OSLog(subsystem: subsystem, category: "Notification")
    static let authentication = OSLog(subsystem: subsystem, category: "Authentication")
    static let schedule = OSLog(subsystem: subsystem, category: "Schedule")
    static let character = OSLog(subsystem: subsystem, category: "Character")
    static let subscription = OSLog(subsystem: subsystem, category: "Subscription")
    static let general = OSLog(subsystem: subsystem, category: "General")
    static let network = OSLog(subsystem: subsystem, category: "Network")

    /// デバッグ情報のログ（デバッグビルドでのみ出力）
    static func debug(_ message: String, category: OSLog = .default, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        os_log(.debug, log: category, "[%@:%@:%d] %@", fileName, function, line, message)
        #endif
    }

    /// 情報ログ（本番でも出力、ただし重要な情報のみ）
    static func info(_ message: String, category: OSLog = .default) {
        os_log(.info, log: category, "%@", message)
    }

    /// 警告ログ（本番でも出力）
    static func warning(_ message: String, category: OSLog = .default) {
        os_log(.error, log: category, "⚠️ %@", message)
    }

    /// エラーログ（本番でも出力）
    static func error(_ message: String, category: OSLog = .default, error: Error? = nil) {
        if let error = error {
            os_log(.error, log: category, "❌ %@: %@", message, error.localizedDescription)
        } else {
            os_log(.error, log: category, "❌ %@", message)
        }
    }

    /// 成功ログ（デバッグビルドでのみ出力）
    static func success(_ message: String, category: OSLog = .default) {
        #if DEBUG
        os_log(.info, log: category, "✅ %@", message)
        #endif
    }

    /// 廃止予定: print() の使用を防ぐため
    @available(*, deprecated, message: "Use Logger instead of print() for production-ready logging")
    static func deprecatedPrint(_ message: String) {
        #if DEBUG
        print("⚠️ DEPRECATED PRINT: \(message)")
        #endif
    }
}

// MARK: - Legacy print() replacement helpers
extension Logger {
    /// Firestore操作のログ
    static func firestoreOperation(_ message: String, success: Bool = true) {
        if success {
            Logger.success(message, category: Logger.firestore)
        } else {
            Logger.error(message, category: Logger.firestore)
        }
    }

    /// 予定操作のログ
    static func scheduleOperation(_ message: String, success: Bool = true) {
        if success {
            Logger.success(message, category: Logger.schedule)
        } else {
            Logger.error(message, category: Logger.schedule)
        }
    }

    /// 通知操作のログ
    static func notificationOperation(_ message: String, success: Bool = true) {
        if success {
            Logger.success(message, category: Logger.notification)
        } else {
            Logger.error(message, category: Logger.notification)
        }
    }
}