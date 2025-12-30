import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @State private var userInput: String = ""
    @State private var isWaitingForReply: Bool = false
    @State private var hasLoadedInitialMessage = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var fontSettings: FontSettingsManager
    // 共有インスタンスは直接参照（パフォーマンス改善）
    private let colorSettings = ColorSettingsManager.shared
    @AppStorage("characterVolume") var characterVolume: Double = 0.8
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var displayedMessage: String = ""
    @State private var fullCharacterMessage: String = ""
    @State private var isSpeaking: Bool = false
    @State private var messageTimer: Timer?
    
    // 画像はローカルファイルから直接読み込み
    
    // キャラクターの動作制御用
    @State private var characterExpression: CharacterExpression = .normal
    
    // 広告表示
    @StateObject private var rewardedAd = RewardedAdManager()
    @StateObject private var chatLimitManager = ChatLimitManager()
    private let subscriptionManager = SubscriptionManager.shared
    
    // 予定確認ポップアップ
    @State private var showChatLimitUpgrade = false
    @State private var showPremiumUpgrade = false
    @State private var showScheduleConfirmation = false
    @State private var pendingScheduleData: ExtractedScheduleData?
    @State private var showScheduleEdit = false
    @State private var scheduleToEdit: ScheduleItem?
    @StateObject private var scheduleManager = ScheduleManager()
    
    // ポイントシステム
    @StateObject private var pointsManager = PointsManager()
    
    // キャラクター生成ポップアップ
    @State private var showGenerationPopup = false
    
    // レベルアップメッセージ
    @State private var levelUpMessage: String? = nil
    
    // BIG5回答後のメッセージ
    @State private var engagingComment: String = ""
    @State private var showEngagingComment: Bool = false

    // 6人会議機能
    @State private var showMeetingInput = false
    @State private var showMeetingLockedDialog = false
    @State private var showMeetingUnlockPopup = false
    @AppStorage("meetingFeatureUnlocked") private var meetingFeatureUnlocked = false
    @AppStorage("meetingFeatureNewBadge") private var showMeetingNewBadge = false

    // 統合履歴
    @State private var showUnifiedHistory = false

    // サービス
    @StateObject private var characterService = CharacterService()
    @StateObject private var errorManager = ErrorManager()
    private let diaryNotificationService = DiaryNotificationService.shared

    // キャラクター性別
    @State private var characterGender: CharacterGender = .female
    @State private var characterConfig: CharacterConfig? = nil

    let userId: String
    let characterId: String

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // 背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                        .onTapGesture {
                            // 背景タップでキーボードを閉じる
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }

                    // キャラクター画像表示（背景レイヤー）
                    if let config = characterConfig {
                        CharacterDisplayComponent(
                            displayedMessage: $displayedMessage,
                            currentExpression: $characterExpression,
                            characterConfig: config
                        )
                        .id(config.id) // configが変更されたら完全に再生成
                        .frame(
                            width: min(geometry.size.width * 1.3, 800),
                            height: min(geometry.size.height * 0.8, 800)
                        )
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.6)
                        .onTapGesture {
                            // キャラクター画像タップでキーボードを閉じる
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }

                    // UI要素（最前面レイヤー）
                    VStack(spacing: 0) {
                        Spacer()

                        // 下部：BIG5進捗バー、履歴ボタンとチャット入力/BIG5選択肢
                        VStack(spacing: 8) {
                            // BIG5進捗バー（チャット入力と連動）
                            HStack {
                                BIG5ProgressView(
                                    answeredCount: characterService.big5AnsweredCount,
                                    levelUpMessage: levelUpMessage
                                )
                                .padding(.leading, 16)

                                Spacer()
                            }

                            // 6人会議ボタンと履歴ボタン
                            HStack {
                                // 自分会議ボタン
                                Button(action: {
                                    // 診断中は何もしない（質問に答えるのが優先）
                                    if characterService.showBIG5Question || characterService.showBIG5ContinueDialog {
                                        return
                                    }

                                    let isUnlocked = characterService.big5AnsweredCount >= 20
                                    if isUnlocked {
                                        showMeetingInput = true
                                        // Newバッジを非表示にする
                                        if showMeetingNewBadge {
                                            showMeetingNewBadge = false
                                        }
                                    } else {
                                        showMeetingLockedDialog = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: characterService.big5AnsweredCount >= 20 ? "person.3.fill" : "lock.fill")
                                        Text("自分会議")
                                            .dynamicCallout()

                                        // Newバッジ
                                        if showMeetingNewBadge && characterService.big5AnsweredCount >= 20 {
                                            Text("New")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(colorSettings.getCurrentAccentColor().opacity(characterService.big5AnsweredCount >= 20 ? 0.85 : 0.5))
                                    .cornerRadius(20)
                                    .shadow(radius: 2)
                                }
                                .padding(.leading, 16)

                                Spacer()

                                // 統合履歴ボタン
                                Button(action: {
                                    showUnifiedHistory = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("履歴")
                                            .dynamicCallout()
                                    }
                                    .foregroundColor(colorSettings.getCurrentAccentColor())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(20)
                                    .shadow(radius: 2)
                                }
                                .padding(.trailing, 16)
                            }

                            // BIG5質問の選択肢、確認ダイアログ、またはチャット入力
                            if characterService.showBIG5Question {
                                // BIG5質問表示
                                if let question = characterService.currentBIG5Question {
                                    SimpleAnswerButtons(
                                        question: question.question,
                                        onAnswer: { answerValue in
                                            handleBIG5Answer(answerValue: answerValue, question: question)
                                        }
                                    )
                                    .environmentObject(fontSettings)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: characterService.showBIG5Question)
                                }
                            } else if characterService.showBIG5ContinueDialog {
                                // 確認ダイアログ表示
                                BIG5ContinueDialog(
                                    onContinue: {
                                        displayedMessage = ""  // メッセージをクリア
                                        characterService.continueToNextQuestion()
                                    },
                                    onLater: {
                                        characterService.skipToChat()
                                    }
                                )
                                .environmentObject(fontSettings)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: characterService.showBIG5ContinueDialog)
                            } else {
                                // 通常のチャット入力
                                ChatInputComponent(
                                    userInput: $userInput,
                                    isWaitingForReply: isWaitingForReply,
                                    onSendMessage: sendMessage
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: characterService.showBIG5Question)
                            }
                        }
                        .padding(.bottom, subscriptionManager.shouldDisplayBannerAd() ? 5 : 10)

                        // バナー広告（無料ユーザーのみ、チャット入力とタブの間に配置）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            BannerAdView(adUnitID: Config.homeScreenBannerAdUnitID)
                                .frame(height: 50)
                                .background(Color.clear)
                                .onAppear {
                                    subscriptionManager.trackBannerAdImpression()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                    }


                    // 吹き出し表示（中央配置）
                    if (characterService.showBIG5Question && characterService.currentBIG5Question != nil) || (!characterService.showBIG5ContinueDialog && !displayedMessage.isEmpty) {
                        VStack {
                            Text(getBubbleMessage())
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.black)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .multilineTextAlignment(.leading)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: min(geometry.size.width * 0.8, 280))
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.safeAreaInsets.top + 80
                        )
                        .onTapGesture {
                            // 吹き出しタップでキーボードを閉じる
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .onAppear {
                        }
                    }

                }
            }
            .onAppear {
                // UI設定は即座に実行
                colorSettings.forceRefresh()

                // サブスクリプション監視開始
                subscriptionManager.startMonitoring()

                // NavigationStackの背景を透明にする
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance

                // 重い処理は非同期で実行
                DispatchQueue.main.async {
                    onViewAppear()
                }

                // BIG5進捗の読み込みは遅延実行（デバッグモードはスキップ）
                if userId != "debug_user" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        characterService.loadInitialBIG5Progress(characterId: characterId)

                        // キャラクター生成状態の監視開始
                        characterService.monitorCharacterGenerationStatus(characterId: characterId)
                    }
                } else {
                }

                // 自動アニメーションは無効化
                // startCharacterAnimations()
            }
            .onChange(of: characterService.characterGenerationStatus.status) { newStatus in
                // 完了ポップアップが表示された時点でFirestoreのみ削除（ローカル状態は維持）
                if newStatus == .completed {
                    characterService.clearGenerationStatusInFirestore(characterId: characterId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissCharacterGenerationPopup)) { _ in
                // ポップアップを閉じる時にローカル状態をリセット
                characterService.characterGenerationStatus = .notStarted
            }
            .onChange(of: characterService.big5AnsweredCount) { newValue in
                // 20問完了時に解禁ポップアップを表示
                if newValue == 20 && !meetingFeatureUnlocked {
                    meetingFeatureUnlocked = true
                    showMeetingNewBadge = true

                    // 少し遅延させてポップアップを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showMeetingUnlockPopup = true
                    }
                }
            }
            .onDisappear {
                // リスナーのクリーンアップ
                characterService.stopMonitoringGenerationStatus()
                subscriptionManager.stopMonitoring()
            }
            .errorAlert(errorManager)
            .sheet(isPresented: $showChatLimitUpgrade) {
                ChatLimitUpgradeView(
                    onUpgrade: {
                        showPremiumUpgrade = true
                    }
                )
            }
            .sheet(isPresented: $showPremiumUpgrade) {
                PremiumUpgradeView()
            }
            .sheet(isPresented: $showScheduleEdit) {
                if let schedule = scheduleToEdit {
                    NavigationStack {
                        ScheduleEditView(schedule: schedule, userId: userId, isNewSchedule: true)
                    }
                }
            }
            .sheet(isPresented: $showMeetingInput) {
                MeetingInputView(
                    userId: userId,
                    characterId: characterId
                )
            }
            .fullScreenCover(isPresented: $showUnifiedHistory) {
                UnifiedHistoryView(
                    userId: userId,
                    characterId: characterId
                )
            }
        }
        .overlay {
            if showScheduleConfirmation, let scheduleData = pendingScheduleData {
                ScheduleConfirmationPopup(
                    scheduleData: scheduleData,
                    onConfirm: { confirmedScheduleData, selectedTag in
                        scheduleManager.saveSchedule(from: confirmedScheduleData, tag: selectedTag)
                        showScheduleConfirmation = false
                        pendingScheduleData = nil
                    },
                    onCancel: {
                        showScheduleConfirmation = false
                        pendingScheduleData = nil
                    },
                    onEdit: { scheduleData in
                        // ExtractedScheduleDataからScheduleItemを作成（まだDB保存しない）
                        scheduleToEdit = createScheduleItem(from: scheduleData)
                        showScheduleConfirmation = false
                        showScheduleEdit = true
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: showScheduleConfirmation)
            }
            
            // キャラクター生成ポップアップ
            if characterService.characterGenerationStatus.shouldShowPopup {
                CharacterGenerationPopupView(status: characterService.characterGenerationStatus)
                    .animation(.easeInOut(duration: 0.3), value: characterService.characterGenerationStatus.status)
            }

            // 会議機能ロックダイアログ
            if showMeetingLockedDialog {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showMeetingLockedDialog = false
                        }

                    MeetingFeatureLockedDialog(
                        currentProgress: characterService.big5AnsweredCount,
                        onContinueDiagnosis: {
                            showMeetingLockedDialog = false
                            // 診断を開始
                            triggerBIG5Question()
                        },
                        onDismiss: {
                            showMeetingLockedDialog = false
                        }
                    )
                    .environmentObject(fontSettings)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showMeetingLockedDialog)
            }

            // 会議機能解禁ポップアップ
            if showMeetingUnlockPopup {
                MeetingFeatureUnlockPopup(
                    onTryNow: {
                        showMeetingUnlockPopup = false
                        showMeetingInput = true
                    },
                    onDismiss: {
                        showMeetingUnlockPopup = false
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showMeetingUnlockPopup)
            }
        }
    }
    
    private var backgroundView: some View {
        colorSettings.getCurrentBackgroundGradient()
            .ignoresSafeArea()
    }
    
    // MARK: - View Lifecycle
    private func onViewAppear() {
        if !hasLoadedInitialMessage {
            loadCharacterInfo()
            loadCharacterGender()
            hasLoadedInitialMessage = true
        }

        if let currentUser = Auth.auth().currentUser {
        } else {
        }


        // 予定検出の通知を監視
        NotificationCenter.default.addObserver(
            forName: .scheduleDetected,
            object: nil,
            queue: .main
        ) { notification in
            if let scheduleData = notification.userInfo?["scheduleData"] as? [String: Any] {
                self.pendingScheduleData = ExtractedScheduleData(from: scheduleData)
                self.showScheduleConfirmation = true
            }
        }
        
        // ポイント獲得の通知を監視
        NotificationCenter.default.addObserver(
            forName: .pointsEarned,
            object: nil,
            queue: .main
        ) { notification in
            if let characterId = notification.userInfo?["characterId"] as? String {
                self.pointsManager.addPoints(for: characterId)
            }
        }
        
        // BIG5回答後の返答を監視
        NotificationCenter.default.addObserver(
            forName: .init("BIG5AnswerResponse"),
            object: nil,
            queue: .main
        ) { notification in
            if let reply = notification.userInfo?["reply"] as? String {
                self.engagingComment = reply
                self.showEngagingComment = true
            }
        }
        
        // ポイント初期読み込み
        pointsManager.loadPoints(for: characterId)

        // 日記通知の監視を開始
        if let config = characterConfig {
            diaryNotificationService.startMonitoringCharacter(
                userId: userId,
                character: config
            )
        }
    }
    
    // MARK: - Character Info Loading
    private func loadCharacterInfo() {

        characterService.loadCharacterInfo(userId: userId) { [self] result in

            DispatchQueue.main.async {

                switch result {
                case .success(let info):
                    // Live2DCharacterViewが画像管理するため、singleImageUrlは不要
                    // 初期メッセージのみ設定
                    if !info.initialMessage.isEmpty {
                        self.displayedMessage = info.initialMessage
                    }
                case .failure(let error):
                    self.errorManager.handleError(error)
                }

            }
        }

    }

    private func loadCharacterGender() {
        let db = Firestore.firestore()
        let detailsRef = db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("details").document("current")

        detailsRef.getDocument { document, error in
            if let error = error {
                return
            }

            guard let document = document, document.exists else {
                return
            }

            guard let data = document.data() else {
                return
            }

            guard let genderString = data["gender"] as? String else {
                return
            }

            DispatchQueue.main.async {
                // "男性" -> .male, "女性" -> .female
                let gender: CharacterGender
                if genderString == "男性" {
                    gender = .male
                } else {
                    gender = .female
                }

                self.characterGender = gender

                // CharacterConfigを更新
                self.characterConfig = CharacterConfig(
                    id: "character_\(gender.rawValue)",
                    name: "Koharu",
                    gender: gender,
                    imageSource: .local("character_\(gender.rawValue)"),
                    isDefault: true
                )
            }
        }
    }

    
    // MARK: - Message Sending
    private func sendMessage() {
        handleChatLimit()
        
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // ユーザー入力があったらENGAGING_COMMENTをリセット
        if showEngagingComment {
            showEngagingComment = false
            engagingComment = ""
        }
        
        // 性格診断のトリガーパターンの検出
        let topicRequestPatterns = [
            "性格解析して",
            "性格診断して"
        ]

        // 完全一致または含まれているかチェック
        let isTopicRequest = topicRequestPatterns.contains { pattern in
            trimmed.contains(pattern)
        }
        
        // 話題リクエストの場合はBIG5質問を表示
        if isTopicRequest {
            userInput = ""
            
            // CharacterServiceを通じてBIG5質問を強制的にトリガー
            triggerBIG5Question()
            
            return
        }
        
        // 送信直後にテキストをクリア＆入力を無効化
        userInput = ""
        isWaitingForReply = true

        // キーボードを閉じる
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        characterService.sendMessage(
            characterId: characterId,
            userMessage: trimmed,
            userId: userId
        ) { [self] result in
            DispatchQueue.main.async {
                self.isWaitingForReply = false
                
                switch result {
                case .success(let reply):
                    self.handleCharacterReply(reply)
                case .failure(let error):
                    self.errorManager.handleError(error)
                }
            }
        }
    }
    
    private func handleChatLimit() {
        // プレミアムユーザーは広告なし
        if subscriptionManager.subscriptionStatus == .premium {
            return
        }

        // チャット回数をカウント（制限なし）
        chatLimitManager.consumeChat()

        // 5回に1回動画広告表示チェック
        let currentChatCount = chatLimitManager.totalChatsToday

        if currentChatCount % 5 == 0 {
            // 他のビューが表示されている可能性があるため、少し遅延させる
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showRewardedAdFromTopViewController()
            }
        }
    }

    // 最前面のViewControllerから広告を表示
    private func showRewardedAdFromTopViewController() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.keyWindow?.rootViewController else {
            return
        }

        // 最前面のViewControllerを取得
        var topViewController = rootViewController
        while let presentedVC = topViewController.presentedViewController {
            topViewController = presentedVC
        }

        // 広告を表示
        self.rewardedAd.showAd(from: topViewController) {
        }
    }

    private func handleCharacterReply(_ reply: CharacterReply) {
        fullCharacterMessage = reply.message
        displayedMessage = ""
        isSpeaking = true

        // レベルアップメッセージの検出（サーバー側の段階完了メッセージ）
        detectLevelUpMessage(reply.message)
        
        // 音声URLがある場合のみ再生
        if let voiceUrl = reply.voiceUrl {
            AudioService.shared.playVoice(url: voiceUrl, volume: characterVolume)
        }
        
        startTypewriterEffect(message: reply.message)
    }
    
    private func detectLevelUpMessage(_ message: String) {
        // サーバー側の段階完了メッセージパターン
        let levelUpPatterns = [
            "第1段階のデータ収集が完了しました",
            "君ともっと話したくなってきたよ",
            "あなたともっと話したくなってきたよ", 
            "やった！全部の診断が終わったね",
            "引き続き解析を進めさせていただきます",
            "僕も少しずつ感情を理解できるようになってるかも",
            "私も少しずつ感情を理解できるようになってるかも",
            "これからもっと楽しくお話しできそう"
        ]
        
        // メッセージにレベルアップパターンが含まれている場合
        for pattern in levelUpPatterns {
            if message.contains(pattern) {
                // レベルアップメッセージを設定（少し遅延させてアニメーションを確実に実行）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    levelUpMessage = message
                    
                    // 一定時間後にメッセージをクリア
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        levelUpMessage = nil
                    }
                }
                break
            }
        }
    }
    
    private func startTypewriterEffect(message: String) {
        var currentIndex = 0
        messageTimer?.invalidate()
        
        messageTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if currentIndex < message.count {
                let index = message.index(message.startIndex, offsetBy: currentIndex + 1)
                self.displayedMessage = String(message[..<index])
                currentIndex += 1
            } else {
                timer.invalidate()
                self.isSpeaking = false
            }
        }
    }
    
    // MARK: - Bubble Message
    private func getBubbleMessage() -> String {
        if showEngagingComment {
            return engagingComment
        } else if characterService.showBIG5Question && characterService.currentBIG5Question != nil {
            let question = characterService.currentBIG5Question!.question
            let options = """
            以下から選んでね：
            1. 全く当てはまらない
            2. あまり当てはまらない
            3. どちらでもない
            4. やや当てはまる
            5. 非常に当てはまる
            """
            return "\(question)\n\n\(options)"
        } else {
            return displayedMessage
        }
    }
    
    // MARK: - BIG5 Answer Handling
    private func handleBIG5Answer(answerValue: Int, question: BIG5Question) {
        // CharacterServiceに回答を送信（サーバー側でENGAGING_COMMENT_PATTERNSが処理される）
        let characterId = authManager.characterId
        characterService.submitBIG5Answer(answerValue, characterId: characterId)
    }
    
    // MARK: - BIG5 Question Trigger
    private func triggerBIG5Question() {
        // Cloud Functionを呼び出してBIG5質問を取得
        isWaitingForReply = true

        characterService.sendMessage(
            characterId: characterId,
            userMessage: "性格診断して",
            userId: userId
        ) { [self] result in
            DispatchQueue.main.async {
                self.isWaitingForReply = false

                switch result {
                case .success(let reply):
                    self.handleCharacterReply(reply)
                case .failure(let error):
                    self.errorManager.handleError(error)
                }
            }
        }
    }

    // MARK: - Schedule Helper
    private func createScheduleItem(from scheduleData: ExtractedScheduleData) -> ScheduleItem {
        let startDate = scheduleData.startDate ?? Date()
        let endDate = scheduleData.endDate ?? startDate.addingTimeInterval(3600) // デフォルト1時間後

        return ScheduleItem(
            id: UUID().uuidString,
            title: scheduleData.title,
            isAllDay: scheduleData.isAllDay,
            startDate: startDate,
            endDate: endDate,
            location: scheduleData.location,
            tag: "",
            memo: scheduleData.memo,
            repeatOption: "",
            remindValue: 10,
            remindUnit: "分前",
            recurringGroupId: nil,
            notificationSettings: NotificationSettings(
                isEnabled: true,
                notifications: [
                    NotificationTiming(value: 10, unit: .minutes)
                ]
            )
        )
    }

}

// チャット入力コンポーネント
struct ChatInputComponent: View {
    @Binding var userInput: String
    let isWaitingForReply: Bool
    @State private var oldInput: String = ""
    @State private var isPlaceholderVisible: Bool = true
    @State private var hasSetInitialText: Bool = false
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared

    let onSendMessage: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                    AutoSizingTextEditor(text: $userInput)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(isWaitingForReply ? 0.1 : 0.2))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                        .overlay(
                            // クリアボタン（常に表示、テキストがない時は無効化）
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            userInput = ""
                                            isPlaceholderVisible = true
                                        }
                                        // キーボードを閉じる
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(userInput.isEmpty ? .gray.opacity(0.3) : .gray.opacity(0.6))
                                            .font(.system(size: 16))
                                    }
                                    .disabled(userInput.isEmpty)
                                    .padding(.trailing, 15)
                                }
                                .padding(.bottom, 20)
                            }
                        )
                        .disabled(isWaitingForReply)
                        .onTapGesture {
                            // 待機中はタップを無効化
                            if !isWaitingForReply && isPlaceholderVisible {
                                isPlaceholderVisible = false
                                userInput = ""
                            }
                        }
                        .onChange(of: userInput) { newValue in
                            // 入力があったらプレースホルダーを非表示
                            if !newValue.isEmpty {
                                isPlaceholderVisible = false
                            } else {
                                isPlaceholderVisible = true
                            }

                            if userInput.count > 100 {
                                userInput = oldInput
                            } else {
                                oldInput = userInput
                            }
                        }

                    // プレースホルダーテキスト
                    if isPlaceholderVisible && userInput.isEmpty {
                        Text(isWaitingForReply ? "返答を待っています..." : "性格診断して")
                            .foregroundColor(.gray) // グレー色で見やすく
                            .padding(.horizontal, 15)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false) // タップを通す
                    }
                }

                Button(action: {
                    // 待機中または無効な入力の場合は送信しない
                    if !isWaitingForReply && !isPlaceholderVisible && !userInput.isEmpty {
                        onSendMessage()
                    }
                }) {
                    Image(systemName: isWaitingForReply ? "hourglass" : "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(!isWaitingForReply && !isPlaceholderVisible && !userInput.isEmpty ? colorSettings.getCurrentAccentColor().opacity(0.85) : Color.gray.opacity(0.5))
                        .clipShape(Circle())
                        .shadow(radius: !isWaitingForReply && !isPlaceholderVisible && !userInput.isEmpty ? 4 : 0)
                        .disabled(isWaitingForReply)
                }
            }
            .padding(.horizontal)

            // 文字数カウント（プレースホルダー時は0文字表示）
            Text("\(isPlaceholderVisible ? 0 : userInput.count)/100文字")
                .dynamicCaption()
                .foregroundColor(userInput.count >= 100 ? .red : colorSettings.getCurrentTextColor().opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 10)
    }
}
