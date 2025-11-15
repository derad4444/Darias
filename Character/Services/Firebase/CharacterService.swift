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
    @Published var showBIG5ContinueDialog: Bool = false
    @Published var pendingNextQuestion: BIG5Question? = nil
    @Published var lastBIG5Reply: String = ""
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
            "性格解析は全部で100問あるよ。好きなタイミングで「性格診断して」と話しかけてくれれば質問するから答えてね！",
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
        // 会話履歴を取得してからCloud Functionを呼び出し
        fetchRecentChatHistory(userId: userId, characterId: characterId) { chatHistory in
            // キャラクター返答Cloud Function呼び出し
            // isPremiumフラグでFirebase Functions側でモデル選択
            // 無料: GPT-4o-mini, 有料: GPT-4o-2024-11-20
            Task { @MainActor in
                let isPremiumValue = self.subscriptionManager.isPremium

                self.functions.httpsCallable("generateCharacterReply").call([
                    "characterId": characterId,
                    "userMessage": userMessage,
                    "userId": userId,
                    "isPremium": isPremiumValue,
                    "chatHistory": chatHistory
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

    // 会話履歴を取得（直近2件）
    private func fetchRecentChatHistory(userId: String, characterId: String, completion: @escaping ([[String: String]]) -> Void) {
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: 2)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents, error == nil else {
                    completion([])
                    return
                }

                // 会話履歴を古い順に並べ替え、100文字制限を適用
                let chatHistory = documents.reversed().compactMap { doc -> [String: String]? in
                    let data = doc.data()
                    guard let userContent = data["content"] as? String,
                          let aiResponse = data["analysis_result"] as? String else {
                        return nil
                    }

                    // 各メッセージを100文字に制限
                    let trimmedUserContent = String(userContent.prefix(100))
                    let trimmedAiResponse = String(aiResponse.prefix(100))

                    return [
                        "userMessage": trimmedUserContent,
                        "aiResponse": trimmedAiResponse
                    ]
                }

                completion(chatHistory)
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


        // リアルタイムリスナーを設定
        big5ProgressListener = db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .addSnapshotListener { [weak self] document, error in
                if let error = error {
                    return
                }

                guard let data = document?.data() else {
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
                            } else {
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
                            } else {
                            }
                        }
                }
            }
    }
    
    func submitBIG5Answer(_ answerValue: Int, characterId: String) {
        guard let currentQuestion = currentBIG5Question else {
            return
        }


        // Firestoreの状態を確認
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    if let currentQ = data["currentQuestion"] as? [String: Any] {
                    } else {
                    }
                } else {
                }
            }

        // ユーザーIDを取得
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            Logger.error("User not authenticated for BIG5 answer submission", category: Logger.authentication)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for BIG5 answer submission", category: Logger.general)
            return
        }


        // Cloud Functionに回答を送信
        Task { @MainActor in
            let isPremiumValue = subscriptionManager.isPremium

            let data: [String: Any] = [
                "characterId": characterId,
                "userMessage": "\(answerValue)",
                "userId": userId,
                "isPremium": isPremiumValue
            ]


            functions.httpsCallable("generateCharacterReply").call(data) { [weak self] result, error in
            if let error = error {
                return
            }
            
            if let data = result?.data as? [String: Any] {
                DispatchQueue.main.async {
                    // フィードバックを保存
                    if let reply = data["reply"] as? String {
                        self?.lastBIG5Reply = reply
                    }

                    // 次の質問があるかチェック
                    if let isBig5Question = data["isBig5Question"] as? Int,
                       isBig5Question == 1,
                       let questionId = data["questionId"] as? String,
                       let questionText = data["questionText"] as? String {


                        let nextQuestion = BIG5Question(
                            id: questionId,
                            question: questionText,
                            trait: "",
                            direction: ""
                        )

                        // 次の質問を保存
                        self?.pendingNextQuestion = nextQuestion

                        // BIG5質問UIは一旦非表示
                        self?.showBIG5Question = false
                        self?.currentBIG5Question = nil

                        // フィードバックは表示せず、lastBIG5Replyに保存済み
                        // ダイアログで「後で」を選んだ時に表示する

                        // すぐにダイアログ表示
                        self?.showBIG5ContinueDialog = true
                    } else {
                        // 診断完了または通常チャット
                        self?.showBIG5Question = false
                        self?.currentBIG5Question = nil

                        // Big5スコア更新処理
                        self?.updateBig5PersonalityKey(characterId: characterId)

                        // 返答を表示
                        if let reply = data["reply"] as? String {
                            NotificationCenter.default.post(
                                name: .init("BIG5AnswerResponse"),
                                object: nil,
                                userInfo: ["reply": reply]
                            )
                        } else {
                        }
                    }
                }
            } else {
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

    func continueToNextQuestion() {

        DispatchQueue.main.async {
            if let nextQuestion = self.pendingNextQuestion {
                self.currentBIG5Question = nextQuestion
                self.showBIG5Question = true
                self.showBIG5ContinueDialog = false
                self.pendingNextQuestion = nil

            } else {
            }
        }
    }

    func skipToChat() {
        DispatchQueue.main.async {
            self.showBIG5Question = false
            self.showBIG5ContinueDialog = false
            self.pendingNextQuestion = nil

            // キャラクターの返答を通知（HomeViewで表示）
            if !self.lastBIG5Reply.isEmpty {
                NotificationCenter.default.post(
                    name: .init("BIG5AnswerResponse"),
                    object: nil,
                    userInfo: ["reply": self.lastBIG5Reply]
                )
            }
        }
    }

    // MARK: - Big5 PersonalityKey Update
    
    private func updateBig5PersonalityKey(characterId: String) {
        // ユーザーIDを取得
        guard let currentUserId = Auth.auth().currentUser?.uid else {
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
                    return
                }
                
                // Big5Scoresに変換
                guard let big5Scores = Big5Scores.fromScoreMap(currentScores) else {
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
                        } else {
                            
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

