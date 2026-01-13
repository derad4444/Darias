import Foundation
import UIKit

/// BIG5性格スコアから画像ファイル名を生成するサービス
class PersonalityImageService {

    /// BIG5スコアから画像ファイル名を生成
    /// - Parameters:
    ///   - scores: BIG5スコア（各1-5の範囲）
    ///   - gender: 性別（male/female）
    /// - Returns: 画像ファイル名（例: "Female_HLMHL" または "Male_HLMHL"）
    static func generateImageFileName(from scores: Big5Scores, gender: CharacterGender) -> String {
        // 1. 各スコアをL/M/Hに変換（OCEANの順番）
        let o = convertScoreToLevel(scores.openness)
        let c = convertScoreToLevel(scores.conscientiousness)
        let e = convertScoreToLevel(scores.extraversion)
        let a = convertScoreToLevel(scores.agreeableness)
        let n = convertScoreToLevel(scores.neuroticism)

        // 2. 性別プレフィックスを追加
        let genderPrefix = gender == .female ? "Female" : "Male"

        // 3. OCEANの順番で結合してファイル名を生成
        let fileName = "\(genderPrefix)_\(o)\(c)\(e)\(a)\(n)"

        print("📸 画像ファイル名生成:")
        print("   スコア: O=\(scores.openness), C=\(scores.conscientiousness), E=\(scores.extraversion), A=\(scores.agreeableness), N=\(scores.neuroticism)")
        print("   性別: \(gender.rawValue)")
        print("   変換後: \(fileName)")

        return fileName
    }

    /// スコア（1-5）をレベル（L/M/H）に変換
    /// - 1, 2 → L (LOW)
    /// - 3 → M (MID)
    /// - 4, 5 → H (HIGH)
    private static func convertScoreToLevel(_ score: Double) -> String {
        if score <= 2.0 {
            return "L"
        } else if score <= 3.0 {
            return "M"
        } else {
            return "H"
        }
    }

    /// 画像ファイルが存在するか確認
    /// - Parameters:
    ///   - scores: BIG5スコア
    ///   - gender: 性別
    /// - Returns: 画像が存在する場合はtrue
    static func imageExists(for scores: Big5Scores, gender: CharacterGender) -> Bool {
        let fileName = generateImageFileName(from: scores, gender: gender)
        return UIImage(named: fileName) != nil
    }

    /// デフォルト画像ファイル名を取得
    /// - Parameter gender: 性別
    /// - Returns: デフォルト画像ファイル名（例: "character_female"）
    static func getDefaultImageName(for gender: CharacterGender) -> String {
        return "character_\(gender.rawValue)"
    }

    // MARK: - Firebase Storage Path Generation

    /// BIG5スコアからFirebase Storageのパスを生成
    /// - Parameters:
    ///   - scores: BIG5スコア
    ///   - gender: 性別
    /// - Returns: Firebase Storageパス（例: "character-images/female/Female_HLMHL.png"）
    static func generateStoragePath(from scores: Big5Scores, gender: CharacterGender) -> String {
        let fileName = generateImageFileName(from: scores, gender: gender)
        return "character-images/\(gender.rawValue)/\(fileName).png"
    }

    /// ファイル名からFirebase Storageのパスを生成
    /// - Parameters:
    ///   - fileName: 画像ファイル名（例: "Female_HLMHL"）
    ///   - gender: 性別
    /// - Returns: Firebase Storageパス
    static func generateStoragePath(fileName: String, gender: CharacterGender) -> String {
        return "character-images/\(gender.rawValue)/\(fileName).png"
    }

    /// Firebase Storageから画像を取得（非同期）
    /// - Parameters:
    ///   - scores: BIG5スコア
    ///   - gender: 性別
    /// - Returns: UIImage
    static func fetchImage(from scores: Big5Scores, gender: CharacterGender) async throws -> UIImage {
        let fileName = generateImageFileName(from: scores, gender: gender)
        return try await FirebaseImageService.shared.fetchImage(fileName: fileName, gender: gender)
    }

    /// デフォルト画像を取得
    /// - Parameter gender: 性別
    /// - Returns: UIImage
    static func getDefaultImage(for gender: CharacterGender) -> UIImage? {
        let imageName = getDefaultImageName(for: gender)
        return UIImage(named: imageName)
    }

    /// 画像を取得（Firebase優先、フォールバックでローカル）
    /// - Parameters:
    ///   - scores: BIG5スコア
    ///   - gender: 性別
    /// - Returns: UIImage
    static func fetchImageWithFallback(from scores: Big5Scores, gender: CharacterGender) async -> UIImage {
        do {
            // Firebase Storageから取得を試みる
            return try await fetchImage(from: scores, gender: gender)
        } catch {
            // フォールバック: デフォルト画像
            return getDefaultImage(for: gender) ?? UIImage()
        }
    }
}
