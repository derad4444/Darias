import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class DiaryNotificationService: ObservableObject {
    static let shared = DiaryNotificationService()

    private let db = Firestore.firestore()
    private var diaryListeners: [String: ListenerRegistration] = [:]
    private let notificationManager = NotificationManager.shared

    @Published var isMonitoring = false

    private init() {}

    // MARK: - Public Methods

    /// 全キャラクターの日記監視を開始
    func startMonitoring(userId: String, characters: [CharacterConfig]) {
        guard !isMonitoring else { return }

        isMonitoring = true

        for character in characters {
            startMonitoringCharacter(userId: userId, character: character)
        }

        print("✅ 日記監視開始: \(characters.count)キャラクター")
    }

    /// 特定キャラクターの日記監視を開始
    func startMonitoringCharacter(userId: String, character: CharacterConfig) {
        // 既に監視中の場合はスキップ
        if diaryListeners[character.id] != nil {
            return
        }

        let diaryRef = db.collection("users").document(userId)
            .collection("characters").document(character.id)
            .collection("diary")

        // 最新の日記のみを監視（24時間以内）
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        let listener = diaryRef
            .whereField("date", isGreaterThan: Timestamp(date: yesterday))
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ 日記監視エラー: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                // 新しく追加されたドキュメントをチェック
                // 注意: 即座通知は無効化。23:55の定期通知のみ使用する
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        // 新しい日記が追加された（ログのみ、通知は送信しない）
                        if let date = (change.document.data()["date"] as? Timestamp)?.dateValue() {
                            print("📝 新しい日記検出: \(character.name) - \(date)")
                        }
                    }
                }
            }

        diaryListeners[character.id] = listener
    }

    /// 全監視を停止
    func stopMonitoring() {
        for (_, listener) in diaryListeners {
            listener.remove()
        }
        diaryListeners.removeAll()
        isMonitoring = false

        print("⏹ 日記監視停止")
    }

    /// 特定キャラクターの監視を停止
    func stopMonitoringCharacter(characterId: String) {
        diaryListeners[characterId]?.remove()
        diaryListeners.removeValue(forKey: characterId)
    }
}
