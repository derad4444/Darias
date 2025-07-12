import Foundation
import UIKit
import Combine

// MARK: - Live2D Interaction Controller
class Live2DInteractionController: ObservableObject {
    // MARK: - Properties
    @Published var isLookAtEnabled: Bool = true
    @Published var isTouchEnabled: Bool = true
    @Published var isDragEnabled: Bool = true
    @Published var lookAtSensitivity: Float = 1.0
    @Published var touchSensitivity: Float = 1.0
    
    var live2DManager: Live2DManager?
    var animationController: Live2DAnimationController?
    private var cancellables = Set<AnyCancellable>()
    
    // Look At tracking
    private var currentLookX: Float = 0.0
    private var currentLookY: Float = 0.0
    private var targetLookX: Float = 0.0
    private var targetLookY: Float = 0.0
    private var lookAtTimer: Timer?
    
    // Touch tracking
    private var lastTouchTime: Date = Date()
    private var touchCount: Int = 0
    private var lastTouchLocation: CGPoint = .zero
    
    // Drag tracking
    private var isDragging: Bool = false
    private var dragStartLocation: CGPoint = .zero
    private var dragCurrentLocation: CGPoint = .zero
    
    // Hit Areas (Live2Dモデルの当たり判定領域)
    private var hitAreas: [HitArea] = []
    
    struct HitArea {
        let name: String
        let rect: CGRect
        let reaction: String
        let priority: Int
        
        init(name: String, rect: CGRect, reaction: String, priority: Int = 1) {
            self.name = name
            self.rect = rect
            self.reaction = reaction
            self.priority = priority
        }
    }
    
    // MARK: - Initialization
    init(live2DManager: Live2DManager? = nil, animationController: Live2DAnimationController? = nil) {
        self.live2DManager = live2DManager
        self.animationController = animationController
        setupNotificationObservers()
        setupHitAreas()
        startLookAtTracking()
    }
    
    private func setupNotificationObservers() {
        // タッチイベントの監視
        NotificationCenter.default.addObserver(
            forName: .live2DTouchEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTouchEvent(notification)
        }
        
        // ドラッグイベントの監視
        NotificationCenter.default.addObserver(
            forName: .live2DDragEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDragEvent(notification)
        }
        
        // 視線追従イベントの監視
        NotificationCenter.default.addObserver(
            forName: .live2DLookAt,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleLookAtEvent(notification)
        }
    }
    
    private func setupHitAreas() {
        // Live2Dモデルの当たり判定領域を設定
        hitAreas = [
            HitArea(name: "head", rect: CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.4), reaction: "head_touch", priority: 3),
            HitArea(name: "face", rect: CGRect(x: 0.25, y: 0.15, width: 0.5, height: 0.3), reaction: "face_touch", priority: 4),
            HitArea(name: "body", rect: CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.5), reaction: "body_touch", priority: 2),
            HitArea(name: "left_hand", rect: CGRect(x: 0.1, y: 0.6, width: 0.2, height: 0.2), reaction: "hand_touch", priority: 2),
            HitArea(name: "right_hand", rect: CGRect(x: 0.7, y: 0.6, width: 0.2, height: 0.2), reaction: "hand_touch", priority: 2)
        ]
    }
    
    // MARK: - Look At Control
    private func startLookAtTracking() {
        lookAtTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateLookAt()
        }
    }
    
    private func updateLookAt() {
        guard isLookAtEnabled else { return }
        
        // スムーズな視線移動のための線形補間
        let smoothness: Float = 0.1
        currentLookX += (targetLookX - currentLookX) * smoothness
        currentLookY += (targetLookY - currentLookY) * smoothness
        
        // Live2Dに視線位置を送信
        live2DManager?.updateLookAt(x: currentLookX, y: currentLookY)
    }
    
    func setLookAtTarget(x: Float, y: Float, smooth: Bool = true) {
        guard isLookAtEnabled else { return }
        
        let sensitivity = lookAtSensitivity
        targetLookX = x * sensitivity
        targetLookY = y * sensitivity
        
        if !smooth {
            currentLookX = targetLookX
            currentLookY = targetLookY
        }
        
        print("Look at target set: (\(targetLookX), \(targetLookY))")
    }
    
    func setLookAtTarget(point: CGPoint, viewSize: CGSize) {
        // スクリーン座標を-1.0〜1.0の範囲に正規化
        let normalizedX = Float((point.x / viewSize.width) * 2.0 - 1.0)
        let normalizedY = Float((point.y / viewSize.height) * 2.0 - 1.0)
        
        setLookAtTarget(x: normalizedX, y: -normalizedY) // Y軸を反転
    }
    
    private func handleLookAtEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let x = userInfo["x"] as? Float,
              let y = userInfo["y"] as? Float else { return }
        
        let smooth = userInfo["smooth"] as? Bool ?? true
        setLookAtTarget(x: x, y: y, smooth: smooth)
    }
    
    // MARK: - Touch Interaction
    func handleTouch(at point: CGPoint, viewSize: CGSize) {
        guard isTouchEnabled else { return }
        
        lastTouchLocation = point
        lastTouchTime = Date()
        touchCount += 1
        
        // 正規化座標に変換
        let normalizedPoint = CGPoint(
            x: point.x / viewSize.width,
            y: point.y / viewSize.height
        )
        
        // 当たり判定チェック
        if let hitArea = getHitArea(at: normalizedPoint) {
            handleHitAreaTouch(hitArea, at: normalizedPoint)
        } else {
            handleGenericTouch(at: normalizedPoint)
        }
        
        // 視線をタッチ位置に向ける
        setLookAtTarget(point: point, viewSize: viewSize)
        
        print("Touch detected at: \(point), normalized: \(normalizedPoint)")
    }
    
    private func getHitArea(at point: CGPoint) -> HitArea? {
        // 優先度の高い当たり判定から順にチェック
        let sortedHitAreas = hitAreas.sorted { $0.priority > $1.priority }
        
        for hitArea in sortedHitAreas {
            if hitArea.rect.contains(point) {
                return hitArea
            }
        }
        
        return nil
    }
    
    private func handleHitAreaTouch(_ hitArea: HitArea, at point: CGPoint) {
        print("Hit area touched: \(hitArea.name)")
        
        // 当たり判定に応じたリアクション
        switch hitArea.reaction {
        case "head_touch":
            triggerHeadTouchReaction()
        case "face_touch":
            triggerFaceTouchReaction()
        case "body_touch":
            triggerBodyTouchReaction()
        case "hand_touch":
            triggerHandTouchReaction()
        default:
            triggerGenericTouchReaction()
        }
        
        // タッチイベントを通知
        Live2DEventHelper.sendTouchEvent(x: Float(point.x), y: Float(point.y), pressure: 1.0)
    }
    
    private func handleGenericTouch(at point: CGPoint) {
        triggerGenericTouchReaction()
        
        // タッチイベントを通知
        Live2DEventHelper.sendTouchEvent(x: Float(point.x), y: Float(point.y), pressure: 1.0)
    }
    
    private func handleTouchEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let x = userInfo["x"] as? Float,
              let y = userInfo["y"] as? Float else { return }
        
        let pressure = userInfo["pressure"] as? Float ?? 1.0
        
        // 追加のタッチ処理
        processTouchFeedback(x: x, y: y, pressure: pressure)
    }
    
    // MARK: - Touch Reactions
    private func triggerHeadTouchReaction() {
        let headReactions = ["01_female", "happy_reaction"]
        let reaction = headReactions.randomElement() ?? "01_female"
        
        animationController?.setExpression("happy")
        animationController?.playMotion(reaction, priority: 3)
    }
    
    private func triggerFaceTouchReaction() {
        let faceReactions = ["02_female", "shy_reaction"]
        let reaction = faceReactions.randomElement() ?? "02_female"
        
        animationController?.setExpression("surprised")
        animationController?.playMotion(reaction, priority: 3)
    }
    
    private func triggerBodyTouchReaction() {
        let bodyReactions = ["03_female", "tickle_reaction"]
        let reaction = bodyReactions.randomElement() ?? "03_female"
        
        animationController?.setExpression("confused")
        animationController?.playMotion(reaction, priority: 2)
    }
    
    private func triggerHandTouchReaction() {
        let handReactions = ["04_female", "wave_reaction"]
        let reaction = handReactions.randomElement() ?? "04_female"
        
        animationController?.setExpression("happy")
        animationController?.playMotion(reaction, priority: 2)
    }
    
    private func triggerGenericTouchReaction() {
        let genericReactions = ["05_female", "06_female", "07_female"]
        let reaction = genericReactions.randomElement() ?? "05_female"
        
        animationController?.playMotion(reaction, priority: 1)
    }
    
    // MARK: - Drag Interaction
    func handleDragStart(at point: CGPoint, viewSize: CGSize) {
        guard isDragEnabled else { return }
        
        isDragging = true
        dragStartLocation = point
        dragCurrentLocation = point
        
        // ドラッグ開始時の視線設定
        setLookAtTarget(point: point, viewSize: viewSize)
        
        print("Drag started at: \(point)")
    }
    
    func handleDragUpdate(to point: CGPoint, viewSize: CGSize) {
        guard isDragEnabled, isDragging else { return }
        
        dragCurrentLocation = point
        
        // ドラッグ中の視線追従
        setLookAtTarget(point: point, viewSize: viewSize)
        
        // ドラッグの方向と距離を計算
        let dragVector = CGPoint(
            x: point.x - dragStartLocation.x,
            y: point.y - dragStartLocation.y
        )
        
        let dragDistance = sqrt(dragVector.x * dragVector.x + dragVector.y * dragVector.y)
        
        // 一定距離以上ドラッグした場合のリアクション
        if dragDistance > 50.0 {
            handleDragReaction(vector: dragVector, distance: dragDistance)
        }
    }
    
    func handleDragEnd(at point: CGPoint, viewSize: CGSize) {
        guard isDragEnabled, isDragging else { return }
        
        isDragging = false
        
        let dragVector = CGPoint(
            x: point.x - dragStartLocation.x,
            y: point.y - dragStartLocation.y
        )
        
        // ドラッグイベントを通知
        Live2DEventHelper.sendDragEvent(
            startX: Float(dragStartLocation.x / viewSize.width),
            startY: Float(dragStartLocation.y / viewSize.height),
            endX: Float(point.x / viewSize.width),
            endY: Float(point.y / viewSize.height)
        )
        
        print("Drag ended at: \(point), vector: \(dragVector)")
    }
    
    private func handleDragEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let startX = userInfo["startX"] as? Float,
              let startY = userInfo["startY"] as? Float,
              let endX = userInfo["endX"] as? Float,
              let endY = userInfo["endY"] as? Float else { return }
        
        // ドラッグ方向の判定とリアクション
        let deltaX = endX - startX
        let deltaY = endY - startY
        
        if abs(deltaX) > abs(deltaY) {
            // 水平方向のドラッグ
            if deltaX > 0 {
                triggerRightFlickReaction()
            } else {
                triggerLeftFlickReaction()
            }
        } else {
            // 垂直方向のドラッグ
            if deltaY > 0 {
                triggerDownFlickReaction()
            } else {
                triggerUpFlickReaction()
            }
        }
    }
    
    private func handleDragReaction(vector: CGPoint, distance: CGFloat) {
        // ドラッグの方向に応じたリアクション
        if abs(vector.x) > abs(vector.y) {
            // 水平方向
            if vector.x > 0 {
                triggerRightFlickReaction()
            } else {
                triggerLeftFlickReaction()
            }
        } else {
            // 垂直方向
            if vector.y > 0 {
                triggerDownFlickReaction()
            } else {
                triggerUpFlickReaction()
            }
        }
    }
    
    // MARK: - Flick Reactions
    private func triggerLeftFlickReaction() {
        animationController?.playMotion("08_female", priority: 2) // Left flick motion
        print("Left flick reaction triggered")
    }
    
    private func triggerRightFlickReaction() {
        animationController?.playMotion("09_female", priority: 2) // Right flick motion
        print("Right flick reaction triggered")
    }
    
    private func triggerUpFlickReaction() {
        animationController?.playMotion("07_female", priority: 2) // Up flick motion
        print("Up flick reaction triggered")
    }
    
    private func triggerDownFlickReaction() {
        animationController?.playMotion("06_female", priority: 2) // Down flick motion
        print("Down flick reaction triggered")
    }
    
    // MARK: - Utility Methods
    private func processTouchFeedback(x: Float, y: Float, pressure: Float) {
        // タッチの強度に応じたフィードバック
        if pressure > 0.8 {
            // 強いタッチ
            triggerStrongTouchReaction()
        } else if pressure < 0.3 {
            // 軽いタッチ
            triggerLightTouchReaction()
        }
    }
    
    private func triggerStrongTouchReaction() {
        animationController?.setExpression("surprised")
        print("Strong touch reaction")
    }
    
    private func triggerLightTouchReaction() {
        animationController?.setExpression("happy")
        print("Light touch reaction")
    }
    
    // MARK: - Settings
    func setLookAtSensitivity(_ sensitivity: Float) {
        lookAtSensitivity = max(0.1, min(2.0, sensitivity))
        print("Look at sensitivity set to: \(lookAtSensitivity)")
    }
    
    func setTouchSensitivity(_ sensitivity: Float) {
        touchSensitivity = max(0.1, min(2.0, sensitivity))
        print("Touch sensitivity set to: \(touchSensitivity)")
    }
    
    func enableLookAt(_ enabled: Bool) {
        isLookAtEnabled = enabled
        if !enabled {
            // 中央位置にリセット
            setLookAtTarget(x: 0.0, y: 0.0, smooth: true)
        }
        print("Look at \(enabled ? "enabled" : "disabled")")
    }
    
    func enableTouch(_ enabled: Bool) {
        isTouchEnabled = enabled
        print("Touch \(enabled ? "enabled" : "disabled")")
    }
    
    func enableDrag(_ enabled: Bool) {
        isDragEnabled = enabled
        print("Drag \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Cleanup
    deinit {
        lookAtTimer?.invalidate()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
        
        print("Live2D Interaction Controller deinitialized")
    }
}