//
//  Live2DSwiftBridge.swift
//  Character
//
//  Live2D Cubism SDK Swift Bridge (temporary implementation)
//

import Foundation
import Metal
import MetalKit
import UIKit

// Live2D Model Data Structure
struct Live2DModelData {
    let modelPath: String
    let textures: [MTLTexture]
    let mocData: Data?
    let physicsData: Data?
    let motions: [String: [String]]
    let isLoaded: Bool
}

// Actual Live2D implementation using Metal textures
// 実際のLive2Dモデルファイルとテクスチャを使用した実装

func createLive2DAllocator() -> UnsafeMutableRawPointer? {
    print("🔍 Live2DSwiftBridge - createLive2DAllocator (temporary implementation)")
    // 一時的な実装: メモリアロケーターのプレースホルダー
    let allocator = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    allocator.pointee = 1 // アロケーターが作成されたことを示すマーカー
    return UnsafeMutableRawPointer(allocator)
}

func initializeLive2DFramework(_ allocator: UnsafeMutableRawPointer?) {
    print("🔍 Live2DSwiftBridge - initializeLive2DFramework (temporary implementation)")
    // 一時的な実装: フレームワーク初期化のプレースホルダー
    // 実際のSDKでは、Live2D Cubism Frameworkの初期化を行います
}

func disposeLive2DFramework() {
    print("🔍 Live2DSwiftBridge - disposeLive2DFramework (temporary implementation)")
    // 一時的な実装: フレームワーク終了処理のプレースホルダー
    // 実際のSDKでは、Live2D Cubism Frameworkの終了処理を行います
}

func loadLive2DModel(_ modelPath: String) -> UnsafeMutableRawPointer? {
    print("🔍 Live2DSwiftBridge - loadLive2DModel開始: \(modelPath)")
    
    // ファイルの存在チェック
    let fileManager = FileManager.default
    print("🔍 Live2DSwiftBridge - ファイル存在チェック実行中...")
    
    if fileManager.fileExists(atPath: modelPath) {
        print("✅ Live2DSwiftBridge - モデルファイルが見つかりました: \(modelPath)")
        
        // ファイルサイズをチェック
        do {
            let attributes = try fileManager.attributesOfItem(atPath: modelPath)
            let fileSize = attributes[FileAttributeKey.size] as? Int ?? 0
            print("🔍 Live2DSwiftBridge - ファイルサイズ: \(fileSize) bytes")
            
            if fileSize > 0 {
                print("🔍 Live2DSwiftBridge - ファイルサイズ有効、モデル作成開始")
                
                // モデルJSONファイルを解析して必要なファイルを確認
                let result = validateModelFiles(modelPath: modelPath)
                
                if result.isValid {
                    print("✅ Live2DSwiftBridge - モデルファイル検証成功")
                    
                    // 実際のモデルデータを読み込み
                    if let modelData = loadActualLive2DModelData(modelPath: modelPath) {
                        print("✅ Live2DSwiftBridge - 実際のモデルデータ読み込み成功")
                        let model = UnsafeMutablePointer<Live2DModelData>.allocate(capacity: 1)
                        model.pointee = modelData
                        
                        print("✅ Live2DSwiftBridge - Live2Dモデルデータポインタ作成成功")
                        print("🔍 Live2DSwiftBridge - テクスチャ数: \(modelData.textures.count)")
                        
                        return UnsafeMutableRawPointer(model)
                    } else {
                        print("❌ Live2DSwiftBridge - 実際のモデルデータ読み込み失敗")
                        return nil
                    }
                } else {
                    print("❌ Live2DSwiftBridge - モデルファイル検証失敗: \(result.missingFiles)")
                    return nil
                }
            } else {
                print("❌ Live2DSwiftBridge - ファイルサイズが0です")
                return nil
            }
        } catch {
            print("❌ Live2DSwiftBridge - ファイル属性取得エラー: \(error)")
            return nil
        }
    } else {
        print("❌ Live2DSwiftBridge - モデルファイルが見つかりません: \(modelPath)")
        
        // ディレクトリの内容をチェック
        let parentDir = (modelPath as NSString).deletingLastPathComponent
        print("🔍 Live2DSwiftBridge - 親ディレクトリチェック: \(parentDir)")
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: parentDir)
            print("🔍 Live2DSwiftBridge - ディレクトリ内容: \(contents)")
        } catch {
            print("❌ Live2DSwiftBridge - ディレクトリ読み取りエラー: \(error)")
        }
        
        return nil
    }
}

// モデルファイルの検証結果
struct ModelValidationResult {
    let isValid: Bool
    let missingFiles: [String]
}

// モデルファイルとその依存ファイルを検証
func validateModelFiles(modelPath: String) -> ModelValidationResult {
    print("🔍 Live2DSwiftBridge - モデルファイル検証開始")
    
    let fileManager = FileManager.default
    let modelDir = (modelPath as NSString).deletingLastPathComponent
    var missingFiles: [String] = []
    
    do {
        // model3.jsonファイルを読み込み
        let data = try Data(contentsOf: URL(fileURLWithPath: modelPath))
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        
        if let fileReferences = json?["FileReferences"] as? [String: Any] {
            // .moc3ファイルをチェック
            if let mocFile = fileReferences["Moc"] as? String {
                let mocPath = "\(modelDir)/\(mocFile)"
                if !fileManager.fileExists(atPath: mocPath) {
                    missingFiles.append(mocFile)
                } else {
                    print("✅ Live2DSwiftBridge - .moc3ファイル確認: \(mocFile)")
                }
            }
            
            // テクスチャファイルをチェック
            if let textures = fileReferences["Textures"] as? [String] {
                for texture in textures {
                    let texturePath = "\(modelDir)/\(texture)"
                    if !fileManager.fileExists(atPath: texturePath) {
                        missingFiles.append(texture)
                        print("❌ Live2DSwiftBridge - テクスチャファイルが見つかりません: \(texture)")
                        print("🔍 Live2DSwiftBridge - 検索パス: \(texturePath)")
                    } else {
                        // ファイルサイズも確認
                        do {
                            let attributes = try fileManager.attributesOfItem(atPath: texturePath)
                            let fileSize = attributes[FileAttributeKey.size] as? Int ?? 0
                            print("✅ Live2DSwiftBridge - テクスチャファイル確認: \(texture) (サイズ: \(fileSize) bytes)")
                        } catch {
                            print("⚠️ Live2DSwiftBridge - テクスチャファイル属性エラー: \(texture) - \(error)")
                        }
                    }
                }
            }
            
            // 物理ファイルをチェック（オプション）
            if let physicsFile = fileReferences["Physics"] as? String {
                let physicsPath = "\(modelDir)/\(physicsFile)"
                if !fileManager.fileExists(atPath: physicsPath) {
                    print("⚠️ Live2DSwiftBridge - 物理ファイルが見つかりません（オプション）: \(physicsFile)")
                } else {
                    print("✅ Live2DSwiftBridge - 物理ファイル確認: \(physicsFile)")
                }
            }
        }
        
        print("🔍 Live2DSwiftBridge - モデルファイル検証完了")
        return ModelValidationResult(isValid: missingFiles.isEmpty, missingFiles: missingFiles)
        
    } catch {
        print("❌ Live2DSwiftBridge - JSONパースエラー: \(error)")
        return ModelValidationResult(isValid: false, missingFiles: ["JSON parse error"])
    }
}

func createLive2DRenderer(_ device: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("🔍 Live2DSwiftBridge - createLive2DRenderer (temporary implementation)")
    
    // 一時的な実装: レンダラー作成のプレースホルダー
    // 実際のSDKでは、Metal用のLive2Dレンダラーを作成します
    
    if device != nil {
        let renderer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        renderer.pointee = 3 // レンダラーが作成されたことを示すマーカー
        return UnsafeMutableRawPointer(renderer)
    } else {
        return nil
    }
}


func renderLive2DModel(_ renderer: UnsafeMutableRawPointer?, _ model: UnsafeMutableRawPointer?) {
    // Live2Dモデルの描画処理
    
    if renderer != nil && model != nil {
        // デバッグログを適度に減らす
        let randomValue = Int.random(in: 0..<300)
        if randomValue == 0 {
            print("🔍 Live2DSwiftBridge - renderLive2DModel実行中")
            print("🔍 Live2DSwiftBridge - renderer: \(renderer != nil ? "有効" : "無効")")
            print("🔍 Live2DSwiftBridge - model: \(model != nil ? "有効" : "無効")")
        }
        
        // 実際のLive2D描画はMetalシェーダーで行われる
        // ここでは描画フラグのみ設定
    } else {
        // デバッグログを適度に減らす
        let randomValue = Int.random(in: 0..<300)
        if randomValue == 0 {
            print("⚠️ Live2DSwiftBridge - renderLive2DModel: renderer または model が nil")
        }
    }
}


func isLive2DModelLoaded(_ model: UnsafeMutableRawPointer?) -> Int32 {
    // モデル読み込み状態チェック
    
    guard let model = model else {
        // デバッグ情報を適度に出力
        if Int.random(in: 0..<300) == 0 { // 約1/300の確率でログ出力
            print("🔍 Live2DSwiftBridge - isLive2DModelLoaded: モデルポインタがnil")
        }
        return 0
    }
    
    // Live2DModelDataの場合の処理
    let modelDataPointer = model.bindMemory(to: Live2DModelData.self, capacity: 1)
    let modelData = modelDataPointer.pointee
    let isLoaded = modelData.isLoaded && !modelData.textures.isEmpty
    
    // デバッグ情報を適度に出力
    if Int.random(in: 0..<100) == 0 { // 約1/100の確率でログ出力（より頻繁に）
        print("🔍 Live2DSwiftBridge - isLive2DModelLoaded: テクスチャ数=\(modelData.textures.count), 読み込み状態=\(isLoaded)")
    }
    
    return isLoaded ? 1 : 0
}

// MARK: - Enhanced Animation System

class Live2DAnimationState {
    var breathPhase: Float = 0.0
    var blinkTimer: Float = 0.0
    var isBlinking: Bool = false
    var currentExpression: String = "normal"
    var parameterValues: [String: Float] = [:]
    var motionState: String = "Idle"
    var motionTimer: Float = 0.0
    
    init() {
        // 基本パラメータの初期化
        parameterValues["ParamAngleX"] = 0.0
        parameterValues["ParamAngleY"] = 0.0
        parameterValues["ParamAngleZ"] = 0.0
        parameterValues["ParamEyeLOpen"] = 1.0
        parameterValues["ParamEyeROpen"] = 1.0
        parameterValues["ParamMouthOpenY"] = 0.0
        parameterValues["ParamBreath"] = 0.0
    }
}

// グローバルアニメーション状態管理
private var animationStates: [UnsafeMutableRawPointer: Live2DAnimationState] = [:]

// MARK: - Enhanced Animation Functions

func updateLive2DModel(_ model: UnsafeMutableRawPointer?, _ deltaTime: Float) {
    guard let model = model else { return }
    
    // アニメーション状態の取得または作成
    if animationStates[model] == nil {
        animationStates[model] = Live2DAnimationState()
        print("✅ Live2DSwiftBridge - 新しいアニメーション状態を作成")
    }
    
    guard let animState = animationStates[model] else { return }
    
    // 呼吸アニメーション
    animState.breathPhase += deltaTime * 2.0
    let breathValue = sin(animState.breathPhase) * 0.5 + 0.5
    animState.parameterValues["ParamBreath"] = breathValue * 0.3
    
    // 体の微細な動き（基本の待機アニメーション）
    let baseAngleX = sin(animState.breathPhase * 0.8) * 2.0
    let baseAngleY = cos(animState.breathPhase * 0.6) * 1.5
    let baseAngleZ = sin(animState.breathPhase * 0.4) * 1.0
    
    // 他のアニメーションがない場合のみ基本動作を適用
    if animState.motionState == "Idle" {
        animState.parameterValues["ParamAngleX"] = baseAngleX
        animState.parameterValues["ParamAngleY"] = baseAngleY
        animState.parameterValues["ParamAngleZ"] = baseAngleZ
    }
    
    // 瞬きアニメーション
    animState.blinkTimer += deltaTime
    if animState.blinkTimer > 3.0 + Float.random(in: 0...2.0) { // 3-5秒間隔でランダム
        animState.blinkTimer = 0.0
        animState.isBlinking = true
        
        // 瞬きアニメーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animState.parameterValues["ParamEyeLOpen"] = 0.0
            animState.parameterValues["ParamEyeROpen"] = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animState.parameterValues["ParamEyeLOpen"] = 1.0
            animState.parameterValues["ParamEyeROpen"] = 1.0
            animState.isBlinking = false
        }
    }
    
    // モーション状態の更新
    animState.motionTimer += deltaTime
    if animState.motionTimer > 8.0 { // 8秒ごとにランダムモーション
        animState.motionTimer = 0.0
        let randomMotions = ["Idle", "Tap", "FlickLeft", "FlickRight"]
        animState.motionState = randomMotions.randomElement() ?? "Idle"
        
        // モーションに応じた動き
        switch animState.motionState {
        case "Tap":
            animState.parameterValues["ParamAngleX"] = Float.random(in: -10...10)
            animState.parameterValues["ParamAngleY"] = Float.random(in: -5...5)
        case "FlickLeft":
            animState.parameterValues["ParamAngleX"] = -15.0
            animState.parameterValues["ParamAngleY"] = 5.0
        case "FlickRight":
            animState.parameterValues["ParamAngleX"] = 15.0
            animState.parameterValues["ParamAngleY"] = -5.0
        default:
            break
        }
    }
    
    // デバッグログ（大幅に減らす）
    if Int.random(in: 0..<600) == 0 { // 約1/600の確率でログ出力
        print("🔍 Live2DAnimation - Breath: \(breathValue), Motion: \(animState.motionState)")
    }
}

func playLive2DMotion(_ model: UnsafeMutableRawPointer?, _ groupName: String, _ motionIndex: Int) {
    guard let model = model else { return }
    
    print("🔍 Live2DSwiftBridge - playLive2DMotion: \(groupName)[\(motionIndex)]")
    
    // アニメーション状態の取得または作成
    if animationStates[model] == nil {
        animationStates[model] = Live2DAnimationState()
    }
    
    guard let animState = animationStates[model] else { return }
    
    // モーションに応じた実際の動き
    switch groupName {
    case "Idle":
        animState.motionState = "Idle"
        animState.parameterValues["ParamAngleX"] = 0.0
        animState.parameterValues["ParamAngleY"] = 0.0
        
    case "Tap":
        animState.motionState = "Tap"
        // タップ時の反応
        animState.parameterValues["ParamAngleX"] = Float.random(in: -15...15)
        animState.parameterValues["ParamAngleY"] = Float.random(in: -10...10)
        
        // 一定時間後に元に戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animState.parameterValues["ParamAngleX"] = 0.0
            animState.parameterValues["ParamAngleY"] = 0.0
        }
        
    case "FlickLeft", "FlickRight", "FlickUp", "FlickDown":
        animState.motionState = groupName
        
        // フリック方向に応じた動き
        switch groupName {
        case "FlickLeft":
            animState.parameterValues["ParamAngleX"] = -20.0
            animState.parameterValues["ParamAngleY"] = 5.0
        case "FlickRight":
            animState.parameterValues["ParamAngleX"] = 20.0
            animState.parameterValues["ParamAngleY"] = -5.0
        case "FlickUp":
            animState.parameterValues["ParamAngleY"] = -15.0
        case "FlickDown":
            animState.parameterValues["ParamAngleY"] = 15.0
        default:
            break
        }
        
        // 2秒後に元に戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            animState.parameterValues["ParamAngleX"] = 0.0
            animState.parameterValues["ParamAngleY"] = 0.0
        }
        
    default:
        print("Unknown motion group: \(groupName)")
    }
}

func setLive2DExpression(_ model: UnsafeMutableRawPointer?, _ expressionName: String) {
    guard let model = model else { return }
    
    print("🔍 Live2DSwiftBridge - setLive2DExpression: \(expressionName)")
    
    // アニメーション状態の取得または作成
    if animationStates[model] == nil {
        animationStates[model] = Live2DAnimationState()
    }
    
    guard let animState = animationStates[model] else { return }
    
    animState.currentExpression = expressionName
    
    // 表情に応じたパラメータ変更
    switch expressionName {
    case "smile", "happy":
        animState.parameterValues["ParamMouthOpenY"] = 0.3
        animState.parameterValues["ParamAngleX"] = 2.0
        animState.parameterValues["ParamAngleY"] = 1.0
        
    case "angry":
        animState.parameterValues["ParamMouthOpenY"] = 0.1
        animState.parameterValues["ParamAngleX"] = -3.0
        animState.parameterValues["ParamAngleY"] = -2.0
        
    case "cry", "sad":
        animState.parameterValues["ParamMouthOpenY"] = 0.0
        animState.parameterValues["ParamAngleX"] = 0.0
        animState.parameterValues["ParamAngleY"] = -5.0
        
    case "sleep":
        animState.parameterValues["ParamEyeLOpen"] = 0.1
        animState.parameterValues["ParamEyeROpen"] = 0.1
        animState.parameterValues["ParamMouthOpenY"] = 0.0
        
    default: // normal
        animState.parameterValues["ParamMouthOpenY"] = 0.0
        animState.parameterValues["ParamAngleX"] = 0.0
        animState.parameterValues["ParamAngleY"] = 0.0
        animState.parameterValues["ParamEyeLOpen"] = 1.0
        animState.parameterValues["ParamEyeROpen"] = 1.0
    }
}

func setLive2DParameter(_ model: UnsafeMutableRawPointer?, _ paramName: String, _ value: Float) {
    guard let model = model else { return }
    
    // アニメーション状態の取得または作成
    if animationStates[model] == nil {
        animationStates[model] = Live2DAnimationState()
    }
    
    guard let animState = animationStates[model] else { return }
    
    // パラメータ値を設定
    animState.parameterValues[paramName] = value
    
    // 重要なパラメータのみデバッグログ表示
    let importantParams = ["ParamAngleX", "ParamAngleY", "ParamMouthOpenY", "ParamEyeLOpen", "ParamEyeROpen"]
    if importantParams.contains(paramName) {
        print("🔍 Live2DParameter - \(paramName) = \(value)")
    }
}

// MARK: - Utility Functions

func getModelPath(for modelName: String) -> String {
    // プロジェクト直下に配置されたファイルを使用
    let projectRootPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
    
    let modelFileName: String
    switch modelName {
    case "character_female":
        modelFileName = "koharu.model3.json"
    case "character_male":
        modelFileName = "haruto.model3.json"
    default:
        modelFileName = "model.model3.json"
    }
    
    let directPath = "\(projectRootPath)/\(modelFileName)"
    print("🔍 Live2DSwiftBridge - プロジェクト直下パス: \(directPath)")
    
    // ファイルの存在確認
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: directPath) {
        print("✅ Live2DSwiftBridge - ファイル存在確認成功: \(directPath)")
    } else {
        print("❌ Live2DSwiftBridge - ファイルが見つかりません: \(directPath)")
    }
    
    return directPath
}

// MARK: - Actual Model Loading Implementation

func loadActualLive2DModelData(modelPath: String) -> Live2DModelData? {
    print("🔍 Live2DSwiftBridge - loadActualLive2DModelData開始: \(modelPath)")
    
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("❌ Live2DSwiftBridge - Metal device not available")
        return nil
    }
    
    let fileManager = FileManager.default
    let modelDir = (modelPath as NSString).deletingLastPathComponent
    
    do {
        // モデルJSONファイルを読み込み
        let data = try Data(contentsOf: URL(fileURLWithPath: modelPath))
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let fileReferences = json["FileReferences"] as? [String: Any] else {
            print("❌ Live2DSwiftBridge - JSONパースエラー")
            return nil
        }
        
        // テクスチャファイルを読み込み
        var textures: [MTLTexture] = []
        
        if let textureFiles = fileReferences["Textures"] as? [String] {
            for textureFile in textureFiles {
                // プロジェクト直下に配置されたテクスチャファイルを探す
                let projectRootPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
                let texturePath = "\(projectRootPath)/\(textureFile)"
                
                print("🔍 Live2DSwiftBridge - テクスチャ読み込み: \(texturePath)")
                
                if let texture = loadTextureFromFile(path: texturePath, device: device) {
                    textures.append(texture)
                    print("✅ Live2DSwiftBridge - テクスチャ読み込み成功: \(textureFile)")
                } else {
                    print("❌ Live2DSwiftBridge - テクスチャ読み込み失敗: \(textureFile)")
                    
                    // フォールバック: 元の相対パスも試す
                    let fallbackPath = "\(modelDir)/\(textureFile)"
                    print("🔍 Live2DSwiftBridge - フォールバック試行: \(fallbackPath)")
                    
                    if let texture = loadTextureFromFile(path: fallbackPath, device: device) {
                        textures.append(texture)
                        print("✅ Live2DSwiftBridge - フォールバックでテクスチャ読み込み成功: \(textureFile)")
                    } else {
                        print("❌ Live2DSwiftBridge - フォールバックも失敗: \(textureFile)")
                    }
                }
            }
        }
        
        // .moc3ファイルを読み込み
        var mocData: Data? = nil
        if let mocFile = fileReferences["Moc"] as? String {
            let projectRootPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
            let mocPath = "\(projectRootPath)/\(mocFile)"
            
            if fileManager.fileExists(atPath: mocPath) {
                mocData = try Data(contentsOf: URL(fileURLWithPath: mocPath))
                print("✅ Live2DSwiftBridge - .moc3ファイル読み込み成功: \(mocData?.count ?? 0) bytes")
            } else {
                print("❌ Live2DSwiftBridge - .moc3ファイルが見つかりません: \(mocPath)")
            }
        }
        
        // 物理ファイルを読み込み
        var physicsData: Data? = nil
        if let physicsFile = fileReferences["Physics"] as? String {
            let projectRootPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
            let physicsPath = "\(projectRootPath)/\(physicsFile)"
            
            if fileManager.fileExists(atPath: physicsPath) {
                physicsData = try Data(contentsOf: URL(fileURLWithPath: physicsPath))
                print("✅ Live2DSwiftBridge - 物理ファイル読み込み成功: \(physicsData?.count ?? 0) bytes")
            } else {
                print("❌ Live2DSwiftBridge - 物理ファイルが見つかりません: \(physicsPath)")
            }
        }
        
        // モーション情報を取得
        var motions: [String: [String]] = [:]
        if let motionGroups = fileReferences["Motions"] as? [String: Any] {
            for (groupName, motionList) in motionGroups {
                if let motionArray = motionList as? [[String: Any]] {
                    motions[groupName] = motionArray.compactMap { $0["File"] as? String }
                }
            }
        }
        
        let modelData = Live2DModelData(
            modelPath: modelPath,
            textures: textures,
            mocData: mocData,
            physicsData: physicsData,
            motions: motions,
            isLoaded: !textures.isEmpty
        )
        
        print("✅ Live2DSwiftBridge - Live2DModelData作成完了")
        print("🔍 Live2DSwiftBridge - テクスチャ数: \(textures.count)")
        print("🔍 Live2DSwiftBridge - .moc3データ: \(mocData != nil ? "有り" : "無し")")
        print("🔍 Live2DSwiftBridge - モーション数: \(motions.count)")
        
        return modelData
        
    } catch {
        print("❌ Live2DSwiftBridge - ファイル読み込みエラー: \(error)")
        return nil
    }
}

func loadTextureFromFile(path: String, device: MTLDevice) -> MTLTexture? {
    guard let image = UIImage(contentsOfFile: path) else {
        print("❌ Live2DSwiftBridge - UIImage読み込み失敗: \(path)")
        return nil
    }
    
    guard let cgImage = image.cgImage else {
        print("❌ Live2DSwiftBridge - CGImage変換失敗")
        return nil
    }
    
    let textureLoader = MTKTextureLoader(device: device)
    
    do {
        let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.`private`.rawValue
        ])
        
        print("✅ Live2DSwiftBridge - MTLTexture作成成功: \(texture.width)x\(texture.height)")
        return texture
        
    } catch {
        print("❌ Live2DSwiftBridge - MTLTexture作成エラー: \(error)")
        return nil
    }
}

func getLive2DAnimationState(_ model: UnsafeMutableRawPointer?) -> Live2DAnimationState? {
    guard let model = model else { return nil }
    return animationStates[model]
}

// MARK: - Memory Management

func deallocateLive2DPointer(_ pointer: UnsafeMutableRawPointer?) {
    // メモリリークを防ぐためのクリーンアップ
    if let pointer = pointer {
        let intPointer = pointer.bindMemory(to: Int.self, capacity: 1)
        intPointer.deallocate()
    }
}