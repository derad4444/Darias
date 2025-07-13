import Foundation
import UIKit

class Live2DFileTest {
    
    // MARK: - Static Test Methods
    static func testAllFiles() {
        print("🔍 Live2DFileTest - すべてのファイルテスト開始")
        
        // 基本的なファイル存在確認
        testFileExistence()
        
        // モデルファイルの詳細テスト
        testModelFiles()
        
        // テクスチャファイルの確認
        testTextureFiles()
        
        // アニメーションファイルの確認
        testAnimationFiles()
        
        print("✅ Live2DFileTest - すべてのファイルテスト完了")
    }
    
    // MARK: - File Existence Tests
    private static func testFileExistence() {
        print("🔍 Live2DFileTest - ファイル存在確認開始")
        
        let projectPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
        let fileManager = FileManager.default
        
        // 必要なLive2Dファイルのリスト
        let requiredFiles = [
            "koharu.model3.json",
            "koharu.moc3",
            "koharu.physics3.json",
            "koharu.cdi3.json"
        ]
        
        var allFilesExist = true
        
        for fileName in requiredFiles {
            let filePath = "\(projectPath)/\(fileName)"
            let exists = fileManager.fileExists(atPath: filePath)
            
            if exists {
                print("✅ Live2DFileTest - \(fileName): 存在")
                
                // ファイルサイズも確認
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: filePath)
                    let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
                    print("   ファイルサイズ: \(fileSize) bytes")
                } catch {
                    print("   ファイルサイズ取得エラー: \(error)")
                }
            } else {
                print("❌ Live2DFileTest - \(fileName): 見つかりません")
                allFilesExist = false
            }
        }
        
        if allFilesExist {
            print("✅ Live2DFileTest - すべての必要ファイルが存在します")
        } else {
            print("❌ Live2DFileTest - 一部のファイルが見つかりません")
        }
    }
    
    // MARK: - Model File Tests
    private static func testModelFiles() {
        print("🔍 Live2DFileTest - モデルファイルテスト開始")
        
        let projectPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
        let modelPath = "\(projectPath)/koharu.model3.json"
        
        // モデルファイルの読み込みテスト
        testModelFileReading(at: modelPath)
        
        // MOC3ファイルのテスト
        let moc3Path = "\(projectPath)/koharu.moc3"
        testMoc3File(at: moc3Path)
        
        print("✅ Live2DFileTest - モデルファイルテスト完了")
    }
    
    private static func testModelFileReading(at path: String) {
        print("🔍 Live2DFileTest - モデルファイル読み込みテスト: \(path)")
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Live2DFileTest - モデルファイルが存在しません: \(path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            print("✅ Live2DFileTest - モデルファイル読み込み成功: \(data.count) bytes")
            
            // JSONとして解析可能かテスト
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let jsonDict = json as? [String: Any] {
                print("✅ Live2DFileTest - JSON解析成功")
                
                // 基本構造の確認
                if let version = jsonDict["Version"] as? Int {
                    print("   Version: \(version)")
                }
                
                if let fileReferences = jsonDict["FileReferences"] as? [String: Any] {
                    print("   FileReferences: \(fileReferences.keys.joined(separator: ", "))")
                    
                    // MOC3ファイルの参照確認
                    if let moc = fileReferences["Moc"] as? String {
                        print("   Moc file: \(moc)")
                    }
                    
                    // テクスチャファイルの参照確認
                    if let textures = fileReferences["Textures"] as? [String] {
                        print("   Textures: \(textures.joined(separator: ", "))")
                    }
                }
                
                // Groups情報の確認
                if let groups = jsonDict["Groups"] as? [[String: Any]] {
                    print("   Groups count: \(groups.count)")
                }
            }
            
        } catch {
            print("❌ Live2DFileTest - モデルファイル読み込みエラー: \(error)")
        }
    }
    
    private static func testMoc3File(at path: String) {
        print("🔍 Live2DFileTest - MOC3ファイルテスト: \(path)")
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Live2DFileTest - MOC3ファイルが存在しません: \(path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            print("✅ Live2DFileTest - MOC3ファイル読み込み成功: \(data.count) bytes")
            
            // MOC3ファイルの基本的な検証
            if data.count > 0 {
                let header = data.prefix(16)
                print("   Header bytes: \(header.map { String(format: "%02x", $0) }.joined(separator: " "))")
                
                // MOC3の基本的なマジックナンバー確認
                if data.count >= 4 {
                    let magicBytes = data.prefix(4)
                    print("   Magic bytes: \(magicBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
                }
            }
            
        } catch {
            print("❌ Live2DFileTest - MOC3ファイル読み込みエラー: \(error)")
        }
    }
    
    // MARK: - Texture File Tests
    private static func testTextureFiles() {
        print("🔍 Live2DFileTest - テクスチャファイルテスト開始")
        
        let projectPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
        let texturePath = "\(projectPath)/Character/Resources/Live2DModels/Female/texture_00_female.png"
        
        if FileManager.default.fileExists(atPath: texturePath) {
            print("✅ Live2DFileTest - テクスチャファイル存在: \(texturePath)")
            
            // 画像として読み込み可能かテスト
            if let image = UIImage(contentsOfFile: texturePath) {
                print("✅ Live2DFileTest - テクスチャ画像読み込み成功: \(image.size)")
            } else {
                print("❌ Live2DFileTest - テクスチャ画像読み込み失敗")
            }
        } else {
            print("❌ Live2DFileTest - テクスチャファイルが見つかりません: \(texturePath)")
        }
        
        print("✅ Live2DFileTest - テクスチャファイルテスト完了")
    }
    
    // MARK: - Animation File Tests
    private static func testAnimationFiles() {
        print("🔍 Live2DFileTest - アニメーションファイルテスト開始")
        
        let projectPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
        let physicsPath = "\(projectPath)/koharu.physics3.json"
        
        if FileManager.default.fileExists(atPath: physicsPath) {
            print("✅ Live2DFileTest - 物理演算ファイル存在: \(physicsPath)")
            
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: physicsPath))
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                
                if let jsonDict = json as? [String: Any] {
                    print("✅ Live2DFileTest - 物理演算ファイル解析成功")
                    
                    if let version = jsonDict["Version"] as? Int {
                        print("   Physics Version: \(version)")
                    }
                    
                    if let meta = jsonDict["Meta"] as? [String: Any] {
                        print("   Meta: \(meta)")
                    }
                }
                
            } catch {
                print("❌ Live2DFileTest - 物理演算ファイル読み込みエラー: \(error)")
            }
        } else {
            print("❌ Live2DFileTest - 物理演算ファイルが見つかりません: \(physicsPath)")
        }
        
        print("✅ Live2DFileTest - アニメーションファイルテスト完了")
    }
    
    // MARK: - Integration Test
    static func testLive2DIntegration() {
        print("🔍 Live2DFileTest - Live2D統合テスト開始")
        
        // 必要なファイルがすべて揃っているかの最終確認
        let projectPath = "/Users/onoderaryousuke/Desktop/development-D/Character"
        let fileManager = FileManager.default
        
        let requiredFiles = [
            "koharu.model3.json",
            "koharu.moc3",
            "koharu.physics3.json",
            "Character/Resources/Live2DModels/Female/texture_00_female.png"
        ]
        
        var integrationTest = true
        
        for fileName in requiredFiles {
            let filePath = "\(projectPath)/\(fileName)"
            if !fileManager.fileExists(atPath: filePath) {
                print("❌ Live2DFileTest - 統合テスト失敗: \(fileName)が見つかりません")
                integrationTest = false
            }
        }
        
        if integrationTest {
            print("✅ Live2DFileTest - Live2D統合テスト成功: すべてのファイルが揃っています")
        } else {
            print("❌ Live2DFileTest - Live2D統合テスト失敗: 一部のファイルが不足しています")
        }
        
        print("✅ Live2DFileTest - Live2D統合テスト完了")
    }
}