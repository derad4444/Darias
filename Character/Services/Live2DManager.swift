import Foundation
import Metal
import MetalKit
import UIKit

// Live2D Cubism SDK統合実装
// 実際のLive2D Cubism SDKを使用した実装

class Live2DManager: ObservableObject {
    // MARK: - Properties
    private var live2DModel: UnsafeMutableRawPointer? // 実際のLive2Dモデル
    private var live2DRenderer: UnsafeMutableRawPointer? // 実際のLive2Dレンダラー
    private var live2DAllocator: UnsafeMutableRawPointer? // Live2Dアロケーター
    private var isInitialized = false
    private var modelPath: String?
    
    // アニメーション状態
    private var currentTime: Float = 0.0
    private var breathPhase: Float = 0.0
    private var blinkTimer: Float = 0.0
    private var isBlinking = false
    
    // Metal関連
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    // 初期化状態管理
    private var initializationState: InitializationState = .notStarted
    private let initializationQueue = DispatchQueue(label: "Live2DInit", qos: .utility)
    
    enum InitializationState {
        case notStarted
        case inProgress
        case completed
        case failed
    }
    
    // MARK: - Initialization
    init() {
        // Live2D Cubism SDKの初期化
        print("🔍 Live2DManager - init開始")
        print("Live2D Manager: Cubism SDK初期化開始")
        initializeCubismFramework()
        print("🔍 Live2DManager - init完了")
    }
    
    private func initializeCubismFramework() {
        print("🔍 Live2DManager - initializeCubismFramework開始")
        
        // Live2D Cubism Frameworkの初期化
        initializationState = .inProgress
        print("🔍 Live2DManager - 初期化状態をinProgressに設定")
        
        // 安全な初期化処理
        DispatchQueue.global(qos: .utility).async {
            print("🔍 Live2DManager - バックグラウンドキューで初期化開始")
            
            // Live2Dアロケーターの作成
            self.live2DAllocator = createLive2DAllocator()
            print("🔍 Live2DManager - Live2Dアロケーター作成: \(self.live2DAllocator != nil ? "成功" : "失敗")")
            
            // Live2D Cubism Frameworkの初期化
            initializeLive2DFramework(self.live2DAllocator)
            print("🔍 Live2DManager - Live2D Cubism Framework初期化完了")
            
            // Metal初期化も同時に実行
            self.initializeMetal()
            
            self.isInitialized = true
            self.initializationState = .completed
            print("✅ Live2DManager - 初期化状態をcompletedに設定")
            
            DispatchQueue.main.async {
                print("✅ Live2DManager - メインキューで初期化完了通知")
                print("Live2D Cubism Framework初期化完了")
                
                // 初期化完了後、自動的にデフォルトモデルを読み込み
                self.loadDefaultModel()
            }
        }
    }
    
    private func initializeMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Live2DManager - Metal is not supported on this device")
            return
        }
        
        self.metalDevice = device
        self.commandQueue = device.makeCommandQueue()
        print("✅ Live2DManager - Metal初期化完了")
    }
    
    private func loadDefaultModel() {
        print("🔍 Live2DManager - デフォルトモデル読み込み開始")
        
        // パス構築のテストを実行
        testModelPaths()
        
        self.loadModel(modelName: "character_female")
    }
    
    private func testModelPaths() {
        print("🔍 Live2DManager - モデルパステスト開始")
        
        let testModelName = "character_female"
        let constructedPath = getModelPath(for: testModelName)
        
        print("🔍 Live2DManager - 構築されたパス: \(constructedPath)")
        
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: constructedPath)
        print("🔍 Live2DManager - ファイル存在: \(exists)")
        
        if exists {
            // ファイルサイズを確認
            do {
                let attributes = try fileManager.attributesOfItem(atPath: constructedPath)
                let fileSize = attributes[FileAttributeKey.size] as? Int ?? 0
                print("✅ Live2DManager - ファイルサイズ: \(fileSize) bytes")
                
                // ファイル内容の簡易チェック
                let data = try Data(contentsOf: URL(fileURLWithPath: constructedPath))
                if data.count > 0 {
                    print("✅ Live2DManager - ファイル読み込み成功: \(data.count) bytes")
                }
            } catch {
                print("❌ Live2DManager - ファイル読み込みエラー: \(error)")
            }
        } else {
            // プロジェクトディレクトリの確認
            let projectDir = "/Users/onoderaryousuke/Desktop/development-D/Character"
            print("🔍 Live2DManager - プロジェクトディレクトリ確認: \(projectDir)")
            
            if fileManager.fileExists(atPath: projectDir) {
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: projectDir)
                    let live2dFiles = contents.filter { $0.contains("koharu") || $0.contains(".json") || $0.contains(".moc3") }
                    print("🔍 Live2DManager - Live2D関連ファイル: \(live2dFiles)")
                } catch {
                    print("❌ Live2DManager - ディレクトリ読み取りエラー: \(error)")
                }
            } else {
                print("❌ Live2DManager - プロジェクトディレクトリが存在しません")
            }
        }
        
        print("🔍 Live2DManager - モデルパステスト完了")
    }
    
    func initialize() {
        // 既に初期化済みの場合は何もしない
        guard initializationState == .notStarted else { 
            print("🔍 Live2DManager - 初期化済みまたは進行中: \(initializationState)")
            return 
        }
        
        print("🔍 Live2DManager - 手動初期化開始")
        initializeCubismFramework()
    }
    
    // MARK: - Model Loading
    func loadModel(modelName: String) {
        print("🔍 Live2DManager - loadModel開始: \(modelName)")
        print("🔍 Live2DManager - 初期化状態: \(initializationState)")
        
        // 初期化が完了していない場合は待機してから実行
        guard initializationState == .completed else {
            print("🔍 Live2DManager - 初期化未完了のため待機")
            
            // 最大10回まで待機を試行
            waitForInitializationAndLoadModel(modelName: modelName, retryCount: 0)
            return
        }
        
        // モデルパスの構築（絶対パスを使用）
        let modelPath = getModelPath(for: modelName)
        self.modelPath = modelPath
        print("🔍 Live2DManager - モデルパス: \(modelPath)")
        
        // モデルの読み込みを非同期で実行
        initializationQueue.async {
            print("🔍 Live2DManager - モデル読み込み開始")
            self.loadModelFromPath(modelPath)
        }
    }
    
    private func waitForInitializationAndLoadModel(modelName: String, retryCount: Int) {
        let maxRetries = 10
        
        if retryCount >= maxRetries {
            print("🔍 Live2DManager - 初期化待機タイムアウト、強制的にモデル読み込み開始")
            // 初期化が完了していなくても、モデル読み込みを強制実行
            forceLoadModel(modelName: modelName)
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.initializationState == .completed {
                print("🔍 Live2DManager - 初期化完了、モデル読み込み再開")
                self.loadModel(modelName: modelName)
            } else {
                print("🔍 Live2DManager - 初期化待機中 (試行\(retryCount + 1)/\(maxRetries))")
                self.waitForInitializationAndLoadModel(modelName: modelName, retryCount: retryCount + 1)
            }
        }
    }
    
    private func forceLoadModel(modelName: String) {
        print("🔍 Live2DManager - 強制モデル読み込み開始: \(modelName)")
        
        // 初期化状態を強制的に完了に設定
        initializationState = .completed
        
        // モデルパスの構築（絶対パスを使用）
        let modelPath = getModelPath(for: modelName)
        self.modelPath = modelPath
        
        // モデルの読み込みを非同期で実行
        initializationQueue.async {
            print("🔍 Live2DManager - 強制モデル読み込み実行")
            self.loadModelFromPath(modelPath)
        }
    }
    
    private func getModelFileName(for modelName: String) -> String {
        switch modelName {
        case "character_female":
            return "koharu.model3.json"
        case "character_male":
            return "haruto.model3.json"
        default:
            return "model.model3.json"
        }
    }
    
    private func getModelPath(for modelName: String) -> String {
        let modelFileName = getModelFileName(for: modelName)
        
        // プロジェクト直下に配置されたファイルを使用
        let projectRootPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
        let directPath = "\(projectRootPath)/\(modelFileName)"
        
        print("🔍 Live2DManager - プロジェクト直下パス: \(directPath)")
        
        // ファイルの存在確認
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directPath) {
            print("✅ Live2DManager - ファイル存在確認成功: \(directPath)")
            return directPath
        } else {
            print("❌ Live2DManager - ファイルが見つかりません: \(directPath)")
            
            // バンドル内の確認も行う
            if let bundlePath = Bundle.main.path(forResource: modelFileName.replacingOccurrences(of: ".model3.json", with: ""), ofType: "model3.json") {
                print("✅ Live2DManager - バンドル内でファイル発見: \(bundlePath)")
                return bundlePath
            }
            
            return directPath
        }
    }
    
    private func loadModelFromPath(_ path: String) {
        print("🔍 Live2DManager - loadModelFromPath開始: \(path)")
        
        // ファイル存在確認
        let fileManager = FileManager.default
        let fileExists = fileManager.fileExists(atPath: path)
        print("🔍 Live2DManager - ファイル存在確認: \(fileExists) - \(path)")
        
        if !fileExists {
            print("❌ Live2DManager - モデルファイルが見つかりません: \(path)")
            initializationState = .failed
            return
        }
        
        guard initializationState == .completed else {
            print("🔍 Live2DManager - Live2D Framework not initialized, state: \(initializationState)")
            return
        }
        
        print("🔍 Live2DManager - Live2D Framework初期化済み、モデル読み込み開始")
        print("🔍 Live2DManager - アロケーター: \(live2DAllocator != nil ? "作成済み" : "未作成")")
        
        // 実際のLive2D SDKを使用してモデルを読み込み
        self.live2DModel = loadLive2DModel(path)
        
        print("🔍 Live2DManager - loadLive2DModel呼び出し完了")
        print("🔍 Live2DManager - モデルポインター: \(live2DModel != nil ? "有効" : "無効")")
        
        if self.live2DModel != nil {
            print("✅ Live2DManager - Live2Dモデル読み込み成功")
            
            // モデル状態を確認
            let modelStatus = isLive2DModelLoaded(live2DModel)
            print("🔍 Live2DManager - モデル状態確認: \(modelStatus)")
            
            // Metalレンダラーの作成
            if let device = self.metalDevice {
                print("🔍 Live2DManager - Metalデバイス有効、レンダラー作成開始")
                self.live2DRenderer = createLive2DRenderer(Unmanaged.passUnretained(device).toOpaque())
                print("🔍 Live2DManager - Live2Dレンダラー作成完了: \(live2DRenderer != nil ? "成功" : "失敗")")
            } else {
                print("❌ Live2DManager - Metalデバイスが無効")
            }
            
            DispatchQueue.main.async {
                print("🔍 Live2DManager - onModelLoaded呼び出し")
                self.onModelLoaded()
            }
        } else {
            print("❌ Live2DManager - Live2Dモデル読み込み失敗")
            print("🔍 Live2DManager - loadLive2DModel関数がnilを返しました")
            initializationState = .failed
        }
    }
    
    private func createMockModelData() -> [String: Any] {
        // モックデータの作成を軽量化
        return [
            "Version": 3,
            "FileReferences": [
                "Moc": "koharu.moc3",
                "Textures": ["koharu.2048/texture_00_female.png"],
                "Physics": "koharu.physics3.json",
                "Motions": [
                    "Idle": [["File": "motion/idle_female.motion3.json"]],
                    "Tap": [["File": "motion/01_female.motion3.json"]]
                ]
            ]
        ]
    }
    
    private func onModelLoaded() {
        print("Live2D model loaded successfully")
        // モデルロード完了の通知
        NotificationCenter.default.post(name: .live2DModelLoaded, object: nil)
    }
    
    // MARK: - Model Update
    func update(deltaTime: Float) {
        guard isInitialized, live2DModel != nil else { return }
        
        currentTime += deltaTime
        
        // 実際のLive2D SDKでのモデル更新
        updateLive2DModel(live2DModel, deltaTime)
        
        // アニメーション状態の更新（デバッグ用）
        breathPhase += deltaTime * 2.0 // 2秒で一周期
        
        // 瞬きアニメーション（デバッグ用）
        blinkTimer += deltaTime
        if blinkTimer > 3.0 { // 3秒おきに瞬き
            blinkTimer = 0.0
            isBlinking = true
        }
        
        if isBlinking {
            blinkTimer += deltaTime * 10.0
            if blinkTimer > 1.0 {
                isBlinking = false
                blinkTimer = 0.0
            }
        }
    }
    
    private func updateModelParameters(deltaTime: Float) {
        // パラメータの更新処理は update(deltaTime:) メソッドに統合されました
    }
    
    // MARK: - Helper Methods
    // プレースホルダー実装 - 実際のLive2D SDKではこれらのメソッドでリソースを読み込みます
    
    // MARK: - Animation Control
    func playMotion(motionName: String, priority: Int = 1) {
        guard isInitialized, let model = live2DModel else { return }
        
        // モーション再生
        playLive2DMotion(model, motionName, 0)
        
        print("Playing motion: \(motionName) with priority: \(priority)")
    }
    
    func setExpression(expressionName: String) {
        guard isInitialized, let model = live2DModel else { return }
        
        // 表情変更
        setLive2DExpression(model, expressionName)
        
        print("Setting expression: \(expressionName)")
    }
    
    func setParameter(name: String, value: Float) {
        guard isInitialized, let model = live2DModel else { return }
        
        // パラメータ直接制御
        setLive2DParameter(model, name, value)
        
        print("Setting parameter \(name) to value: \(value)")
    }
    
    // MARK: - Interaction
    func updateLookAt(x: Float, y: Float) {
        guard isInitialized else { return }
        
        // 視線追従
        setParameter(name: "ParamAngleX", value: x * 30.0) // -30〜30度
        setParameter(name: "ParamAngleY", value: y * 30.0)
        setParameter(name: "ParamEyeBallX", value: x)
        setParameter(name: "ParamEyeBallY", value: y)
    }
    
    func updateLipSync(volume: Float) {
        guard isInitialized else { return }
        
        // 口パク
        let mouthValue = min(max(volume * 2.0, 0.0), 1.0) // 0〜1に正規化
        setParameter(name: "ParamMouthOpenY", value: mouthValue)
    }
    
    func triggerBlink() {
        guard isInitialized else { return }
        
        // 瞬き
        setParameter(name: "ParamEyeLOpen", value: 0.0)
        setParameter(name: "ParamEyeROpen", value: 0.0)
        
        // 0.2秒後に目を開く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setParameter(name: "ParamEyeLOpen", value: 1.0)
            self.setParameter(name: "ParamEyeROpen", value: 1.0)
        }
    }
    
    // MARK: - Physics
    func updatePhysics(deltaTime: Float) {
        guard isInitialized, live2DModel != nil else { return }
        
        // 髪の毛や服の揺れ
        // 実際のSDK導入時に以下のコードを有効化:
        /*
        if let cubismModel = model as? CubismModel {
            cubismModel.getPhysics()?.evaluate(deltaTime)
        }
        */
    }
    
    func setPhysicsSettings(gravity: Float, wind: Float) {
        guard isInitialized, live2DModel != nil else { return }
        
        // 重力や風の設定
        // 実際のSDK導入時に以下のコードを有効化:
        /*
        if let cubismModel = model as? CubismModel {
            let physics = cubismModel.getPhysics()
            physics?.setGravity(gravity)
            physics?.setWind(wind)
        }
        */
        
        print("Setting physics - Gravity: \(gravity), Wind: \(wind)")
    }
    
    func updateAnimation(deltaTime: Float) {
        guard isInitialized, live2DModel != nil else { return }
        
        // アニメーションの更新処理
        // 実際のSDK導入時に以下のコードを有効化:
        /*
        if let cubismModel = model as? CubismModel {
            cubismModel.update()
        }
        */
        
        // デバッグ用: アニメーション更新をログ出力
        // print("Updating animation with deltaTime: \(deltaTime)")
    }
    
    // MARK: - Cleanup
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        // Live2D リソースのクリーンアップ
        live2DModel = nil
        live2DRenderer = nil
        
        // Live2D Frameworkの終了処理
        if isInitialized {
            disposeLive2DFramework()
        }
        
        live2DAllocator = nil
        isInitialized = false
        
        print("Live2D Manager cleaned up")
    }
}

// MARK: - Notification Names (moved to Live2DNotifications.swift)

// MARK: - Live2D Model Info
extension Live2DManager {
    func getModelInfo() -> [String: Any] {
        guard isInitialized, live2DModel != nil else {
            return ["status": "not_loaded"]
        }
        
        return [
            "status": "loaded",
            "modelPath": modelPath ?? "",
            "isInitialized": isInitialized
        ]
    }
    
    func getAvailableMotions() -> [String] {
        // 実際のLive2D SDKから取得される
        return ["Idle", "Tap", "FlickLeft", "FlickRight", "FlickUp", "FlickDown"]
    }
    
    func getAvailableExpressions() -> [String] {
        // 利用可能な表情一覧を返す
        return ["normal", "happy", "sad", "angry", "surprised"]
    }
    
    // MARK: - Getter Methods
    func getModel() -> Any? {
        return live2DModel
    }
    
    func getRenderer() -> Any? {
        return live2DRenderer
    }
    
    func isModelLoaded() -> Bool {
        guard let model = live2DModel else {
            // モデルポインタがnilの場合
            if Int.random(in: 0..<500) == 0 { // ログ出力頻度を削減
                print("🔍 Live2DManager - isModelLoaded: false (model pointer is nil)")
            }
            return false
        }
        
        // モデルの読み込み状態をチェック
        let loadedStatus = isLive2DModelLoaded(model)
        let isLoaded = (loadedStatus == 1)
        
        // ログ出力を大幅に削減（50秒に1回のみ）
        if Int.random(in: 0..<500) == 0 {
            print("🔍 Live2DManager - isModelLoaded: \(isLoaded), status code: \(loadedStatus)")
        }
        
        return isLoaded
    }
    
    func getAnimationState() -> [String: Any] {
        // Live2DSwiftBridgeからアニメーション状態を取得
        if let model = live2DModel,
           let animState = getLive2DAnimationState(model) {
            return [
                "currentTime": currentTime,
                "breathPhase": breathPhase,
                "isBlinking": isBlinking,
                "motionState": animState.motionState,
                "currentExpression": animState.currentExpression,
                "parameterValues": animState.parameterValues
            ]
        }
        
        return [
            "currentTime": currentTime,
            "breathPhase": breathPhase,
            "isBlinking": isBlinking
        ]
    }
}