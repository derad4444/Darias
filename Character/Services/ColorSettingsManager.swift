import SwiftUI
import Foundation

class ColorSettingsManager: ObservableObject {
    static let shared = ColorSettingsManager()
    
    @AppStorage("customBackgroundStartColor") private var backgroundStartColorHex: String = "#EDE6F2"
    @AppStorage("customBackgroundEndColor") private var backgroundEndColorHex: String = "#F9F6F0"
    @AppStorage("customTextColor") private var textColorHex: String = "#000000"
    @AppStorage("customAccentColor") private var accentColorHex: String = "#A084CA"
    @AppStorage("isGradientBackground") private var isGradientBackground: Bool = true
    
    @Published var backgroundStartColor: Color = Color(hex: "#EDE6F2")
    @Published var backgroundEndColor: Color = Color(hex: "#F9F6F0")
    @Published var textColor: Color = Color.black
    @Published var accentColor: Color = Color(hex: "#A084CA")
    @Published var useGradient: Bool = true
    
    private init() {
        loadColors()
    }
    
    private func loadColors() {
        backgroundStartColor = Color(hex: backgroundStartColorHex)
        backgroundEndColor = Color(hex: backgroundEndColorHex)
        textColor = Color(hex: textColorHex)
        accentColor = Color(hex: accentColorHex)
        useGradient = isGradientBackground
        
        // デバッグ用ログ
        print("🎨 ColorSettings loaded:")
        print("  背景開始色: \(backgroundStartColorHex)")
        print("  背景終了色: \(backgroundEndColorHex)")
        print("  テキスト色: \(textColorHex)")
        print("  アクセント色: \(accentColorHex)")
        print("  グラデーション: \(useGradient)")
    }
    
    func saveColors() {
        backgroundStartColorHex = backgroundStartColor.toHex()
        backgroundEndColorHex = backgroundEndColor.toHex()
        textColorHex = textColor.toHex()
        accentColorHex = accentColor.toHex()
        isGradientBackground = useGradient
    }
    
    func resetToDefault() {
        backgroundStartColor = Color(hex: "#EDE6F2")
        backgroundEndColor = Color(hex: "#F9F6F0")
        textColor = Color.black
        accentColor = Color(hex: "#A084CA")
        useGradient = true
        saveColors()
        objectWillChange.send()
    }
    
    func forceRefresh() {
        objectWillChange.send()
        print("🔄 ColorSettings force refreshed")
    }
    
    // 現在の背景を取得（グラデーションまたは一色）
    func getCurrentBackground() -> AnyView {
        if useGradient {
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [backgroundStartColor, backgroundEndColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyView(backgroundStartColor)
        }
    }
    
    // 下位互換性のためのグラデーション関数
    func getCurrentBackgroundGradient() -> LinearGradient {
        print("🎨 Creating gradient - start: \(backgroundStartColor), end: \(backgroundEndColor), useGradient: \(useGradient)")
        
        if useGradient {
            let gradient = LinearGradient(
                gradient: Gradient(colors: [backgroundStartColor, backgroundEndColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            print("📈 Gradient created with 2 colors")
            return gradient
        } else {
            let gradient = LinearGradient(
                gradient: Gradient(colors: [backgroundStartColor, backgroundStartColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            print("📊 Single color gradient created")
            return gradient
        }
    }
    
    // 現在のテキストカラーを取得
    func getCurrentTextColor() -> Color {
        return textColor
    }
    
    // 現在のアクセントカラーを取得
    func getCurrentAccentColor() -> Color {
        return accentColor
    }
}

// Color extension for hex conversion
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
}