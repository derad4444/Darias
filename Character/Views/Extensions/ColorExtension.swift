import SwiftUI

// MARK: - Color Extension (Legacy - 新しいAppColors.swiftを推奨)
// Color(hex:)イニシャライザを維持（後方互換性のため）
extension Color {
    init(hex: String) {
        self = Color.fromHex(hex)
    }
    
    // 旧カラー定義（後方互換性のため）
    static let oldPurple = Color(hex: "#A084CA")
    static let oldTabAccent = Color(hex: "#8a2be2")
    
    // 新しいカラーテーマへの移行用エイリアス
    static let primaryColor = AppTheme.primaryPink
    static let secondaryColor = AppTheme.secondaryLavender
    static let accentColor = AppTheme.accentGold
}