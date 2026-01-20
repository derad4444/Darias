// Models/FontSettings.swift

import SwiftUI
import Foundation

// フォントの種類を定義
enum AppFontFamily: String, CaseIterable, Identifiable {
    case systemDefault = "System"
    case systemRounded = "System Rounded"
    case systemMonospace = "System Monospace"
    case systemSerif = "System Serif"
    case hiraginoSans = "Hiragino Sans"
    case hiraginoMincho = "Hiragino Mincho ProN"
    case hiraginoMaruGo = "Hiragino Maru Gothic ProN"
    case notosansJP = "NotoSansJP"
    case notoSerifJP = "NotoSerifJP"
    case yuGothic = "Yu Gothic"
    case yuMincho = "Yu Mincho"
    case menlo = "Menlo"
    case avenir = "Avenir"
    case georgia = "Georgia"
    case palatino = "Palatino"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .systemDefault:
            return "システム標準"
        case .systemRounded:
            return "システム丸文字"
        case .systemMonospace:
            return "システム等幅"
        case .systemSerif:
            return "システムセリフ"
        case .hiraginoSans:
            return "ヒラギノ角ゴ"
        case .hiraginoMincho:
            return "ヒラギノ明朝"
        case .hiraginoMaruGo:
            return "ヒラギノ丸ゴ"
        case .notosansJP:
            return "Noto Sans JP"
        case .notoSerifJP:
            return "Noto Serif JP"
        case .yuGothic:
            return "游ゴシック"
        case .yuMincho:
            return "游明朝"
        case .menlo:
            return "Menlo"
        case .avenir:
            return "Avenir"
        case .georgia:
            return "Georgia"
        case .palatino:
            return "Palatino"
        }
    }
    
    var description: String {
        switch self {
        case .systemDefault:
            return "読みやすい標準フォント"
        case .systemRounded:
            return "やわらかい印象の丸文字"
        case .systemMonospace:
            return "プログラミング向け等幅フォント"
        case .systemSerif:
            return "読書に適したセリフ体"
        case .hiraginoSans:
            return "美しい日本語ゴシック体"
        case .hiraginoMincho:
            return "上品な明朝体"
        case .hiraginoMaruGo:
            return "親しみやすい丸ゴシック"
        case .notosansJP:
            return "Google開発の読みやすいフォント"
        case .notoSerifJP:
            return "Google開発の明朝体"
        case .yuGothic:
            return "モダンなゴシック体"
        case .yuMincho:
            return "伝統的な明朝体"
        case .menlo:
            return "Apple開発の等幅フォント"
        case .avenir:
            return "幾何学的な美しいフォント"
        case .georgia:
            return "スクリーン向けセリフ体"
        case .palatino:
            return "クラシックな書体"
        }
    }
    
    // フォントファミリーを実際のFont.Designに変換
    var fontDesign: Font.Design {
        switch self {
        case .systemDefault:
            return .default
        case .systemRounded:
            return .rounded
        case .systemMonospace:
            return .monospaced
        case .systemSerif:
            return .serif
        case .hiraginoSans, .hiraginoMaruGo, .notosansJP, .yuGothic:
            return .default
        case .hiraginoMincho, .yuMincho, .notoSerifJP:
            return .serif
        case .menlo:
            return .monospaced
        case .avenir, .georgia, .palatino:
            return .default
        }
    }
    
    // カスタムフォント名を取得
    var fontName: String? {
        switch self {
        case .systemDefault, .systemRounded, .systemMonospace, .systemSerif:
            return nil
        case .hiraginoSans:
            return "HiraginoSans-W3"
        case .hiraginoMincho:
            return "HiraginoMincho-ProN-W3"
        case .hiraginoMaruGo:
            return "HiraginoSansGB-W3"
        case .notosansJP:
            return "NotoSansJP-Regular"
        case .notoSerifJP:
            return "NotoSerifJP-Regular"
        case .yuGothic:
            return "YuGo-Medium"
        case .yuMincho:
            return "YuMin-Medium"
        case .menlo:
            return "Menlo-Regular"
        case .avenir:
            return "Avenir-Book"
        case .georgia:
            return "Georgia"
        case .palatino:
            return "Palatino-Roman"
        }
    }
}

// フォントサイズの設定
enum FontSizeScale: String, CaseIterable, Identifiable {
    case extraSmall = "extraSmall"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .extraSmall:
            return "とても小さく"
        case .small:
            return "小さく"
        case .medium:
            return "標準"
        case .large:
            return "大きく"
        case .extraLarge:
            return "とても大きく"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .extraSmall:
            return 0.8
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.2
        case .extraLarge:
            return 1.4
        }
    }
}

// フォント設定を管理するObservableObject
class FontSettingsManager: ObservableObject {
    // アプリ全体で共有するシングルトンインスタンス
    static let shared = FontSettingsManager()
    
    @Published var fontFamily: AppFontFamily {
        didSet {
            UserDefaults.standard.set(fontFamily.rawValue, forKey: "selectedFontFamily")
        }
    }
    
    @Published var fontSize: FontSizeScale {
        didSet {
            UserDefaults.standard.set(fontSize.rawValue, forKey: "selectedFontSize")
        }
    }
    
    init() {
        // UserDefaultsから設定を読み込み
        let savedFontFamily = UserDefaults.standard.string(forKey: "selectedFontFamily") ?? AppFontFamily.systemDefault.rawValue
        self.fontFamily = AppFontFamily(rawValue: savedFontFamily) ?? .systemDefault
        
        let savedFontSize = UserDefaults.standard.string(forKey: "selectedFontSize") ?? FontSizeScale.medium.rawValue
        self.fontSize = FontSizeScale(rawValue: savedFontSize) ?? .medium
    }
    
    // 指定したベースサイズで動的フォントを生成
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let adjustedSize = size * fontSize.scale
        
        if let customFontName = fontFamily.fontName {
            // カスタムフォントの場合
            return Font.custom(customFontName, size: adjustedSize)
                .weight(weight)
        } else {
            // システムフォントの場合
            return Font.system(size: adjustedSize, weight: weight, design: fontFamily.fontDesign)
        }
    }
    
    // フォントが利用可能かチェック
    func isFontAvailable(_ fontFamily: AppFontFamily) -> Bool {
        guard let fontName = fontFamily.fontName else {
            return true // システムフォントは常に利用可能
        }
        
        return UIFont(name: fontName, size: 16) != nil
    }
    
    // 利用可能なフォントのみをフィルタ
    var availableFonts: [AppFontFamily] {
        return AppFontFamily.allCases.filter { isFontAvailable($0) }
    }
}