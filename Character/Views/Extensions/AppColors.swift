// Views/Extensions/AppColors.swift

import SwiftUI

extension Color {
    struct AppTheme {
        // メインカラー - 女性らしいピンク系
        static let primaryPink = Color.fromHex("#FF6B9D")      // 活き活きとしたコーラルピンク
        static let secondaryLavender = Color.fromHex("#C44AC0") // リッチなラベンダー
        static let accentGold = Color.fromHex("#FFD93D")        // 温かみのあるゴールド
        
        // サブカラー - 優しく上品な色合い
        static let softPeach = Color.fromHex("#FFAAA7")         // 柔らかなピーチ
        static let mintGreen = Color.fromHex("#6BCF7F")         // フレッシュなミント
        static let dustyRose = Color.fromHex("#D4A5A5")         // ダスティローズ
        static let creamWhite = Color.fromHex("#FFF8F3")        // 温かなクリーム
        
        // グラデーション用背景色
        static let backgroundGradient1 = Color.fromHex("#FFE5F1") // ソフトピンク
        static let backgroundGradient2 = Color.fromHex("#E5F3FF") // ライトブルー
        static let backgroundGradient3 = Color.fromHex("#F0E5FF") // ライトラベンダー
        
        // テキスト色
        static let textPrimary = Color.fromHex("#2D2D2D")        // 濃いグレー
        static let textSecondary = Color.fromHex("#6B6B6B")      // ミディアムグレー
        static let textLight = Color.fromHex("#A0A0A0")          // ライトグレー
        
        // カード・コンテナ背景
        static let cardBackground = Color.white.opacity(0.9)
        static let cardShadow = Color.black.opacity(0.05)
    }
    
    // 新しいHex文字列からColorを生成するヘルパー（重複回避）
    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 美しいグラデーション定義
extension LinearGradient {
    struct AppGradients {
        static let primaryButton = LinearGradient(
            colors: [Color.AppTheme.primaryPink, Color.AppTheme.secondaryLavender],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let backgroundMain = LinearGradient(
            colors: [Color.AppTheme.backgroundGradient1, Color.AppTheme.backgroundGradient2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let cardShine = LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentHighlight = LinearGradient(
            colors: [Color.AppTheme.accentGold, Color.AppTheme.softPeach],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}