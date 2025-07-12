import Foundation
import FirebaseFirestore
import FirebaseFunctions

extension Notification.Name {
    static let scheduleDetected = Notification.Name("scheduleDetected")
    static let pointsEarned = Notification.Name("pointsEarned")
}

class CharacterService: ObservableObject {
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "asia-northeast1")
    
    @Published var big5AnsweredCount: Int = 0
    
    // MARK: - Character Info Loading
    func loadCharacterInfo(
        userId: String,
        completion: @escaping (Result<CharacterInfo, AppError>) -> Void
    ) {
        guard !userId.isEmpty else {
            completion(.failure(.invalidInput("ユーザーIDが空です")))
            return
        }
        
        db.collection("CharacterDetail")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "updatedAt", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(.firestoreError(error.localizedDescription)))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(.failure(.firestoreError("キャラクター情報が見つかりません")))
                    return
                }
                
                let data = document.data()
                guard let personalityKey = data["personalityKey"] as? String else {
                    completion(.failure(.firestoreError("パーソナリティキーが存在しません")))
                    return
                }
                
                self.loadCharacterImages(personalityKey: personalityKey, completion: completion)
            }
    }
    
    private func loadCharacterImages(
        personalityKey: String,
        completion: @escaping (Result<CharacterInfo, AppError>) -> Void
    ) {
        db.collection("personalityImages")
            .document(personalityKey)
            .getDocument { imageDoc, error in
                if let error = error {
                    completion(.failure(.firestoreError(error.localizedDescription)))
                    return
                }
                
                guard let imageData = imageDoc?.data(),
                      let parts = imageData["parts"] as? [String: String] else {
                    completion(.failure(.firestoreError("キャラクター画像データが見つかりません")))
                    return
                }
                
                // サンプル画像をAssetsから取得（Assets.xcassetsの画像名を指定）
                let sampleImageUrl: URL? = nil // Assets画像は CharacterView.swift で直接 Image("sample_character") として表示 
                
                let characterInfo = CharacterInfo(
                    singleImageUrl: sampleImageUrl ?? URL(string: parts["singleImageUrl"] ?? ""),
                    initialMessage: self.getTimeBasedMessage()
                )
                
                completion(.success(characterInfo))
            }
    }
    
    private func getTimeBasedMessage() -> String {
        let now = Calendar.current.component(.hour, from: Date())
        print("⏰ 現在の時間: \(now)時")
        
        if now >= 5 && now < 12 {
            return "おはよう！今日は何するの？"
        } else if now >= 18 || now < 5 {
            return "今日は何があったの？"
        } else {
            return ""
        }
    }
    
    // MARK: - Message Sending
    func sendMessage(
        characterId: String,
        userMessage: String,
        userId: String,
        completion: @escaping (Result<CharacterReply, AppError>) -> Void
    ) {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.invalidInput("メッセージを入力してください")))
            return
        }
        guard !characterId.isEmpty else {
            completion(.failure(.invalidInput("キャラクターIDが設定されていません")))
            return
        }
        guard !userId.isEmpty else {
            completion(.failure(.invalidInput("ユーザーIDが設定されていません")))
            return
        }
        
        print("✅ メッセージ送信開始: \(trimmed), userId=\(userId), characterId=\(characterId)")
        
        // キャラクター返答Cloud Function呼び出し
        functions.httpsCallable("generateCharacterReply").call([
            "characterId": characterId,
            "userMessage": trimmed,
            "userId": userId
        ]) { result, error in
            if let error = error {
                completion(.failure(.cloudFunctionError(error.localizedDescription)))
                return
            }
            
            guard let data = result?.data as? [String: Any],
                  let reply = data["reply"] as? String,
                  let voiceUrlString = data["voiceUrl"] as? String,
                  let voiceUrl = URL(string: voiceUrlString) else {
                completion(.failure(.cloudFunctionError("不正な応答データです")))
                return
            }
            
            let characterReply = CharacterReply(
                message: reply,
                voiceUrl: voiceUrl
            )
            
            // 投稿をFirestoreに保存
            self.saveUserPost(userId: userId, characterId: characterId, content: trimmed, reply: reply)
            
            completion(.success(characterReply))
        }
        
        // 予定抽出Cloud Function呼び出し
        functions.httpsCallable("extractSchedule").call([
            "userId": userId,
            "userMessage": trimmed
        ]) { result, error in
            if let error = error {
                print("🔥 extractSchedule エラー: \(error.localizedDescription)")
            } else {
                print("✅ extractSchedule 成功: \(result?.data ?? "No data")")
                
                // 予定が検出された場合の処理
                if let data = result?.data as? [String: Any],
                   let hasSchedule = data["hasSchedule"] as? Bool,
                   hasSchedule,
                   let scheduleData = data["scheduleData"] as? [String: Any] {
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .scheduleDetected,
                            object: nil,
                            userInfo: ["scheduleData": scheduleData]
                        )
                    }
                }
            }
        }
        
        // ポイント付与通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .pointsEarned,
                object: nil,
                userInfo: ["characterId": characterId]
            )
        }
        
        // BIG5進捗の監視と更新
        self.monitorBIG5Progress(characterId: characterId)
    }
    
    private func saveUserPost(userId: String, characterId: String, content: String, reply: String) {
        let newPost: [String: Any] = [
            "content": content,
            "character_id": characterId,
            "timestamp": Timestamp(date: Date()),
            "analysis_result": ["raw_output": reply]
        ]
        
        db.collection("users").document(userId)
            .collection("posts").addDocument(data: newPost) { error in
                if let error = error {
                    print("❌ 投稿保存エラー: \(error.localizedDescription)")
                } else {
                    print("✅ 投稿保存成功")
                }
            }
    }
    
    // MARK: - BIG5 Progress Monitoring
    func monitorBIG5Progress(characterId: String) {
        db.collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .getDocument { [weak self] document, error in
                if let error = error {
                    print("❌ BIG5進捗取得エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let data = document?.data() else {
                    print("📝 BIG5進捗データがありません")
                    return
                }
                
                let answeredQuestions = data["answeredQuestions"] as? [[String: Any]] ?? []
                let newCount = answeredQuestions.count
                
                DispatchQueue.main.async {
                    let oldCount = self?.big5AnsweredCount ?? 0
                    self?.big5AnsweredCount = newCount
                    
                    // カウントが増えた場合はアニメーション通知を送信
                    if newCount > oldCount {
                        NotificationCenter.default.post(
                            name: .big5ProgressUpdated,
                            object: nil,
                            userInfo: ["answeredCount": newCount]
                        )
                    }
                }
            }
    }
    
    func loadInitialBIG5Progress(characterId: String) {
        monitorBIG5Progress(characterId: characterId)
    }
}

