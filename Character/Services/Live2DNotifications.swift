import Foundation

// MARK: - Live2D Notification Names
extension Notification.Name {
    // Basic Live2D Events
    static let live2DModelLoaded = Notification.Name("live2DModelLoaded")
    static let live2DModelLoadFailed = Notification.Name("live2DModelLoadFailed")
    static let live2DFrameworkInitialized = Notification.Name("live2DFrameworkInitialized")
    
    // Animation Events
    static let live2DBlinkAnimation = Notification.Name("live2DBlinkAnimation")
    static let live2DMotionPlay = Notification.Name("live2DMotionPlay")
    static let live2DMotionFinished = Notification.Name("live2DMotionFinished")
    static let live2DAnimationUpdate = Notification.Name("live2DAnimationUpdate")
    
    // Expression Events
    static let live2DExpressionChange = Notification.Name("live2DExpressionChange")
    static let live2DExpressionFinished = Notification.Name("live2DExpressionFinished")
    
    // Audio Events
    static let live2DTalkStart = Notification.Name("live2DTalkStart")
    static let live2DTalkStop = Notification.Name("live2DTalkStop")
    static let live2DLipSyncUpdate = Notification.Name("live2DLipSyncUpdate")
    static let live2DBreathingUpdate = Notification.Name("live2DBreathingUpdate")
    
    // Interaction Events
    static let live2DLookAt = Notification.Name("live2DLookAt")
    static let live2DTouchEvent = Notification.Name("live2DTouchEvent")
    static let live2DDragEvent = Notification.Name("live2DDragEvent")
    
    // Physics Events
    static let live2DPhysicsUpdate = Notification.Name("live2DPhysicsUpdate")
    static let live2DPhysicsReset = Notification.Name("live2DPhysicsReset")
    static let live2DPhysicsToggle = Notification.Name("live2DPhysicsToggle")
    
    // Parameter Events
    static let live2DParameterChange = Notification.Name("live2DParameterChange")
    static let live2DParameterReset = Notification.Name("live2DParameterReset")
    
    // Rendering Events
    static let live2DRenderingStart = Notification.Name("live2DRenderingStart")
    static let live2DRenderingStop = Notification.Name("live2DRenderingStop")
    static let live2DRenderingError = Notification.Name("live2DRenderingError")
    
    // Debug Events
    static let live2DDebugInfo = Notification.Name("live2DDebugInfo")
    static let live2DPerformanceWarning = Notification.Name("live2DPerformanceWarning")
}

// MARK: - Live2D Event Helper
class Live2DEventHelper {
    
    // MARK: - Motion Events
    static func playMotion(_ motionName: String, priority: Int = 1, loop: Bool = false) {
        NotificationCenter.default.post(
            name: .live2DMotionPlay,
            object: nil,
            userInfo: [
                "motionName": motionName,
                "priority": priority,
                "loop": loop
            ]
        )
    }
    
    // MARK: - Expression Events
    static func setExpression(_ expressionName: String, duration: Float = 1.0) {
        NotificationCenter.default.post(
            name: .live2DExpressionChange,
            object: nil,
            userInfo: [
                "expression": expressionName,
                "duration": duration
            ]
        )
    }
    
    // MARK: - Look At Events
    static func updateLookAt(x: Float, y: Float, smooth: Bool = true) {
        NotificationCenter.default.post(
            name: .live2DLookAt,
            object: nil,
            userInfo: [
                "x": x,
                "y": y,
                "smooth": smooth
            ]
        )
    }
    
    // MARK: - Audio Events
    static func startTalk(volume: Float = 0.5) {
        NotificationCenter.default.post(
            name: .live2DTalkStart,
            object: nil,
            userInfo: ["volume": volume]
        )
    }
    
    static func stopTalk() {
        NotificationCenter.default.post(
            name: .live2DTalkStop,
            object: nil
        )
    }
    
    static func updateLipSync(volume: Float) {
        NotificationCenter.default.post(
            name: .live2DLipSyncUpdate,
            object: nil,
            userInfo: ["volume": volume]
        )
    }
    
    // MARK: - Touch Events
    static func sendTouchEvent(x: Float, y: Float, pressure: Float = 1.0) {
        NotificationCenter.default.post(
            name: .live2DTouchEvent,
            object: nil,
            userInfo: [
                "x": x,
                "y": y,
                "pressure": pressure
            ]
        )
    }
    
    static func sendDragEvent(startX: Float, startY: Float, endX: Float, endY: Float) {
        NotificationCenter.default.post(
            name: .live2DDragEvent,
            object: nil,
            userInfo: [
                "startX": startX,
                "startY": startY,
                "endX": endX,
                "endY": endY
            ]
        )
    }
    
    // MARK: - Parameter Events
    static func setParameter(name: String, value: Float, weight: Float = 1.0) {
        NotificationCenter.default.post(
            name: .live2DParameterChange,
            object: nil,
            userInfo: [
                "name": name,
                "value": value,
                "weight": weight
            ]
        )
    }
    
    // MARK: - Animation Events
    static func triggerBlink() {
        NotificationCenter.default.post(
            name: .live2DBlinkAnimation,
            object: nil
        )
    }
    
    // MARK: - Physics Events
    static func updatePhysics(gravity: Float, wind: Float) {
        NotificationCenter.default.post(
            name: .live2DPhysicsUpdate,
            object: nil,
            userInfo: [
                "gravity": gravity,
                "wind": wind
            ]
        )
    }
    
    static func resetPhysics() {
        NotificationCenter.default.post(
            name: .live2DPhysicsReset,
            object: nil
        )
    }
    
    // MARK: - Debug Events
    static func sendDebugInfo(_ info: [String: Any]) {
        NotificationCenter.default.post(
            name: .live2DDebugInfo,
            object: nil,
            userInfo: info
        )
    }
    
    static func sendPerformanceWarning(_ message: String, fps: Float) {
        NotificationCenter.default.post(
            name: .live2DPerformanceWarning,
            object: nil,
            userInfo: [
                "message": message,
                "fps": fps
            ]
        )
    }
}

// MARK: - Live2D Event Observer
class Live2DEventObserver {
    private var observers: [NSObjectProtocol] = []
    
    deinit {
        removeAllObservers()
    }
    
    func removeAllObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    func observeModelLoad(handler: @escaping () -> Void) {
        let observer = NotificationCenter.default.addObserver(
            forName: .live2DModelLoaded,
            object: nil,
            queue: .main,
            using: { _ in handler() }
        )
        observers.append(observer)
    }
    
    func observeMotionFinish(handler: @escaping (String) -> Void) {
        let observer = NotificationCenter.default.addObserver(
            forName: .live2DMotionFinished,
            object: nil,
            queue: .main,
            using: { notification in
                if let motionName = notification.userInfo?["motion"] as? String {
                    handler(motionName)
                }
            }
        )
        observers.append(observer)
    }
    
    func observeExpressionChange(handler: @escaping (String) -> Void) {
        let observer = NotificationCenter.default.addObserver(
            forName: .live2DExpressionChange,
            object: nil,
            queue: .main,
            using: { notification in
                if let expression = notification.userInfo?["expression"] as? String {
                    handler(expression)
                }
            }
        )
        observers.append(observer)
    }
    
    func observePerformanceWarning(handler: @escaping (String, Float) -> Void) {
        let observer = NotificationCenter.default.addObserver(
            forName: .live2DPerformanceWarning,
            object: nil,
            queue: .main,
            using: { notification in
                if let message = notification.userInfo?["message"] as? String,
                   let fps = notification.userInfo?["fps"] as? Float {
                    handler(message, fps)
                }
            }
        )
        observers.append(observer)
    }
}