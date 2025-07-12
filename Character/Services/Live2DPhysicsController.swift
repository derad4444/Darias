import Foundation
import CoreMotion
import Combine

// MARK: - Live2D Physics Controller
class Live2DPhysicsController: ObservableObject {
    // MARK: - Properties
    @Published var isPhysicsEnabled: Bool = true
    @Published var gravityStrength: Float = 1.0
    @Published var windStrength: Float = 0.0
    @Published var windDirection: Float = 0.0 // 0-360度
    @Published var dampingFactor: Float = 0.9
    @Published var isDeviceMotionEnabled: Bool = false
    
    var live2DManager: Live2DManager?
    var parameterController: Live2DParameterController?
    private var motionManager = CMMotionManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Physics simulation properties
    private var physicsTimer: Timer?
    private var physicsObjects: [PhysicsObject] = []
    private var lastUpdateTime: Date = Date()
    
    // Wind simulation
    private var windPhase: Float = 0.0
    private var windTimer: Timer?
    
    // Device motion
    private var deviceAcceleration = SIMD3<Float>(0, 0, 0)
    private var deviceRotation = SIMD3<Float>(0, 0, 0)
    
    // MARK: - Physics Object Definition
    struct PhysicsObject {
        let parameterName: String
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var acceleration: SIMD2<Float>
        let mass: Float
        let damping: Float
        let restLength: Float
        let stiffness: Float
        
        init(parameterName: String, mass: Float = 1.0, damping: Float = 0.9, restLength: Float = 0.0, stiffness: Float = 10.0) {
            self.parameterName = parameterName
            self.position = SIMD2<Float>(0, 0)
            self.velocity = SIMD2<Float>(0, 0)
            self.acceleration = SIMD2<Float>(0, 0)
            self.mass = mass
            self.damping = damping
            self.restLength = restLength
            self.stiffness = stiffness
        }
    }
    
    // MARK: - Initialization
    init(live2DManager: Live2DManager? = nil, parameterController: Live2DParameterController? = nil) {
        self.live2DManager = live2DManager
        self.parameterController = parameterController
        setupPhysicsObjects()
        setupNotificationObservers()
        startPhysicsSimulation()
        setupDeviceMotion()
    }
    
    private func setupPhysicsObjects() {
        // 髪の毛の物理オブジェクト
        physicsObjects = [
            PhysicsObject(parameterName: "ParamHairFront", mass: 0.8, damping: 0.85, stiffness: 15.0),
            PhysicsObject(parameterName: "ParamHairSide", mass: 1.0, damping: 0.80, stiffness: 12.0),
            PhysicsObject(parameterName: "ParamHairBack", mass: 1.2, damping: 0.75, stiffness: 10.0),
            
            // 服やアクセサリーの物理オブジェクト
            PhysicsObject(parameterName: "ParamClothes", mass: 0.5, damping: 0.90, stiffness: 20.0),
            PhysicsObject(parameterName: "ParamNecklace", mass: 0.3, damping: 0.95, stiffness: 25.0),
            PhysicsObject(parameterName: "ParamEarrings", mass: 0.2, damping: 0.92, stiffness: 18.0),
            
            // 体の揺れ
            PhysicsObject(parameterName: "ParamBodyAngleX", mass: 2.0, damping: 0.95, stiffness: 8.0),
            PhysicsObject(parameterName: "ParamBodyAngleZ", mass: 2.0, damping: 0.95, stiffness: 8.0),
        ]
    }
    
    private func setupNotificationObservers() {
        // 物理演算更新要求の監視
        NotificationCenter.default.addObserver(
            forName: .live2DPhysicsUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handlePhysicsUpdateRequest(notification)
        }
        
        // 物理演算リセット要求の監視
        NotificationCenter.default.addObserver(
            forName: .live2DPhysicsReset,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.resetPhysics()
        }
    }
    
    // MARK: - Physics Simulation
    private func startPhysicsSimulation() {
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updatePhysics()
        }
        
        // 風のシミュレーション
        windTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateWind()
        }
    }
    
    private func updatePhysics() {
        guard isPhysicsEnabled else { return }
        
        let currentTime = Date()
        let deltaTime = Float(currentTime.timeIntervalSince(lastUpdateTime))
        lastUpdateTime = currentTime
        
        // デルタタイムの制限（異常値の回避）
        let clampedDeltaTime = min(deltaTime, 1.0/30.0)
        
        for i in 0..<physicsObjects.count {
            updatePhysicsObject(&physicsObjects[i], deltaTime: clampedDeltaTime)
        }
        
        // Live2Dパラメータに反映
        applyPhysicsToParameters()
    }
    
    private func updatePhysicsObject(_ object: inout PhysicsObject, deltaTime: Float) {
        // 重力の適用
        let gravity = SIMD2<Float>(0, -gravityStrength * 9.8)
        
        // 風力の適用
        let windForce = calculateWindForce()
        
        // デバイスモーションの適用
        let motionForce = calculateMotionForce()
        
        // スプリング力の計算（復元力）
        let displacement = object.position - SIMD2<Float>(0, object.restLength)
        let springForce = -displacement * object.stiffness
        
        // 総合力の計算
        let totalForce = gravity + windForce + motionForce + springForce
        
        // ニュートンの運動方程式 F = ma
        object.acceleration = totalForce / object.mass
        
        // 速度の更新（ダンピングを適用）
        object.velocity = (object.velocity + object.acceleration * deltaTime) * object.damping
        
        // 位置の更新
        object.position += object.velocity * deltaTime
        
        // 位置の制限
        object.position.x = max(-1.0, min(1.0, object.position.x))
        object.position.y = max(-1.0, min(1.0, object.position.y))
    }
    
    private func calculateWindForce() -> SIMD2<Float> {
        let windRadians = windDirection * Float.pi / 180.0
        let windX = cos(windRadians) * windStrength
        let windY = sin(windRadians) * windStrength
        
        // 風の強さに変化を加える（自然な風の表現）
        let windVariation = sin(windPhase) * 0.3 + 0.7
        
        return SIMD2<Float>(windX, windY) * windVariation
    }
    
    private func calculateMotionForce() -> SIMD2<Float> {
        guard isDeviceMotionEnabled else { return SIMD2<Float>(0, 0) }
        
        // デバイスの加速度を物理力に変換
        let motionForceX = deviceAcceleration.x * 2.0
        let motionForceY = deviceAcceleration.y * 2.0
        
        return SIMD2<Float>(motionForceX, motionForceY)
    }
    
    private func updateWind() {
        windPhase += 0.1
        
        // 風向きの自然な変化
        if windStrength > 0 {
            let windDirectionVariation = sin(windPhase * 0.5) * 10.0 // ±10度の変化
            windDirection += windDirectionVariation * 0.1
            
            // 風向きを0-360度の範囲に保つ
            if windDirection < 0 {
                windDirection += 360
            } else if windDirection >= 360 {
                windDirection -= 360
            }
        }
    }
    
    private func applyPhysicsToParameters() {
        for object in physicsObjects {
            let parameterValue = object.position.x // X方向の位置をパラメータ値として使用
            parameterController?.setParameter(name: object.parameterName, value: parameterValue, smooth: false)
        }
    }
    
    // MARK: - Device Motion
    private func setupDeviceMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0/60.0
    }
    
    func enableDeviceMotion(_ enabled: Bool) {
        isDeviceMotionEnabled = enabled
        
        if enabled && motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] (data, error) in
                guard let data = data, error == nil else { return }
                
                self?.deviceAcceleration = SIMD3<Float>(
                    Float(data.userAcceleration.x),
                    Float(data.userAcceleration.y),
                    Float(data.userAcceleration.z)
                )
                
                self?.deviceRotation = SIMD3<Float>(
                    Float(data.attitude.roll),
                    Float(data.attitude.pitch),
                    Float(data.attitude.yaw)
                )
            }
        } else {
            motionManager.stopDeviceMotionUpdates()
            deviceAcceleration = SIMD3<Float>(0, 0, 0)
            deviceRotation = SIMD3<Float>(0, 0, 0)
        }
        
        print("Device motion \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Physics Control
    func setGravity(_ strength: Float) {
        gravityStrength = max(0.0, min(5.0, strength))
        print("Gravity strength set to: \(gravityStrength)")
    }
    
    func setWind(strength: Float, direction: Float) {
        windStrength = max(0.0, min(3.0, strength))
        windDirection = direction
        
        // 風向きを0-360度の範囲に正規化
        while windDirection < 0 {
            windDirection += 360
        }
        while windDirection >= 360 {
            windDirection -= 360
        }
        
        print("Wind set - Strength: \(windStrength), Direction: \(windDirection)°")
    }
    
    func setDamping(_ factor: Float) {
        dampingFactor = max(0.1, min(1.0, factor))
        
        // 全ての物理オブジェクトのダンピングを更新
        for i in 0..<physicsObjects.count {
            physicsObjects[i] = PhysicsObject(
                parameterName: physicsObjects[i].parameterName,
                mass: physicsObjects[i].mass,
                damping: dampingFactor,
                restLength: physicsObjects[i].restLength,
                stiffness: physicsObjects[i].stiffness
            )
        }
        
        print("Damping factor set to: \(dampingFactor)")
    }
    
    func enablePhysics(_ enabled: Bool) {
        isPhysicsEnabled = enabled
        
        if !enabled {
            resetPhysics()
        }
        
        print("Physics \(enabled ? "enabled" : "disabled")")
    }
    
    func resetPhysics() {
        for i in 0..<physicsObjects.count {
            physicsObjects[i].position = SIMD2<Float>(0, 0)
            physicsObjects[i].velocity = SIMD2<Float>(0, 0)
            physicsObjects[i].acceleration = SIMD2<Float>(0, 0)
        }
        
        // パラメータをリセット
        for object in physicsObjects {
            parameterController?.setParameter(name: object.parameterName, value: 0.0, smooth: false)
        }
        
        print("Physics reset")
    }
    
    // MARK: - Impulse and Forces
    func applyImpulse(direction: SIMD2<Float>, strength: Float) {
        let impulse = direction * strength
        
        for i in 0..<physicsObjects.count {
            physicsObjects[i].velocity += impulse / physicsObjects[i].mass
        }
        
        print("Applied impulse: \(impulse)")
    }
    
    func applyTouchImpulse(at point: CGPoint, viewSize: CGSize, strength: Float = 1.0) {
        // タッチ位置を-1.0〜1.0の範囲に正規化
        let normalizedX = Float((point.x / viewSize.width) * 2.0 - 1.0)
        let normalizedY = Float((point.y / viewSize.height) * 2.0 - 1.0)
        
        let touchDirection = SIMD2<Float>(normalizedX, -normalizedY)
        applyImpulse(direction: touchDirection, strength: strength)
    }
    
    func applyWindGust(duration: Float, strength: Float, direction: Float) {
        let originalWindStrength = windStrength
        let originalWindDirection = windDirection
        
        setWind(strength: strength, direction: direction)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(duration)) {
            self.setWind(strength: originalWindStrength, direction: originalWindDirection)
        }
        
        print("Applied wind gust: \(strength) for \(duration)s in direction \(direction)°")
    }
    
    // MARK: - Preset Effects
    func simulateHeadShake() {
        let shakeDirection = SIMD2<Float>(Float.random(in: -1...1), 0)
        applyImpulse(direction: shakeDirection, strength: 2.0)
    }
    
    func simulateJump() {
        let jumpDirection = SIMD2<Float>(0, 1)
        applyImpulse(direction: jumpDirection, strength: 3.0)
    }
    
    func simulateWalk() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !self.isPhysicsEnabled {
                timer.invalidate()
                return
            }
            
            let walkDirection = SIMD2<Float>(Float.random(in: -0.5...0.5), 0.2)
            self.applyImpulse(direction: walkDirection, strength: 0.5)
        }
    }
    
    func simulateBreeze() {
        let breezeStrength = Float.random(in: 0.2...0.8)
        let breezeDirection = Float.random(in: 0...360)
        
        applyWindGust(duration: Float.random(in: 2...5), strength: breezeStrength, direction: breezeDirection)
    }
    
    // MARK: - Event Handlers
    private func handlePhysicsUpdateRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let gravity = userInfo["gravity"] as? Float {
            setGravity(gravity)
        }
        
        if let wind = userInfo["wind"] as? Float {
            let direction = userInfo["direction"] as? Float ?? windDirection
            setWind(strength: wind, direction: direction)
        }
    }
    
    // MARK: - Debug and Monitoring
    func getPhysicsInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        info["isEnabled"] = isPhysicsEnabled
        info["gravity"] = gravityStrength
        info["windStrength"] = windStrength
        info["windDirection"] = windDirection
        info["damping"] = dampingFactor
        info["isDeviceMotionEnabled"] = isDeviceMotionEnabled
        
        var objectsInfo: [[String: Any]] = []
        for object in physicsObjects {
            objectsInfo.append([
                "parameter": object.parameterName,
                "position": [object.position.x, object.position.y],
                "velocity": [object.velocity.x, object.velocity.y],
                "mass": object.mass,
                "damping": object.damping
            ])
        }
        info["objects"] = objectsInfo
        
        if isDeviceMotionEnabled {
            info["deviceAcceleration"] = [deviceAcceleration.x, deviceAcceleration.y, deviceAcceleration.z]
            info["deviceRotation"] = [deviceRotation.x, deviceRotation.y, deviceRotation.z]
        }
        
        return info
    }
    
    func printPhysicsStatus() {
        let info = getPhysicsInfo()
        print("=== Live2D Physics Status ===")
        for (key, value) in info {
            print("\(key): \(value)")
        }
    }
    
    // MARK: - Cleanup
    deinit {
        physicsTimer?.invalidate()
        windTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
        
        print("Live2D Physics Controller deinitialized")
    }
}