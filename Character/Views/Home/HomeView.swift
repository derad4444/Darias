import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var userInput: String = ""
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
    
    // キャラクター画像URL（Live2DCharacterViewで管理されるため不要になりました）
    // @State private var singleImageUrl: URL? = nil
    
    // キャラクターの動作制御用
    @State private var randomMotionTimer: Timer?
    
    // 広告表示
    @StateObject private var rewardedAd = RewardedAdManager()
    @StateObject private var chatLimitManager = ChatLimitManager()
    
    // 予定確認ポップアップ
    @State private var showScheduleConfirmation = false
    @State private var pendingScheduleData: ExtractedScheduleData?
    @StateObject private var scheduleManager = ScheduleManager()
    
    // ポイントシステム
    @StateObject private var pointsManager = PointsManager()
    
    
    // サービス
    @StateObject private var characterService = CharacterService()
    @StateObject private var errorManager = ErrorManager()
    
    let userId: String
    let characterId: String
    
    var body: some View {
        NavigationStack {
                VStack(spacing: 0) {
                    ZStack {
                        // 背景
                        colorSettings.getCurrentBackgroundGradient()
                            .ignoresSafeArea()
                        
                        // UI要素（背景レイヤー）
                        VStack(spacing: 0) {
                            // 上部：BIG5進捗表示と吹き出し
                            HStack {
                                BIG5ProgressView(answeredCount: characterService.big5AnsweredCount)
                                    .padding(.leading, 16)
                                    .padding(.top, 16)
                                Spacer()
                            }
                            .frame(height: 60)
                            
                            // 吹き出し表示
                            if !displayedMessage.isEmpty {
                                HStack {
                                    Text(displayedMessage)
                                        .padding()
                                        .background(Color.white.opacity(0.85))
                                        .foregroundColor(.black)
                                        .cornerRadius(16)
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                .padding(.top, 10)
                            }
                            
                            Spacer()
                            
                            // 下部：履歴ボタンとチャット入力（固定高さ）
                            VStack(spacing: 8) {
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
                                
                                // チャット入力
                                ChatInputComponent(
                                    userInput: $userInput,
                                    onSendMessage: sendMessage
                                )
                            }
                            .frame(height: 120) // チャット欄の高さを固定
                            .padding(.bottom, 20)
                        }
                        
                        // Live2Dキャラクター表示（最前面）
                        CharacterDisplayComponent(
                            displayedMessage: $displayedMessage,
                            singleImageUrl: nil, // Live2Dビューを使用
                            characterConfig: CharacterConfig(
                                id: "character_female",
                                name: "Koharu",
                                gender: .female,
                                imageSource: .local("character_female"),
                                isDefault: true
                            )
                        )
                        .frame(width: 600, height: 600) // サイズを少し小さく
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                        .allowsHitTesting(true) // タッチ可能にする
                        .background(Color.red.opacity(0.3)) // デバッグ用背景（一時的）
                        .onAppear {
                            print("🔍 HomeView - Live2Dキャラクター配置完了")
                        }
                    }
                }
                .onAppear {
            print("🔍 HomeView - onAppear開始")
            
            // UI設定は即座に実行
            colorSettings.forceRefresh()
            print("🔍 HomeView - colorSettings.forceRefresh完了")
            
            // NavigationStackの背景を透明にする
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            print("🔍 HomeView - NavigationBar設定完了")
            
            // 重い処理は非同期で実行
            DispatchQueue.main.async {
                print("🔍 HomeView - onViewAppear開始")
                onViewAppear()
                print("🔍 HomeView - onViewAppear完了")
            }
            
            // BIG5進捗の読み込みは遅延実行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔍 HomeView - BIG5進捗読み込み開始")
                characterService.loadInitialBIG5Progress(characterId: characterId)
                print("🔍 HomeView - BIG5進捗読み込み完了")
            }
            
            // キャラクターの自動アニメーション開始
            startCharacterAnimations()
            
            print("🔍 HomeView - onAppear完了")
        }
                .errorAlert(errorManager)
        }
        .navigationDestination(isPresented: $showChatHistory) {
            ChatHistoryView(userId: userId, characterId: characterId)
        }
        .overlay {
            if showScheduleConfirmation, let scheduleData = pendingScheduleData {
                ScheduleConfirmationPopup(
                    scheduleData: scheduleData,
                    onConfirm: { confirmedScheduleData in
                        scheduleManager.saveSchedule(from: confirmedScheduleData)
                        showScheduleConfirmation = false
                        pendingScheduleData = nil
                    },
                    onCancel: {
                        showScheduleConfirmation = false
                        pendingScheduleData = nil
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: showScheduleConfirmation)
            }
        }
    }
    
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(hex: "#EDE6F2"), Color(hex: "#F9F6F0")]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - View Lifecycle
    private func onViewAppear() {
        print("🔍 onViewAppear - 開始")
        
        if !hasLoadedInitialMessage {
            print("🔍 onViewAppear - キャラクター情報読み込み開始")
            loadCharacterInfo()
            hasLoadedInitialMessage = true
            print("🔍 onViewAppear - キャラクター情報読み込み完了")
        }
        
        if let currentUser = Auth.auth().currentUser {
            print("✅ Firebase 認証中 UID: \(currentUser.uid)")
        } else {
            print("❌ Firebase 認証されていません")
        }
        
        print("🔍 onViewAppear - 通知監視設定開始")
        
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
        
        print("🔍 onViewAppear - ポイント読み込み開始")
        // ポイント初期読み込み
        pointsManager.loadPoints(for: characterId)
        print("🔍 onViewAppear - ポイント読み込み完了")
    }
    
    // MARK: - Character Info Loading
    private func loadCharacterInfo() {
        print("🔍 loadCharacterInfo - 開始")
        
        characterService.loadCharacterInfo(userId: userId) { [self] result in
            print("🔍 loadCharacterInfo - API応答受信")
            
            DispatchQueue.main.async {
                print("🔍 loadCharacterInfo - メインキューで処理開始")
                
                switch result {
                case .success(let info):
                    print("🔍 loadCharacterInfo - 成功: \(info.initialMessage)")
                    // Live2DCharacterViewが画像管理するため、singleImageUrlは不要
                    // 初期メッセージのみ設定
                    if !info.initialMessage.isEmpty {
                        self.displayedMessage = info.initialMessage
                    }
                case .failure(let error):
                    print("🔍 loadCharacterInfo - エラー: \(error)")
                    self.errorManager.handleError(error)
                }
                
                print("🔍 loadCharacterInfo - メインキューで処理完了")
            }
        }
        
        print("🔍 loadCharacterInfo - API呼び出し完了")
    }

    
    // MARK: - Message Sending
    private func sendMessage() {
        handleChatLimit()
        
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        characterService.sendMessage(
            characterId: characterId,
            userMessage: trimmed,
            userId: userId
        ) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let reply):
                    self.handleCharacterReply(reply)
                    self.userInput = ""
                case .failure(let error):
                    self.errorManager.handleError(error)
                }
            }
        }
    }
    
    private func handleChatLimit() {
        chatLimitManager.consumeChat()
        
        if chatLimitManager.remainingChats == 0 {
            if let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController {
                rewardedAd.showAd(from: root) {
                    chatLimitManager.refillChats()
                }
            }
        }
    }
    
    private func handleCharacterReply(_ reply: CharacterReply) {
        fullCharacterMessage = reply.message
        displayedMessage = ""
        isSpeaking = true
        
        AudioService.shared.playVoice(url: reply.voiceUrl, volume: characterVolume)
        
        startTypewriterEffect(message: reply.message)
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
    
    // MARK: - Character Animation Control
    
    private func startCharacterAnimations() {
        print("🔍 HomeView - キャラクターアニメーション開始")
        
        // 定期的にランダムな表情変更
        randomMotionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.triggerRandomCharacterAction()
        }
    }
    
    private func triggerRandomCharacterAction() {
        print("🔍 HomeView - ランダムキャラクターアクション実行")
        
        // ランダムな表情変更
        let expressions: [CharacterExpression] = [.normal, .smile, .sleep]
        let randomExpression = expressions.randomElement() ?? .normal
        
        // 表情をランダムに変更（実際の実装では、CharacterDisplayComponentを参照）
        print("🔍 HomeView - 表情変更: \(randomExpression)")
        
        // 将来的にはCharacterDisplayComponentのメソッドを呼び出し可能
        // characterDisplayComponent?.changeExpression(to: randomExpression)
    }
    
    private func stopCharacterAnimations() {
        randomMotionTimer?.invalidate()
        randomMotionTimer = nil
    }
}
