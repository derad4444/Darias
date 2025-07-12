import SwiftUI
import UIKit

struct Live2DCharacterView: UIViewRepresentable {
    let modelName: String
    @Binding var isAnimationPlaying: Bool
    @StateObject private var viewModel: Live2DCharacterViewModel
    
    init(
        modelName: String,
        gender: CharacterGender = .female,
        isAnimationPlaying: Binding<Bool> = .constant(true)
    ) {
        self.modelName = modelName
        self._isAnimationPlaying = isAnimationPlaying
        self._viewModel = StateObject(wrappedValue: Live2DCharacterViewModel(gender: gender))
    }
    
    func makeUIView(context: Context) -> Live2DMetalView {
        print("🔍 Live2DCharacterView - makeUIView開始")
        
        let metalView = Live2DMetalView()
        print("🔍 Live2DCharacterView - Live2DMetalView作成完了")
        
        // 基本設定
        metalView.live2DDelegate = context.coordinator
        metalView.isAnimationPlaying = isAnimationPlaying
        print("🔍 Live2DCharacterView - 基本設定完了")
        
        // モデル読み込みを一度だけ実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔍 Live2DCharacterView - モデル読み込み開始: \(modelName)")
            
            // 既に同じモデルが読み込まれている場合はスキップ
            if metalView.modelName != modelName {
                metalView.loadModel(modelName: modelName)
                print("🔍 Live2DCharacterView - モデル読み込み呼び出し完了")
            } else {
                print("🔍 Live2DCharacterView - 既に同じモデルが読み込まれているためスキップ")
            }
        }
        
        print("🔍 Live2DCharacterView - makeUIView完了")
        return metalView
    }
    
    func updateUIView(_ uiView: Live2DMetalView, context: Context) {
        uiView.isAnimationPlaying = isAnimationPlaying
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, Live2DMetalViewDelegate {
        var parent: Live2DCharacterView
        private var live2DManager: Live2DManager?
        private var animationController: Live2DAnimationController?
        private var interactionController: Live2DInteractionController?
        private var parameterController: Live2DParameterController?
        private var physicsController: Live2DPhysicsController?
        
        init(_ parent: Live2DCharacterView) {
            self.parent = parent
            super.init()
            setupLive2DSystem()
            setupNotificationObservers()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            
            // メモリクリーンアップ
            live2DManager = nil
            animationController = nil
            interactionController = nil
            parameterController = nil
            physicsController = nil
            
            print("Live2D Coordinator cleaned up")
        }
        
        private func setupLive2DSystem() {
            // 段階的で安全な初期化
            print("Live2D システム初期化開始")
            
            // Step 1: Live2DManagerを初期化
            DispatchQueue.main.async {
                self.live2DManager = Live2DManager()
                print("Live2DManager初期化完了")
                
                // Step 2: 少し待ってからコントローラーを初期化
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeControllers()
                }
            }
        }
        
        private func initializeControllers() {
            guard let manager = self.live2DManager else { return }
            
            print("Live2D コントローラー初期化開始")
            
            // コントローラーを順次初期化
            DispatchQueue.global(qos: .utility).async {
                self.animationController = Live2DAnimationController(live2DManager: manager)
                print("AnimationController初期化完了")
                
                self.parameterController = Live2DParameterController(live2DManager: manager)
                print("ParameterController初期化完了")
                
                self.physicsController = Live2DPhysicsController(live2DManager: manager, parameterController: self.parameterController)
                print("PhysicsController初期化完了")
                
                self.interactionController = Live2DInteractionController(live2DManager: manager, animationController: self.animationController)
                print("InteractionController初期化完了")
                
                // モデルの読み込みは最後に実行
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    manager.loadModel(modelName: self.parent.modelName)
                    print("Live2D モデル読み込み開始: \(self.parent.modelName)")
                }
            }
        }
        
        private func setupNotificationObservers() {
            // NotificationObserverの設定を非同期で実行
            DispatchQueue.main.async {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleBlinkAnimation),
                    name: .live2DBlinkAnimation,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleTalkStart),
                    name: .live2DTalkStart,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleTalkStop),
                    name: .live2DTalkStop,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleExpressionChange),
                    name: .live2DExpressionChange,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleLookAt),
                    name: .live2DLookAt,
                    object: nil
                )
                
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.handleModelLoaded),
                    name: .live2DModelLoaded,
                    object: nil
                )
            }
        }
        
        @objc private func handleBlinkAnimation(_ notification: Notification) {
            parameterController?.playBlinkAnimation()
        }
        
        @objc private func handleTalkStart(_ notification: Notification) {
            // 口パクアニメーション開始
            if let volume = notification.userInfo?["volume"] as? Float {
                parameterController?.setParameter(name: "ParamMouthOpenY", value: volume)
            }
        }
        
        @objc private func handleTalkStop(_ notification: Notification) {
            // 口パクアニメーション停止
            parameterController?.setParameter(name: "ParamMouthOpenY", value: 0.0)
        }
        
        @objc private func handleExpressionChange(_ notification: Notification) {
            if let expression = notification.userInfo?["expression"] as? String {
                parameterController?.setExpression(name: expression)
            }
        }
        
        @objc private func handleLookAt(_ notification: Notification) {
            if let userInfo = notification.userInfo,
               let x = userInfo["x"] as? Float,
               let y = userInfo["y"] as? Float {
                interactionController?.setLookAtTarget(x: x, y: y)
            }
        }
        
        @objc private func handleModelLoaded(_ notification: Notification) {
            print("Live2D model loaded successfully")
        }
        
        // Live2D update methods
        func updateView() {
            // フレーム更新時の処理
            let deltaTime = 1.0 / 60.0
            animationController?.update(deltaTime: Float(deltaTime))
        }
        
        // MARK: - Live2DMetalViewDelegate
        func live2DMetalView(_ view: Live2DMetalView, didUpdateFrame frameTime: TimeInterval) {
            updateView()
        }
        
        func live2DMetalView(_ view: Live2DMetalView, didTouchAt point: CGPoint) {
            interactionController?.handleTouch(at: point, viewSize: view.bounds.size)
        }
    }
}

// MARK: - Live2D Interaction Methods
extension Live2DCharacterView {
    func playMotion(_ motionName: String, priority: Int = 1) {
        Live2DEventHelper.playMotion(motionName, priority: priority)
    }
    
    func setExpression(_ expressionName: String) {
        Live2DEventHelper.setExpression(expressionName)
    }
    
    func triggerBlink() {
        Live2DEventHelper.triggerBlink()
    }
    
    func updateLookAt(x: Float, y: Float) {
        Live2DEventHelper.updateLookAt(x: x, y: y)
    }
    
    func startTalk(volume: Float = 0.5) {
        Live2DEventHelper.startTalk(volume: volume)
    }
    
    func stopTalk() {
        Live2DEventHelper.stopTalk()
    }
    
    func handleTouch(at point: CGPoint, in viewSize: CGSize) {
        // Touch handling through interaction controller
        Live2DEventHelper.sendTouchEvent(
            x: Float(point.x / viewSize.width),
            y: Float(point.y / viewSize.height)
        )
    }
    
    func applyPhysicsImpulse(direction: SIMD2<Float>, strength: Float = 1.0) {
        Live2DEventHelper.updatePhysics(gravity: 1.0, wind: strength)
    }
}

// MARK: - Preview
struct Live2DCharacterView_Previews: PreviewProvider {
    static var previews: some View {
        Live2DCharacterView(
            modelName: "character_female",
            gender: .female,
            isAnimationPlaying: .constant(true)
        )
        .frame(width: 300, height: 400)
        .background(Color.gray.opacity(0.1))
    }
}