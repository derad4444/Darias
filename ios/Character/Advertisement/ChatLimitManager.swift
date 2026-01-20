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
            return
        }
        let docRef = db.collection("users").document(userId)
        docRef.getDocument { document, error in
            if let error = error {
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
                        self.totalChatsToday = 0
                    } else {
                        self.totalChatsToday = count
                    }
                } else {
                    self.totalChatsToday = 0
                }
            } else {
                self.totalChatsToday = 0
            }
        }
    }
    
    func consumeChat() {
        totalChatsToday += 1
        updateFirestore()
    }

    private func updateFirestore() {
        guard let userId = userId else {
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
            } else {
            }
        }
    }
}
