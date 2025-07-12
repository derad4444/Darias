import SwiftUI
import Foundation

class Live2DCharacterViewModel: ObservableObject {
    // アニメーション状態
    @Published var currentAnimation: String = "idle"
    @Published var isAnimationPlaying: Bool = true
    @Published var isBlinking: Bool = false
    @Published var isLipSyncing: Bool = false
    @Published var currentExpression: CharacterExpression = .normal
    @Published var characterGender: CharacterGender = .female
    
    // Live2D用の追加プロパティ
    @Published var headX: Float = 0.0
    @Published var headY: Float = 0.0
    @Published var eyeX: Float = 0.0
    @Published var eyeY: Float = 0.0
    @Published var mouthForm: Float = 0.0
    @Published var mouthOpenY: Float = 0.0
    
    // タイマー
    private var blinkTimer: Timer?
    private var lipSyncTimer: Timer?
    private var expressionTimer: Timer?
    private var idleMotionTimer: Timer?
    
    var modelName: String {
        return "character_\(characterGender.rawValue)"
    }
    
    init(gender: CharacterGender = .female) {
        self.characterGender = gender
        startIdleAnimation()
        startBlinkAnimation()
        startIdleMotion()
    }
    
    deinit {
        stopAllAnimations()
    }
    
    // MARK: - Animation Controls
    
    func startIdleAnimation() {
        currentAnimation = "idle"
        isAnimationPlaying = true
    }
    
    func playMotion(_ motionName: String) {
        print("🔍 Live2DCharacterViewModel - playMotion: \(motionName)")
        
        currentAnimation = motionName
        
        // モーションに応じた動作
        switch motionName {
        case "Tap":
            // タップ時の動作
            headX = Float.random(in: -10...10)
            headY = Float.random(in: -5...5)
            
            // 1秒後に元に戻る
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.headX = 0.0
                self.headY = 0.0
            }
            
        case "FlickLeft":
            headX = -15.0
            headY = 2.0
            
        case "FlickRight":
            headX = 15.0
            headY = -2.0
            
        case "FlickUp":
            headY = -10.0
            
        case "FlickDown":
            headY = 10.0
            
        case "Idle":
            headX = 0.0
            headY = 0.0
            
        default:
            break
        }
        
        // 2秒後にアイドル状態に戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.currentAnimation = "idle"
            self.headX = 0.0
            self.headY = 0.0
        }
    }
    
    func startBlinkAnimation() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.0...4.0), repeats: true) { _ in
            self.performBlink()
        }
    }
    
    func stopBlinkAnimation() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }
    
    func startIdleMotion() {
        idleMotionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateIdleMotion()
        }
    }
    
    private func updateIdleMotion() {
        // ゆるやかな呼吸アニメーション
        let time = Date().timeIntervalSince1970
        let breathingScale = 1.0 + 0.02 * sin(time * 2.0)
        
        // 視線のゆらぎ
        eyeX = Float(0.1 * sin(time * 0.5))
        eyeY = Float(0.1 * cos(time * 0.3))
        
        // 頭の微細な動き
        headX = Float(0.05 * sin(time * 0.7))
        headY = Float(0.03 * cos(time * 0.8))
        
        // Live2Dの呼吸パラメータ更新をNotificationで通知
        NotificationCenter.default.post(
            name: .live2DBreathingUpdate,
            object: nil,
            userInfo: [
                "modelName": modelName,
                "scale": breathingScale,
                "eyeX": eyeX,
                "eyeY": eyeY,
                "headX": headX,
                "headY": headY
            ]
        )
    }
    
    private func performBlink() {
        guard !isLipSyncing else { return }
        
        isBlinking = true
        
        // Live2D側で瞬きアニメーション実行
        NotificationCenter.default.post(
            name: .live2DBlinkAnimation,
            object: nil,
            userInfo: ["modelName": modelName]
        )
        
        // 瞬き状態を0.2秒後にリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isBlinking = false
        }
        
        // 次の瞬きタイミングをランダムに設定
        blinkTimer?.invalidate()
        let nextBlinkInterval = Double.random(in: 2.0...5.0)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: nextBlinkInterval, repeats: false) { _ in
            self.performBlink()
        }
    }
    
    func startLipSync() {
        isLipSyncing = true
        
        // Live2D側で口パクアニメーション開始
        NotificationCenter.default.post(
            name: .live2DTalkStart,
            object: nil,
            userInfo: ["modelName": modelName]
        )
        
        // 口パクのバリエーション
        lipSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.performLipSyncVariation()
        }
    }
    
    func stopLipSync() {
        isLipSyncing = false
        lipSyncTimer?.invalidate()
        lipSyncTimer = nil
        mouthOpenY = 0.0
        mouthForm = 0.0
        
        // Live2D側で口パクアニメーション停止
        NotificationCenter.default.post(
            name: .live2DTalkStop,
            object: nil,
            userInfo: ["modelName": modelName]
        )
        
        // アイドルアニメーションに戻す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.startIdleAnimation()
        }
    }
    
    private func performLipSyncVariation() {
        // 音声に合わせた口の形の変化をシミュレート
        mouthOpenY = Float.random(in: 0.3...1.0)
        mouthForm = Float.random(in: 0.0...0.7)
        
        NotificationCenter.default.post(
            name: .live2DLipSyncUpdate,
            object: nil,
            userInfo: [
                "modelName": modelName,
                "mouthOpenY": mouthOpenY,
                "mouthForm": mouthForm
            ]
        )
    }
    
    func changeExpression(to expression: CharacterExpression, duration: TimeInterval = 3.0) {
        currentExpression = expression
        
        // Live2D側でアニメーション変更
        NotificationCenter.default.post(
            name: .live2DExpressionChange,
            object: nil,
            userInfo: [
                "modelName": modelName,
                "expression": expression.rawValue
            ]
        )
        
        // 一定時間後に通常表情に戻す
        if expression != .normal {
            expressionTimer?.invalidate()
            expressionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                self.changeExpression(to: .normal)
            }
        }
    }
    
    func switchGender() {
        stopAllAnimations()
        characterGender = characterGender == .male ? .female : .male
        startIdleAnimation()
        startBlinkAnimation()
        startIdleMotion()
    }
    
    func pauseAnimation() {
        isAnimationPlaying = false
        idleMotionTimer?.invalidate()
    }
    
    func resumeAnimation() {
        isAnimationPlaying = true
        startIdleMotion()
    }
    
    // MARK: - Live2D特有の機能
    
    func lookAt(x: Float, y: Float) {
        eyeX = x * 0.5  // 視線の範囲を調整
        eyeY = y * 0.5
        headX = x * 0.3  // 頭の動きを追加
        headY = y * 0.2
        
        NotificationCenter.default.post(
            name: .live2DLookAt,
            object: nil,
            userInfo: [
                "modelName": modelName,
                "eyeX": eyeX,
                "eyeY": eyeY,
                "headX": headX,
                "headY": headY
            ]
        )
    }
    
    func resetLook() {
        lookAt(x: 0, y: 0)
    }
    
    func playMotion(_ motionName: String, priority: Int = 1) {
        currentAnimation = motionName
        
        NotificationCenter.default.post(
            name: .live2DMotionPlay,
            object: nil,
            userInfo: [
                "modelName": modelName,
                "motionName": motionName,
                "priority": priority
            ]
        )
    }
    
    func setPhysicsEnabled(_ enabled: Bool) {
        NotificationCenter.default.post(
            name: .live2DPhysicsToggle,
            object: nil,
            userInfo: [
                "modelName": modelName,
                "enabled": enabled
            ]
        )
    }
    
    private func stopAllAnimations() {
        stopBlinkAnimation()
        stopLipSync()
        expressionTimer?.invalidate()
        expressionTimer = nil
        idleMotionTimer?.invalidate()
        idleMotionTimer = nil
    }
}
