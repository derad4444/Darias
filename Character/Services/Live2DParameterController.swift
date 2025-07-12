import Foundation
import Combine

// MARK: - Live2D Parameter Controller
class Live2DParameterController: ObservableObject {
    // MARK: - Properties
    @Published var parameters: [String: Float] = [:]
    @Published var parameterRanges: [String: ParameterRange] = [:]
    @Published var isParameterSmoothingEnabled: Bool = true
    @Published var smoothingFactor: Float = 0.1
    
    var live2DManager: Live2DManager?
    private var cancellables = Set<AnyCancellable>()
    private var parameterTargets: [String: Float] = [:]
    private var parameterUpdateTimer: Timer?
    
    // パラメータの種類定義
    struct ParameterRange {
        let minValue: Float
        let maxValue: Float
        let defaultValue: Float
        let description: String
        
        init(min: Float, max: Float, defaultValue: Float, description: String = "") {
            self.minValue = min
            self.maxValue = max
            self.defaultValue = defaultValue
            self.description = description
        }
    }
    
    // Live2D標準パラメータ定義
    private let standardParameters: [String: ParameterRange] = [
        // 顔の角度
        "ParamAngleX": ParameterRange(min: -30.0, max: 30.0, defaultValue: 0.0, description: "顔の左右角度"),
        "ParamAngleY": ParameterRange(min: -30.0, max: 30.0, defaultValue: 0.0, description: "顔の上下角度"),
        "ParamAngleZ": ParameterRange(min: -30.0, max: 30.0, defaultValue: 0.0, description: "顔の回転角度"),
        
        // 目
        "ParamEyeLOpen": ParameterRange(min: 0.0, max: 1.0, defaultValue: 1.0, description: "左目の開閉"),
        "ParamEyeROpen": ParameterRange(min: 0.0, max: 1.0, defaultValue: 1.0, description: "右目の開閉"),
        "ParamEyeBallX": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "眼球の左右位置"),
        "ParamEyeBallY": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "眼球の上下位置"),
        
        // 眉
        "ParamBrowLY": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "左眉の上下"),
        "ParamBrowRY": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "右眉の上下"),
        "ParamBrowLX": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "左眉の角度"),
        "ParamBrowRX": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "右眉の角度"),
        
        // 口
        "ParamMouthOpenY": ParameterRange(min: 0.0, max: 1.0, defaultValue: 0.0, description: "口の開閉"),
        "ParamMouthForm": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "口の形"),
        
        // 体
        "ParamBodyAngleX": ParameterRange(min: -10.0, max: 10.0, defaultValue: 0.0, description: "体の左右角度"),
        "ParamBodyAngleY": ParameterRange(min: -10.0, max: 10.0, defaultValue: 0.0, description: "体の上下角度"),
        "ParamBodyAngleZ": ParameterRange(min: -10.0, max: 10.0, defaultValue: 0.0, description: "体の回転角度"),
        
        // 髪
        "ParamHairFront": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "前髪の揺れ"),
        "ParamHairSide": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "横髪の揺れ"),
        "ParamHairBack": ParameterRange(min: -1.0, max: 1.0, defaultValue: 0.0, description: "後ろ髪の揺れ"),
        
        // 呼吸
        "ParamBreath": ParameterRange(min: 0.0, max: 1.0, defaultValue: 0.0, description: "呼吸"),
        
        // カスタム表情パラメータ
        "ParamHappy": ParameterRange(min: 0.0, max: 1.0, defaultValue: 0.0, description: "幸せな表情"),
        "ParamSad": ParameterRange(min: 0.0, max: 1.0, defaultValue: 0.0, description: "悲しい表情"),
        "ParamAngry": ParameterRange(min: 0.0, max: 1.0, defaultValue: 0.0, description: "怒った表情"),
        "ParamSurprised": ParameterRange(min: 0.0, max: 1.0, defaultValue: 0.0, description: "驚いた表情"),
    ]
    
    // MARK: - Initialization
    init(live2DManager: Live2DManager? = nil) {
        self.live2DManager = live2DManager
        setupParameters()
        setupNotificationObservers()
        startParameterUpdating()
    }
    
    private func setupParameters() {
        // 標準パラメータの初期化
        parameterRanges = standardParameters
        
        // デフォルト値の設定
        for (name, range) in standardParameters {
            parameters[name] = range.defaultValue
            parameterTargets[name] = range.defaultValue
        }
    }
    
    private func setupNotificationObservers() {
        // パラメータ変更要求の監視
        NotificationCenter.default.addObserver(
            forName: .live2DParameterChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleParameterChangeRequest(notification)
        }
        
        // パラメータリセット要求の監視
        NotificationCenter.default.addObserver(
            forName: .live2DParameterReset,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.resetAllParameters()
        }
    }
    
    private func startParameterUpdating() {
        parameterUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateParameters()
        }
    }
    
    // MARK: - Parameter Control
    func setParameter(name: String, value: Float, weight: Float = 1.0, smooth: Bool = true) {
        guard let range = parameterRanges[name] else {
            print("Warning: Unknown parameter '\(name)'")
            return
        }
        
        // 値の範囲チェック
        let clampedValue = max(range.minValue, min(range.maxValue, value))
        
        if smooth && isParameterSmoothingEnabled {
            parameterTargets[name] = clampedValue
        } else {
            parameters[name] = clampedValue
            parameterTargets[name] = clampedValue
            applyParameterToLive2D(name: name, value: clampedValue, weight: weight)
        }
        
        print("Setting parameter '\(name)' to \(clampedValue) (weight: \(weight))")
    }
    
    func getParameter(name: String) -> Float? {
        return parameters[name]
    }
    
    func addCustomParameter(name: String, range: ParameterRange) {
        parameterRanges[name] = range
        parameters[name] = range.defaultValue
        parameterTargets[name] = range.defaultValue
        
        print("Added custom parameter: \(name)")
    }
    
    func removeParameter(name: String) {
        parameterRanges.removeValue(forKey: name)
        parameters.removeValue(forKey: name)
        parameterTargets.removeValue(forKey: name)
        
        print("Removed parameter: \(name)")
    }
    
    private func updateParameters() {
        guard isParameterSmoothingEnabled else { return }
        
        var hasChanges = false
        
        for (name, targetValue) in parameterTargets {
            guard let currentValue = parameters[name] else { continue }
            
            let difference = targetValue - currentValue
            
            if abs(difference) > 0.001 {
                let smoothedValue = currentValue + difference * smoothingFactor
                parameters[name] = smoothedValue
                applyParameterToLive2D(name: name, value: smoothedValue, weight: 1.0)
                hasChanges = true
            }
        }
        
        if hasChanges {
            objectWillChange.send()
        }
    }
    
    private func applyParameterToLive2D(name: String, value: Float, weight: Float) {
        live2DManager?.setParameter(name: name, value: value)
    }
    
    // MARK: - Expression Control
    func setExpression(name: String, intensity: Float = 1.0) {
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        switch name.lowercased() {
        case "happy":
            setHappyExpression(intensity: clampedIntensity)
        case "sad":
            setSadExpression(intensity: clampedIntensity)
        case "angry":
            setAngryExpression(intensity: clampedIntensity)
        case "surprised":
            setSurprisedExpression(intensity: clampedIntensity)
        case "normal", "neutral":
            resetExpressionParameters()
        default:
            print("Unknown expression: \(name)")
        }
    }
    
    private func setHappyExpression(intensity: Float) {
        setParameter(name: "ParamHappy", value: intensity)
        setParameter(name: "ParamSad", value: 0.0)
        setParameter(name: "ParamAngry", value: 0.0)
        setParameter(name: "ParamSurprised", value: 0.0)
        
        // 口の形を笑顔に
        setParameter(name: "ParamMouthForm", value: intensity * 0.8)
        // 眉を少し上げる
        setParameter(name: "ParamBrowLY", value: intensity * 0.3)
        setParameter(name: "ParamBrowRY", value: intensity * 0.3)
    }
    
    private func setSadExpression(intensity: Float) {
        setParameter(name: "ParamSad", value: intensity)
        setParameter(name: "ParamHappy", value: 0.0)
        setParameter(name: "ParamAngry", value: 0.0)
        setParameter(name: "ParamSurprised", value: 0.0)
        
        // 眉を下げる
        setParameter(name: "ParamBrowLY", value: -intensity * 0.5)
        setParameter(name: "ParamBrowRY", value: -intensity * 0.5)
        // 口を下げる
        setParameter(name: "ParamMouthForm", value: -intensity * 0.6)
    }
    
    private func setAngryExpression(intensity: Float) {
        setParameter(name: "ParamAngry", value: intensity)
        setParameter(name: "ParamHappy", value: 0.0)
        setParameter(name: "ParamSad", value: 0.0)
        setParameter(name: "ParamSurprised", value: 0.0)
        
        // 眉を寄せる
        setParameter(name: "ParamBrowLX", value: intensity * 0.7)
        setParameter(name: "ParamBrowRX", value: -intensity * 0.7)
        setParameter(name: "ParamBrowLY", value: -intensity * 0.3)
        setParameter(name: "ParamBrowRY", value: -intensity * 0.3)
    }
    
    private func setSurprisedExpression(intensity: Float) {
        setParameter(name: "ParamSurprised", value: intensity)
        setParameter(name: "ParamHappy", value: 0.0)
        setParameter(name: "ParamSad", value: 0.0)
        setParameter(name: "ParamAngry", value: 0.0)
        
        // 眉を上げる
        setParameter(name: "ParamBrowLY", value: intensity * 0.8)
        setParameter(name: "ParamBrowRY", value: intensity * 0.8)
        // 口を開ける
        setParameter(name: "ParamMouthOpenY", value: intensity * 0.5)
    }
    
    private func resetExpressionParameters() {
        let expressionParams = ["ParamHappy", "ParamSad", "ParamAngry", "ParamSurprised"]
        
        for param in expressionParams {
            setParameter(name: param, value: 0.0)
        }
        
        // 顔のパラメータもリセット
        setParameter(name: "ParamBrowLY", value: 0.0)
        setParameter(name: "ParamBrowRY", value: 0.0)
        setParameter(name: "ParamBrowLX", value: 0.0)
        setParameter(name: "ParamBrowRX", value: 0.0)
        setParameter(name: "ParamMouthForm", value: 0.0)
        setParameter(name: "ParamMouthOpenY", value: 0.0)
    }
    
    // MARK: - Breathing Animation
    private var breathingPhase: Float = 0.0
    
    func startBreathing(intensity: Float = 0.5, speed: Float = 1.0) {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.breathingPhase += 0.1 * speed
            let breathValue = sin(self.breathingPhase) * intensity
            
            self.setParameter(name: "ParamBreath", value: breathValue, smooth: false)
            self.setParameter(name: "ParamBodyAngleY", value: breathValue * 0.3, smooth: false)
        }
    }
    
    // MARK: - Preset Animations
    func playBlinkAnimation() {
        // 瞬きアニメーション
        setParameter(name: "ParamEyeLOpen", value: 0.0, smooth: false)
        setParameter(name: "ParamEyeROpen", value: 0.0, smooth: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setParameter(name: "ParamEyeLOpen", value: 1.0)
            self.setParameter(name: "ParamEyeROpen", value: 1.0)
        }
    }
    
    func playNodAnimation() {
        // うなずきアニメーション
        setParameter(name: "ParamAngleY", value: -10.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setParameter(name: "ParamAngleY", value: 5.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.setParameter(name: "ParamAngleY", value: 0.0)
        }
    }
    
    func playShakeHeadAnimation() {
        // 首を振るアニメーション
        setParameter(name: "ParamAngleX", value: -15.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setParameter(name: "ParamAngleX", value: 15.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.setParameter(name: "ParamAngleX", value: -10.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.setParameter(name: "ParamAngleX", value: 0.0)
        }
    }
    
    // MARK: - Event Handlers
    private func handleParameterChangeRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let name = userInfo["name"] as? String,
              let value = userInfo["value"] as? Float else { return }
        
        let weight = userInfo["weight"] as? Float ?? 1.0
        setParameter(name: name, value: value, weight: weight)
    }
    
    func resetAllParameters() {
        for (name, range) in parameterRanges {
            setParameter(name: name, value: range.defaultValue, smooth: false)
        }
        
        print("All parameters reset to default values")
    }
    
    // MARK: - Settings
    func setSmoothingEnabled(_ enabled: Bool) {
        isParameterSmoothingEnabled = enabled
        print("Parameter smoothing \(enabled ? "enabled" : "disabled")")
    }
    
    func setSmoothingFactor(_ factor: Float) {
        smoothingFactor = max(0.01, min(1.0, factor))
        print("Smoothing factor set to: \(smoothingFactor)")
    }
    
    // MARK: - Utility
    func getParameterInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        for (name, range) in parameterRanges {
            info[name] = [
                "current": parameters[name] ?? 0.0,
                "min": range.minValue,
                "max": range.maxValue,
                "default": range.defaultValue,
                "description": range.description
            ]
        }
        
        return info
    }
    
    func getAllParameterNames() -> [String] {
        return Array(parameterRanges.keys).sorted()
    }
    
    func getExpressionParameterNames() -> [String] {
        return ["ParamHappy", "ParamSad", "ParamAngry", "ParamSurprised"]
    }
    
    func getFaceParameterNames() -> [String] {
        return [
            "ParamAngleX", "ParamAngleY", "ParamAngleZ",
            "ParamEyeLOpen", "ParamEyeROpen",
            "ParamEyeBallX", "ParamEyeBallY",
            "ParamBrowLY", "ParamBrowRY",
            "ParamMouthOpenY", "ParamMouthForm"
        ]
    }
    
    // MARK: - Cleanup
    deinit {
        parameterUpdateTimer?.invalidate()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
        
        print("Live2D Parameter Controller deinitialized")
    }
}