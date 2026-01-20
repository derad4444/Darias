import Foundation
import FirebaseFirestore

class ChatHistoryService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var hasMoreHistory = false

    private let db = Firestore.firestore()
    private let subscriptionManager = SubscriptionManager.shared
    
    func fetchChatHistory(userId: String, characterId: String) {
        isLoading = true
        errorMessage = ""

        // 10秒後にタイムアウト処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isLoading {
                self.isLoading = false
                self.errorMessage = "データの読み込みがタイムアウトしました"
            }
        }

        // MainActorコンテキストでプレミアム状態をチェック
        Task { @MainActor in
            let isPremium = subscriptionManager.isPremium

            // クエリの基本部分
            let query = db.collection("users").document(userId)
                .collection("characters").document(characterId)
                .collection("posts")
                .order(by: "timestamp", descending: true)

            // プレミアムユーザーは制限なし、無料ユーザーは50件制限
            let finalQuery = isPremium ? query : query.limit(to: 50)

            finalQuery.addSnapshotListener { [weak self] snapshot, error in
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
                    
                    if documents.isEmpty {
                        self?.posts = []
                        self?.hasMoreHistory = false
                        return
                    }

                    self?.posts = documents.compactMap { document in
                        // サブコレクションの構造に合わせてPostオブジェクトを作成
                        var data = document.data()
                        data["user_id"] = userId
                        data["character_id"] = characterId

                        do {
                            var post = try Firestore.Decoder().decode(Post.self, from: data)
                            post.id = document.documentID  // ドキュメントIDを手動で設定
                            return post
                        } catch {
                            return nil
                        }
                    }

                    // 無料ユーザーの場合、制限を超える履歴があるかチェック
                    if !isPremium && documents.count == 50 {
                        self?.checkForMoreHistory(userId: userId, characterId: characterId)
                    } else {
                        self?.hasMoreHistory = false
                    }

                    // 重要：データ処理完了後にisLoadingをfalseに設定
                    self?.isLoading = false
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
        
        // 各日付内でメッセージを時間順にソート（新しい順）
        for dateKey in messagesByDate.keys {
            messagesByDate[dateKey]?.sort { $0.timestamp > $1.timestamp }
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
            return d1 > d2  // 新しい順に変更
        }
    }

    private func checkForMoreHistory(userId: String, characterId: String) {
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: 51)  // 51件取得して50件を超えるかチェック
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if error == nil, let documents = snapshot?.documents {
                        self?.hasMoreHistory = documents.count > 50
                    } else {
                        self?.hasMoreHistory = false
                    }
                }
            }
    }
}