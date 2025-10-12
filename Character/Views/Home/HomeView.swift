import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var userInput: String = ""
    @State private var isWaitingForReply: Bool = false
    @State private var hasLoadedInitialMessage = false
    @State private var showChatHistory = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var fontSettings: FontSettingsManager
    @StateObject private var colorSettings = ColorSettingsManager.shared
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
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
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
    
    // サービス
    @StateObject private var characterService = CharacterService()
    @StateObject private var errorManager = ErrorManager()
    
    let userId: String
    let characterId: String
    
    private var dynamicChatInputHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let baseChatHeight = screenHeight * 0.15

        // バナー広告が表示される場合は、大幅に高さを追加して完全に分離
        if subscriptionManager.shouldDisplayBannerAd() {
            // バナー広告 + 十分なマージンを確保（さらに増加）
            return baseChatHeight + 160 // さらに大幅に増加
        } else {
            // プレミアム時：広告スペース不要なので小さく
            return baseChatHeight - 20
        }
    }
    
    private var dynamicHeaderHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight * 0.075
    }

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // 背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    // キャラクター画像表示（背景レイヤー）
                    CharacterDisplayComponent(
                        displayedMessage: $displayedMessage,
                        currentExpression: $characterExpression,
                        characterConfig: CharacterConfig(
                            id: "character_female",
                            name: "Koharu",
                            gender: .female,
                            imageSource: .local("character_female"),
                            isDefault: true
                        )
                    )
                    .frame(width: 600, height: 600)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                    .allowsHitTesting(false) // UIの邪魔にならないよう無効化
                    
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

                            // 履歴ボタン
                            HStack {
                                Spacer()
                                Button(action: {
                                    showChatHistory = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("履歴")
                                            .dynamicCallout()
                                    }
                                    .foregroundColor(colorSettings.getCurrentAccentColor())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(20)
                                    .shadow(radius: 2)
                                }
                                .padding(.trailing, 16)
                            }
                            
                            // BIG5質問の選択肢またはチャット入力
                            if characterService.showBIG5Question {
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
                            BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716") // テスト用ID
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
                    if !displayedMessage.isEmpty || (characterService.showBIG5Question && characterService.currentBIG5Question != nil) {
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
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7) // 画面幅の70%
                        .position(x: UIScreen.main.bounds.width / 2, y: 80) // 吹き出しをより上に配置
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
                        ScheduleEditView(schedule: schedule, userId: userId)
                    }
                }
            }
            .navigationDestination(isPresented: $showChatHistory) {
                ChatHistoryView(userId: userId, characterId: characterId)
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
                        // ExtractedScheduleDataからScheduleItemを作成
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
        }
    }
    
    private var backgroundView: some View {
        colorSettings.getCurrentBackgroundGradient()
            .ignoresSafeArea()
    }
    
    // MARK: - View Lifecycle
    private func onViewAppear() {
        
        // 🔴 デバッグモード用の簡単なバイパス
        if userId == "debug_user" && characterId == "debug_character" {
            
            // デバッグメッセージを削除 - texture_00_female.pngキャラクターのみ表示
            if !hasLoadedInitialMessage {
                self.hasLoadedInitialMessage = true
            }
            return
        }
        
        if !hasLoadedInitialMessage {
            loadCharacterInfo()
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
        
        // ポイント初期読み込み（デバッグモードはスキップ）
        if userId != "debug_user" {
            pointsManager.loadPoints(for: characterId)
        } else {
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
        
        // 「話題ある？」パターンの検出
        let topicRequestPatterns = [
            "話題.*ある[？?]",
            "何.*話.*[？?]",
            "話.*[？?]",
            "なんか.*話.*[？?]",
            "話.*したい",
            "話.*しよう"
        ]
        
        // 簡単なマッチも追加でテスト
        let simpleMatch = trimmed.contains("話題ある") || 
                         trimmed.contains("話題ある？") ||
                         trimmed.contains("話題ある?")
        
        let regexMatch = topicRequestPatterns.contains { pattern in
            trimmed.range(of: pattern, options: .regularExpression) != nil
        }
        
        let isTopicRequest = regexMatch || simpleMatch
        
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
            print("🔵 プレミアムユーザーのため広告スキップ")
            return
        }

        // チャット回数をカウント（制限なし）
        chatLimitManager.consumeChat()

        // 5回に1回動画広告表示チェック
        let currentChatCount = chatLimitManager.totalChatsToday
        print("💬 現在のチャット回数: \(currentChatCount), リワード広告準備状態: \(rewardedAd.isReady)")

        if currentChatCount % 5 == 0 {
            print("🎬 5の倍数でリワード広告表示を試みます")
            // 他のビューが表示されている可能性があるため、少し遅延させる
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let root = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController {
                    // 既に他のビューを表示中でないか確認
                    if root.presentedViewController == nil {
                        self.rewardedAd.showAd(from: root) {
                            // 広告視聴完了時の処理（特になし）
                            print("✅ リワード広告視聴完了")
                        }
                    } else {
                        print("⚠️ 他のビューが表示中のため、広告表示をスキップします")
                        // さらに遅延して再試行
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if let root = UIApplication.shared.connectedScenes
                                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController,
                               root.presentedViewController == nil {
                                self.rewardedAd.showAd(from: root) {
                                    print("✅ リワード広告視聴完了")
                                }
                            } else {
                                print("⚠️ 再試行でも他のビューが表示中のため、広告表示をスキップします")
                            }
                        }
                    }
                } else {
                    print("❌ rootViewControllerが見つかりませんでした")
                }
            }
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
            userMessage: "話題ある？",
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
