import Foundation
import Combine

// MARK: - Live2D Animation Controller
class Live2DAnimationController: ObservableObject {
    // MARK: - Properties
    @Published var currentMotion: String = "idle"
    @Published var currentExpression: String = "normal"
    @Published var isPlaying: Bool = false
    @Published var animationSpeed: Float = 1.0
    
    var live2DManager: Live2DManager?
    private var cancellables = Set<AnyCancellable>()
    private var motionQueue: [MotionRequest] = []
    private var isProcessingMotion: Bool = false
    
    // タイマーによる自動アニメーション
    private var autoAnimationTimer: Timer?
    private var blinkTimer: Timer?
    
    // MARK: - Animation State
    struct MotionRequest {
        let motionName: String
        let priority: Int
        let loop: Bool
        let fadeInTime: Float
        let fadeOutTime: Float
        
        init(motionName: String, priority: Int = 1, loop: Bool = false, fadeInTime: Float = 0.5, fadeOutTime: Float = 0.5) {
            self.motionName = motionName
            self.priority = priority
            self.loop = loop
            self.fadeInTime = fadeInTime
            self.fadeOutTime = fadeOutTime
        }
    }
    
    // MARK: - Initialization
    init(live2DManager: Live2DManager? = nil) {
        self.live2DManager = live2DManager
        setupNotificationObservers()
        // Defer auto animations to prevent UI freeze
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startAutoAnimations()
        }
    }
    
    private func setupNotificationObservers() {
        // モーション再生要求の監視
        NotificationCenter.default.addObserver(
            forName: .live2DMotionPlay,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMotionRequest(notification)
        }
        
        // モーション終了の監視
        NotificationCenter.default.addObserver(
            forName: .live2DMotionFinished,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMotionFinished(notification)
        }
        
        // 表情変更要求の監視
        NotificationCenter.default.addObserver(
            forName: .live2DExpressionChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleExpressionRequest(notification)
        }
    }
    
    // MARK: - Motion Control
    func playMotion(_ motionName: String, priority: Int = 1, loop: Bool = false) {
        let request = MotionRequest(motionName: motionName, priority: priority, loop: loop)
        
        if priority >= getCurrentMotionPriority() {
            // 高優先度の場合は即座に再生
            executeMotion(request)
        } else {
            // 低優先度の場合はキューに追加
            motionQueue.append(request)
            motionQueue.sort { $0.priority > $1.priority }
        }
    }
    
    private func executeMotion(_ request: MotionRequest) {
        guard let live2DManager = live2DManager else { return }
        
        isProcessingMotion = true
        currentMotion = request.motionName
        
        // Live2D Manager にモーション再生を指示
        live2DManager.playMotion(motionName: request.motionName, priority: request.priority)
        
        // アニメーション状態の更新
        DispatchQueue.main.async {
            self.isPlaying = true
            self.objectWillChange.send()
        }
        
        print("Playing motion: \(request.motionName) with priority: \(request.priority)")
        
        // モーション終了をシミュレート（実際のSDKでは自動的に通知される）
        if !request.loop {
            let duration = getMotionDuration(request.motionName)
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(duration)) {
                self.notifyMotionFinished(request.motionName)
            }
        }
    }
    
    private func handleMotionRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let motionName = userInfo["motion"] as? String else { return }
        
        let priority = userInfo["priority"] as? Int ?? 1
        let loop = userInfo["loop"] as? Bool ?? false
        
        playMotion(motionName, priority: priority, loop: loop)
    }
    
    private func handleMotionFinished(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let motionName = userInfo["motion"] as? String else { return }
        
        print("Motion finished: \(motionName)")
        
        isProcessingMotion = false
        isPlaying = false
        
        // キューに待機中のモーションがあれば再生
        processMotionQueue()
        
        // アイドル状態に戻る
        if motionQueue.isEmpty && currentMotion != "idle" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.playIdleMotion()
            }
        }
    }
    
    private func processMotionQueue() {
        guard !motionQueue.isEmpty, !isProcessingMotion else { return }
        
        let nextMotion = motionQueue.removeFirst()
        executeMotion(nextMotion)
    }
    
    private func notifyMotionFinished(_ motionName: String) {
        NotificationCenter.default.post(
            name: .live2DMotionFinished,
            object: nil,
            userInfo: ["motion": motionName]
        )
    }
    
    // MARK: - Expression Control
    func setExpression(_ expressionName: String, duration: Float = 1.0) {
        guard let live2DManager = live2DManager else { return }
        
        currentExpression = expressionName
        live2DManager.setExpression(expressionName: expressionName)
        
        print("Setting expression: \(expressionName)")
        
        // 表情変更完了を通知
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(duration)) {
            NotificationCenter.default.post(
                name: .live2DExpressionFinished,
                object: nil,
                userInfo: ["expression": expressionName]
            )
        }
    }
    
    private func handleExpressionRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let expressionName = userInfo["expression"] as? String else { return }
        
        let duration = userInfo["duration"] as? Float ?? 1.0
        setExpression(expressionName, duration: duration)
    }
    
    // MARK: - Auto Animations
    private func startAutoAnimations() {
        startAutoBlinking()
        startIdleMotions()
    }
    
    private func startAutoBlinking() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.triggerAutoBlink()
        }
    }
    
    private func startIdleMotions() {
        autoAnimationTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.triggerIdleVariation()
        }
    }
    
    private func triggerAutoBlink() {
        guard !isProcessingMotion else { return }
        
        live2DManager?.triggerBlink()
        print("Auto blink triggered")
    }
    
    private func triggerIdleVariation() {
        guard !isProcessingMotion, currentMotion == "idle" else { return }
        
        let idleVariations = ["idle", "idle_02"]
        let randomIdle = idleVariations.randomElement() ?? "idle"
        
        playMotion(randomIdle, priority: 0, loop: false)
    }
    
    private func playIdleMotion() {
        playMotion("idle", priority: 0, loop: true)
    }
    
    // MARK: - Animation Speed Control
    func setAnimationSpeed(_ speed: Float) {
        animationSpeed = max(0.1, min(3.0, speed)) // 0.1倍〜3.0倍の範囲
        
        // 実際のSDKでは、ここでアニメーション速度を設定
        // live2DManager?.setAnimationSpeed(animationSpeed)
        
        print("Animation speed set to: \(animationSpeed)")
    }
    
    // MARK: - Motion Management
    func stopCurrentMotion() {
        guard isPlaying else { return }
        
        isPlaying = false
        isProcessingMotion = false
        motionQueue.removeAll()
        
        // アイドル状態に戻る
        playIdleMotion()
        
        print("Current motion stopped")
    }
    
    func pauseAnimation() {
        isPlaying = false
        // 実際のSDKでは、ここでアニメーションを一時停止
        print("Animation paused")
    }
    
    func resumeAnimation() {
        isPlaying = true
        // 実際のSDKでは、ここでアニメーションを再開
        print("Animation resumed")
    }
    
    // MARK: - Helper Methods
    private func getCurrentMotionPriority() -> Int {
        // 現在のモーションの優先度を返す
        // 実際のSDKでは、Live2Dモデルから取得
        switch currentMotion {
        case "idle", "idle_02":
            return 0
        case let motion where motion.contains("tap"):
            return 2
        case let motion where motion.contains("flick"):
            return 1
        default:
            return 1
        }
    }
    
    private func getMotionDuration(_ motionName: String) -> Float {
        // モーションの長さを返す（秒）
        // 実際のSDKでは、Live2Dモデルから取得
        switch motionName {
        case "idle":
            return 3.0
        case "idle_02":
            return 4.0
        case let motion where motion.contains("tap"):
            return 2.0
        case let motion where motion.contains("flick"):
            return 1.5
        default:
            return 2.0
        }
    }
    
    // MARK: - Available Motions and Expressions
    func getAvailableMotions() -> [String] {
        return [
            "idle", "idle_02",
            "01_female", "02_female", "03_female", "04_female", "05_female",
            "06_female", "07_female", "08_female", "09_female",
            "01_male", "02_male", "03_male", "04_male", "05_male",
            "06_male", "07_male", "08_male", "09_male"
        ]
    }
    
    func getAvailableExpressions() -> [String] {
        return ["normal", "happy", "sad", "angry", "surprised", "confused", "excited"]
    }
    
    // MARK: - Update Loop
    func update(deltaTime: Float) {
        // フレーム毎の更新処理
        updateCurrentAnimation(deltaTime: deltaTime)
        processMotionQueue()
        updateAnimationState()
    }
    
    private func updateCurrentAnimation(deltaTime: Float) {
        // アニメーションの進行状況を更新
        // 実際のLive2D SDKと連携する場合、ここでモーションの更新を行う
        guard let live2DManager = live2DManager else { return }
        live2DManager.updateAnimation(deltaTime: deltaTime)
    }
    
    private func updateAnimationState() {
        // アニメーション状態の同期
        if isPlaying != isProcessingMotion {
            DispatchQueue.main.async {
                self.isPlaying = self.isProcessingMotion
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        autoAnimationTimer?.invalidate()
        blinkTimer?.invalidate()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
        
        print("Live2D Animation Controller deinitialized")
    }
}

// MARK: - Animation Presets
extension Live2DAnimationController {
    
    func playHappySequence() {
        setExpression("happy")
        playMotion("02_female", priority: 2) // 笑顔のモーション
    }
    
    func playSadSequence() {
        setExpression("sad")
        playMotion("03_female", priority: 2) // 悲しみのモーション
    }
    
    func playGreetingSequence() {
        setExpression("happy")
        playMotion("01_female", priority: 2) // 挨拶のモーション
    }
    
    func playTouchReaction(at point: CGPoint) {
        // タッチ位置に応じたリアクション
        let reactions = ["04_female", "05_female", "06_female"]
        let randomReaction = reactions.randomElement() ?? "04_female"
        
        playMotion(randomReaction, priority: 2)
    }
    
    func playRandomMotion() {
        let availableMotions = getAvailableMotions().filter { $0 != "idle" && $0 != "idle_02" }
        if let randomMotion = availableMotions.randomElement() {
            playMotion(randomMotion, priority: 1)
        }
    }
}