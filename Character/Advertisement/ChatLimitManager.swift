import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatLimitManager: ObservableObject {
    @Published var totalChatsToday: Int = 0

    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        fetchChatCount()
    }

    func fetchChatCount() {
        guard let userId = userId else {
            print("⚠️ ChatLimitManager: userIdがありません")
            return
        }
        let docRef = db.collection("users").document(userId)
        docRef.getDocument { document, error in
            if let error = error {
                print("❌ ChatLimitManager: チャット数取得エラー: \(error.localizedDescription)")
                self.totalChatsToday = 0
                return
            }

            if let data = document?.data() {
                // 今日のチャット数を取得
                if let usage = data["usage_tracking"] as? [String: Any] {
                    let count = usage["chat_count_today"] as? Int ?? 0
                    let lastDate = usage["last_chat_date"] as? String ?? ""

                    // 今日の日付を取得
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let today = dateFormatter.string(from: Date())

                    // 日付が変わっていたらリセット
                    if lastDate != today {
                        print("📅 日付が変わったのでチャット数をリセット")
                        self.totalChatsToday = 0
                    } else {
                        self.totalChatsToday = count
                        print("✅ チャット数を取得: \(count)")
                    }
                } else {
                    print("⚠️ usage_trackingがありません。0から開始")
                    self.totalChatsToday = 0
                }
            } else {
                print("⚠️ ユーザードキュメントがありません")
                self.totalChatsToday = 0
            }
        }
    }
    
    func consumeChat() {
        totalChatsToday += 1
        print("💬 チャット消費: 今日のチャット数 = \(totalChatsToday)")
        updateFirestore()
    }

    private func updateFirestore() {
        guard let userId = userId else {
            print("⚠️ updateFirestore: userIdがありません")
            return
        }

        // 今日の日付取得
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        db.collection("users").document(userId).updateData([
            "usage_tracking.chat_count_today": totalChatsToday,
            "usage_tracking.last_chat_date": dateFormatter.string(from: Date()),
            "updated_at": Timestamp()
        ]) { error in
            if let error = error {
                print("❌ Firestoreチャット数更新エラー: \(error.localizedDescription)")
            } else {
                print("✅ Firestoreチャット数更新成功: \(self.totalChatsToday)")
            }
        }
    }
}
