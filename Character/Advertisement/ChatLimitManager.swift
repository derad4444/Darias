import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatLimitManager: ObservableObject {
    @Published var remainingChats: Int = 5
    @Published var totalChatsToday: Int = 0

    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        fetchChatLimit()
    }
    
    func fetchChatLimit() {
        guard let userId = userId else { return }
        let docRef = db.collection("users").document(userId)
        docRef.getDocument { document, error in
            if let data = document?.data() {
                // 残りチャット数
                let count = data["remaining_chats"] as? Int ?? 5
                self.remainingChats = count

                // 今日のチャット数を取得
                if let usage = data["usage_tracking"] as? [String: Any] {
                    self.totalChatsToday = usage["chat_count_today"] as? Int ?? 0
                }
            } else {
                self.remainingChats = 5
                self.totalChatsToday = 0
            }
        }
    }
    
    func consumeChat() {
        guard remainingChats > 0 else { return }
        remainingChats -= 1
        totalChatsToday += 1
        updateFirestore()
    }

    func refillChats() {
        remainingChats = 5
        updateFirestore()
    }

    /// 広告視聴によるチャット追加
    func addChatsFromAd(count: Int = 5) {
        remainingChats += count
        updateFirestore()
    }
    
    private func updateFirestore() {
        guard let userId = userId else { return }

        // 今日の日付取得
        let today = DateFormatter().string(from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        db.collection("users").document(userId).updateData([
            "remaining_chats": remainingChats,
            "usage_tracking.chat_count_today": totalChatsToday,
            "usage_tracking.last_chat_date": dateFormatter.string(from: Date()),
            "updated_at": Timestamp()
        ])
    }
}
