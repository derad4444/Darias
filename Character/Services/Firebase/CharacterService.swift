import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

extension Notification.Name {
    static let scheduleDetected = Notification.Name("scheduleDetected")
    static let pointsEarned = Notification.Name("pointsEarned")
    static let characterGenerationUpdated = Notification.Name("characterGenerationUpdated")
}

class CharacterService: ObservableObject {
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "asia-northeast1")
    private let subscriptionManager = SubscriptionManager.shared

    @Published var big5AnsweredCount: Int = 0
    @Published var currentBIG5Question: BIG5Question? = nil
    @Published var showBIG5Question: Bool = false
    @Published var characterGenerationStatus: CharacterGenerationStatus = .notStarted

    deinit {
        big5ProgressListener?.remove()
        generationStatusListener?.remove()
    }
    
    // MARK: - Character Info Loading (画像取得処理を削除)
    func loadCharacterInfo(
        userId: String,
        completion: @escaping (Result<CharacterInfo, AppError>) -> Void
    ) {
        // 画像はローカルファイルから読み込むため、初期メッセージのみ返す
        let characterInfo = CharacterInfo(
            singleImageUrl: nil, // 使用しない
            initialMessage: self.getTimeBasedMessage()
        )
        
        completion(.success(characterInfo))
    }
    
    private func getTimeBasedMessage() -> String {
        let messages = [
            "性格解析は全部で100問あるよ。好きなタイミングで「話題ある？」と話しかけてくれれば質問するから答えてね！",
            "「何日に〇〇の予定あるよ」と教えてくれれば予定追加しておくね！",
            "アプリでわからないことや欲しい機能があれば設定画面の問い合わせから開発者に連絡してね！",
            "性格解析が終わったらキャラクター詳細画面でどんな性格か確認してみてね",
            "画面の背景の色は自由に変えられるから設定画面から好みの色に変えてね！",
            "BGMの大きさは設定画面で変えられるよ",
            "{user_name}に興味があるからあなたの性格が写っちゃいそうだよ。もう1人の自分だと思って接してね！",
            "私の夢は{user_name}の夢にもなるのかな？"
        ]

        let selectedMessage = messages.randomElement() ?? messages[0]
        return replacePlaceholders(in: selectedMessage)
    }

    private func replacePlaceholders(in message: String) -> String {
        let userName = UserDefaults.standard.string(forKey: "user_name") ?? "あなた"
        return message.replacingOccurrences(of: "{user_name}", with: userName)
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
        
        
        // 先に予定抽出をチェック
        // 予定抽出は無料・有料問わずGPT-3.5-turboを使用（isPremiumパラメータなし）
        functions.httpsCallable("extractSchedule").call([
            "userId": userId,
            "userMessage": trimmed
        ]) { result, error in
            if let error = error {
                // extractSchedule error handled silently, proceed to character reply
                self.generateCharacterReply(characterId: characterId, userMessage: trimmed, userId: userId, completion: completion)
            } else {
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
                    
                    // 予定追加時は固定文言で返答（AI返答生成はスキップ）
                    completion(.success(CharacterReply(
                        message: "予定楽しんでね！",
                        voiceUrl: nil
                    )))
                    
                    // 投稿をFirestoreに保存（予定検出時）
                    self.saveUserPost(userId: userId, characterId: characterId, content: trimmed, reply: "予定楽しんでね！")
                    return
                } else {
                    // 予定が検出されなかった場合は通常のキャラクター返答を生成
                    self.generateCharacterReply(characterId: characterId, userMessage: trimmed, userId: userId, completion: completion)
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
    
    // MARK: - Character Reply Generation
    private func generateCharacterReply(
        characterId: String,
        userMessage: String,
        userId: String,
        completion: @escaping (Result<CharacterReply, AppError>) -> Void
    ) {
        // キャラクター返答Cloud Function呼び出し
        // isPremiumフラグでFirebase Functions側でモデル選択
        // 無料: GPT-4o-mini, 有料: GPT-4o-2024-11-20
        Task { @MainActor in
            let isPremiumValue = subscriptionManager.isPremium

            functions.httpsCallable("generateCharacterReply").call([
                "characterId": characterId,
                "userMessage": userMessage,
                "userId": userId,
                "isPremium": isPremiumValue
            ]) { result, error in
            if let error = error {
                completion(.failure(.cloudFunctionError(error.localizedDescription)))
                return
            }
            
            guard let data = result?.data as? [String: Any],
                  let reply = data["reply"] as? String else {
                completion(.failure(.cloudFunctionError("不正な応答データです")))
                return
            }
            
            // voiceUrlはオプショナルで処理、エラー時は音声なし
            let voiceUrl: URL?
            if let voiceUrlString = data["voiceUrl"] as? String, !voiceUrlString.isEmpty {
                voiceUrl = URL(string: voiceUrlString)
            } else {
                voiceUrl = nil
            }
            
            let characterReply = CharacterReply(
                message: reply,
                voiceUrl: voiceUrl
            )
            
            // BIG5質問の検出と処理
            self.handleBIG5QuestionFromResponse(data, characterId: characterId)
            
            // 投稿をFirestoreに保存
            self.saveUserPost(userId: userId, characterId: characterId, content: userMessage, reply: reply)
            
            completion(.success(characterReply))
            }
        }
    }
    
    private func saveUserPost(userId: String, characterId: String, content: String, reply: String) {
        let newPost: [String: Any] = [
            "content": content,
            "timestamp": Timestamp(date: Date()),
            "analysis_result": reply // Stringとして保存
        ]
        
        // ユーザーのキャラクター別サブコレクションに保存
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("posts").addDocument(data: newPost) { error in
                // Post saved silently
            }
    }
    
    // MARK: - BIG5 Progress Monitoring
    private var big5ProgressListener: ListenerRegistration?

    func monitorBIG5Progress(characterId: String) {
        // 既存のリスナーを解除
        big5ProgressListener?.remove()

        // ユーザーIDを取得（認証済みユーザーから）
        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            Logger.error("User not authenticated for BIG5 progress monitoring", category: Logger.authentication)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for BIG5 progress monitoring", category: Logger.general)
            return
        }

        print("✅ Starting BIG5 progress monitoring for characterId: \(characterId)")

        // リアルタイムリスナーを設定
        big5ProgressListener = db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .addSnapshotListener { [weak self] document, error in
                if let error = error {
                    print("❌ BIG5 progress monitoring error: \(error)")
                    return
                }

                guard let data = document?.data() else {
                    print("⚠️ BIG5 progress document has no data")
                    return
                }

                let answeredQuestions = data["answeredQuestions"] as? [[String: Any]] ?? []
                let newCount = answeredQuestions.count

                print("📊 BIG5 progress update: \(newCount) questions answered")

                DispatchQueue.main.async {
                    let oldCount = self?.big5AnsweredCount ?? 0
                    self?.big5AnsweredCount = newCount

                    print("📊 Updated big5AnsweredCount from \(oldCount) to \(newCount)")

                    // カウントが増えた場合はアニメーション通知を送信
                    if newCount > oldCount {
                        print("✅ Posting big5ProgressUpdated notification")
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
    
    // MARK: - Character Generation Status Monitoring
    private var generationStatusListener: ListenerRegistration?
    
    func monitorCharacterGenerationStatus(characterId: String) {
        // 既存のリスナーを解除
        generationStatusListener?.remove()
        
        // ユーザーIDを取得
        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            Logger.error("User not authenticated for generation status monitoring", category: Logger.authentication)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for generation status monitoring", category: Logger.general)
            return
        }
        
        generationStatusListener = db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("generationStatus").document("current")
            .addSnapshotListener { [weak self] document, error in
                if let error = error {
                    print("❌ Generation status monitoring error: \(error)")
                    return
                }
                
                DispatchQueue.main.async {
                    if let document = document, document.exists {
                        let status = CharacterGenerationStatus(from: document)
                        self?.characterGenerationStatus = status
                        
                        // 状態変更の通知を送信
                        NotificationCenter.default.post(
                            name: .characterGenerationUpdated,
                            object: nil,
                            userInfo: [
                                "status": status.status.rawValue,
                                "stage": status.stage,
                                "message": status.message ?? ""
                            ]
                        )
                        
                        print("🔔 Generation status updated: stage \(status.stage), status: \(status.status.rawValue)")
                    } else {
                        // ドキュメントが存在しない場合は初期状態に戻す
                        self?.characterGenerationStatus = .notStarted
                    }
                }
            }
    }
    
    func stopMonitoringGenerationStatus() {
        generationStatusListener?.remove()
        generationStatusListener = nil
    }
    
    // MARK: - BIG5 Question Management
    func handleBIG5QuestionFromResponse(_ response: [String: Any], characterId: String) {
        if let isBIG5Question = response["isBig5Question"] as? Bool, isBIG5Question,
           let questionId = response["questionId"] as? String,
           let reply = response["reply"] as? String {
            
            // 質問文から実際の質問部分を抽出
            let components = reply.components(separatedBy: "\n")
            let questionText = components.first ?? reply
            
            let question = BIG5Question(
                id: questionId,
                question: questionText,
                trait: "", // トレイト情報は必要に応じて追加
                direction: ""
            )
            
            DispatchQueue.main.async {
                self.currentBIG5Question = question
                self.showBIG5Question = true
            }
            
            // BIG5進行状況をFirestoreに初期化（サーバー側でも作成されるが、クライアント側でも確保）
            initializeBIG5ProgressIfNeeded(characterId: characterId, question: question)
            initializeCharacterDetailsIfNeeded(characterId: characterId)
        }
    }
    
    private func initializeBIG5ProgressIfNeeded(characterId: String, question: BIG5Question) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .getDocument { document, error in
                if let error = error {
                    print("❌ Error checking BIG5 progress: \(error)")
                    return
                }
                
                // ドキュメントが存在しない場合のみ初期化
                if document?.exists != true {
                    let initialData: [String: Any] = [
                        "currentQuestion": [
                            "id": question.id,
                            "question": question.question,
                            "trait": question.trait,
                            "direction": question.direction
                        ],
                        "answeredQuestions": [],
                        "currentScores": [
                            "openness": 3,
                            "conscientiousness": 3,
                            "extraversion": 3,
                            "agreeableness": 3,
                            "neuroticism": 3
                        ],
                        "stage": 1,
                        "updated_at": Timestamp()
                    ]
                    
                    self.db.collection("users").document(userId)
                        .collection("characters").document(characterId)
                        .collection("big5Progress").document("current")
                        .setData(initialData) { error in
                            if let error = error {
                                print("❌ Error initializing BIG5 progress: \(error)")
                            } else {
                                print("✅ BIG5 progress initialized for character: \(characterId)")
                            }
                        }
                }
            }
    }
    
    private func initializeCharacterDetailsIfNeeded(characterId: String) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        guard !characterId.isEmpty else { return }
        
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("details").document("current")
            .getDocument { document, error in
                if let error = error {
                    print("❌ Error checking character details: \(error)")
                    return
                }
                
                // ドキュメントが存在しない場合のみ初期化
                if document?.exists != true {
                    let initialData: [String: Any] = [
                        "gender": "female",
                        "confirmedBig5Scores": [
                            "openness": 3,
                            "conscientiousness": 3,
                            "extraversion": 3,
                            "agreeableness": 3,
                            "neuroticism": 3
                        ],
                        "analysis_level": 0,
                        "points": 0,
                        "created_at": Timestamp(),
                        "updated_at": Timestamp()
                    ]
                    
                    self.db.collection("users").document(userId)
                        .collection("characters").document(characterId)
                        .collection("details").document("current")
                        .setData(initialData) { error in
                            if let error = error {
                                print("❌ Error initializing character details: \(error)")
                            } else {
                                print("✅ Character details initialized for character: \(characterId)")
                            }
                        }
                }
            }
    }
    
    func submitBIG5Answer(_ answerValue: Int, characterId: String) {
        guard let currentQuestion = currentBIG5Question else {
            print("❌ submitBIG5Answer: No current question")
            return
        }

        print("✅ submitBIG5Answer called: answer=\(answerValue), questionId=\(currentQuestion.id), characterId=\(characterId)")

        // Firestoreの状態を確認
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    print("🔍 Firestore big5Progress/current data: \(data)")
                    if let currentQ = data["currentQuestion"] as? [String: Any] {
                        print("🔍 Firestore currentQuestion: \(currentQ)")
                    } else {
                        print("❌ Firestore has no currentQuestion field!")
                    }
                } else {
                    print("❌ Firestore big5Progress/current document does not exist!")
                }
            }

        // ユーザーIDを取得
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            Logger.error("User not authenticated for BIG5 answer submission", category: Logger.authentication)
            print("❌ submitBIG5Answer: User not authenticated")
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for BIG5 answer submission", category: Logger.general)
            print("❌ submitBIG5Answer: CharacterId is empty")
            return
        }

        print("✅ Calling Cloud Function with userId=\(userId), characterId=\(characterId)")

        // Cloud Functionに回答を送信
        Task { @MainActor in
            let isPremiumValue = subscriptionManager.isPremium

            let data: [String: Any] = [
                "characterId": characterId,
                "userMessage": "\(answerValue)",
                "userId": userId,
                "isPremium": isPremiumValue
            ]

            print("✅ Request data: \(data)")

            functions.httpsCallable("generateCharacterReply").call(data) { [weak self] result, error in
            if let error = error {
                print("❌ BIG5 answer submission error: \(error)")
                return
            }
            
            print("🔄 BIG5 answer submission response received")
            if let data = result?.data as? [String: Any] {
                print("🔄 Response data: \(data)")
                DispatchQueue.main.async {
                    // BIG5質問を非表示にして通常チャットに戻る
                    self?.showBIG5Question = false
                    self?.currentBIG5Question = nil
                    
                    // Big5スコア更新処理
                    self?.updateBig5PersonalityKey(characterId: characterId)
                    
                    // 回答への返答をチャット履歴に追加（必要に応じて）
                    if let reply = data["reply"] as? String {
                        print("🔄 Sending BIG5AnswerResponse notification with reply: \(reply)")
                        NotificationCenter.default.post(
                            name: .init("BIG5AnswerResponse"),
                            object: nil,
                            userInfo: ["reply": reply]
                        )
                        print("🔄 BIG5AnswerResponse notification sent")
                    } else {
                        print("❌ No reply found in response data")
                    }
                }
            } else {
                print("❌ Invalid response data format")
            }
            }
        }
    }
    
    func hideBIG5Question() {
        DispatchQueue.main.async {
            self.showBIG5Question = false
            self.currentBIG5Question = nil
        }
    }
    
    // MARK: - Big5 PersonalityKey Update
    
    private func updateBig5PersonalityKey(characterId: String) {
        // ユーザーIDを取得
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated for BIG5 personality key update")
            return
        }
        
        // ユーザーのBig5進捗から暫定スコアを取得
        db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .getDocument { [weak self] document, error in
                guard let data = document?.data(),
                      let currentScores = data["currentScores"] as? [String: Any],
                      let answeredQuestions = data["answeredQuestions"] as? [[String: Any]] else {
                    print("❌ BIG5 progress data not found or invalid structure")
                    return
                }
                
                // Big5Scoresに変換
                guard let big5Scores = Big5Scores.fromScoreMap(currentScores) else {
                    print("❌ Failed to convert currentScores to Big5Scores")
                    return
                }
                
                // personalityKeyを生成
                let big5Service = Big5AnalysisService()
                let newPersonalityKey = big5Service.generatePersonalityKey(scores: big5Scores, gender: "female") // 現在は固定でfemale
                
                // 解析レベルを判定
                let analysisLevel = self?.determineAnalysisLevel(answeredCount: answeredQuestions.count) ?? 0
                
                // キャラクター詳細に確定スコアとして保存
                self?.db.collection("users").document(currentUserId)
                    .collection("characters").document(characterId)
                    .collection("details").document("current").updateData([
                        "personalityKey": newPersonalityKey,
                        "confirmedBig5Scores": big5Scores.toScoreMap(), // confirmedBig5Scoresとして保存
                        "analysis_level": analysisLevel,
                        "updated_at": Timestamp()
                    ]) { error in
                        if let error = error {
                            print("❌ PersonalityKey update error: \(error)")
                        } else {
                            print("✅ PersonalityKey updated to: \(newPersonalityKey) with confirmed scores")
                            
                            // 通知を送信してUIの更新を促す
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: .init("Big5PersonalityKeyUpdated"),
                                    object: nil,
                                    userInfo: ["characterId": characterId, "personalityKey": newPersonalityKey]
                                )
                            }
                        }
                    }
            }
    }
    
    private func determineAnalysisLevel(answeredCount: Int) -> Int {
        if answeredCount >= 100 {
            return 100
        } else if answeredCount >= 50 {
            return 50
        } else if answeredCount >= 20 {
            return 20
        } else {
            return 0
        }
    }
}

