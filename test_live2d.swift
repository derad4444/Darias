import Foundation
import UIKit
import Metal
import MetalKit

// Live2D Test実行クラス
class Live2DTest {
    static func main() {
        print("🔍 Live2D テスト開始")
        
        // Live2DFileTestクラスの呼び出し
        Live2DFileTest.testAllFiles()
        
        // Live2D統合テスト
        Live2DFileTest.testLive2DIntegration()
        
        // Live2DManagerのテスト
        testLive2DManager()
        
        print("✅ Live2D テスト完了")
    }
    
    static func testLive2DManager() {
        print("🔍 Live2DManager テスト開始")
        
        let manager = Live2DManager()
        
        // 初期化確認
        manager.initialize()
        
        // モデル読み込みテスト
        manager.loadModel(modelName: "character_female")
        
        // モデル状態確認
        let isLoaded = manager.isModelLoaded()
        print("📊 モデル読み込み状態: \(isLoaded)")
        
        // モデル情報取得
        let modelInfo = manager.getModelInfo()
        print("📊 モデル情報: \(modelInfo)")
        
        print("✅ Live2DManager テスト完了")
    }
}

// テスト実行
Live2DTest.main()