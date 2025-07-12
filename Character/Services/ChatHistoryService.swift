import Foundation
import FirebaseFirestore

class ChatHistoryService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    func fetchChatHistory(userId: String, characterId: String) {
        isLoading = true
        errorMessage = ""
        
        db.collection("posts")
            .whereField("user_id", isEqualTo: userId)
            .whereField("character_id", isEqualTo: characterId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.posts = []
                        return
                    }
                    
                    self?.posts = documents.compactMap { document in
                        try? document.data(as: Post.self)
                    }
                }
            }
    }
    
    // 日付ごとにチャットメッセージを変換
    func getChatMessagesByDate() -> [String: [ChatMessage]] {
        var messagesByDate: [String: [ChatMessage]] = [:]
        
        for post in posts {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年M月d日"
            let dateString = dateFormatter.string(from: post.timestamp)
            
            // ユーザーメッセージを追加
            let userMessage = ChatMessage(
                content: post.content,
                isUser: true,
                timestamp: post.timestamp
            )
            
            // キャラクターの返答を追加
            let characterMessage = ChatMessage(
                content: post.analysisResult,
                isUser: false,
                timestamp: post.timestamp.addingTimeInterval(1) // 少し後の時間
            )
            
            if messagesByDate[dateString] == nil {
                messagesByDate[dateString] = []
            }
            
            messagesByDate[dateString]?.append(userMessage)
            messagesByDate[dateString]?.append(characterMessage)
        }
        
        // 各日付内でメッセージを時間順にソート
        for dateKey in messagesByDate.keys {
            messagesByDate[dateKey]?.sort { $0.timestamp < $1.timestamp }
        }
        
        return messagesByDate
    }
    
    // 日付のリストを取得（新しい順）
    func getDateList() -> [String] {
        let messagesByDate = getChatMessagesByDate()
        return Array(messagesByDate.keys).sorted { date1, date2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月d日"
            guard let d1 = formatter.date(from: date1),
                  let d2 = formatter.date(from: date2) else {
                return false
            }
            return d1 > d2
        }
    }
}