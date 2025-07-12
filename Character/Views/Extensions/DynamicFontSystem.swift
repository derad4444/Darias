// Views/Extensions/DynamicFontSystem.swift

import SwiftUI

// 動的フォントシステムの拡張
extension Font {
    struct DynamicTypography {
        // 環境オブジェクトからfontManagerを取得するヘルパー関数
        private static func getFontManager() -> FontSettingsManager {
            // 実際の環境オブジェクトからfontManagerを取得
            return FontSettingsManager.shared
        }
        
        // タイトル系
        static func largeTitle() -> Font {
            return getFontManager().font(size: 28, weight: .bold)
        }
        
        static func title() -> Font {
            return getFontManager().font(size: 22, weight: .semibold)
        }
        
        static func title2() -> Font {
            return getFontManager().font(size: 20, weight: .semibold)
        }
        
        static func title3() -> Font {
            return getFontManager().font(size: 18, weight: .semibold)
        }
        
        static func headline() -> Font {
            return getFontManager().font(size: 18, weight: .semibold)
        }
        
        // ボディ系
        static func body() -> Font {
            return getFontManager().font(size: 16, weight: .regular)
        }
        
        static func bodyMedium() -> Font {
            return getFontManager().font(size: 16, weight: .medium)
        }
        
        static func callout() -> Font {
            return getFontManager().font(size: 14, weight: .regular)
        }
        
        // 小さなテキスト系
        static func caption() -> Font {
            return getFontManager().font(size: 12, weight: .regular)
        }
        
        static func caption2() -> Font {
            return getFontManager().font(size: 10, weight: .regular)
        }
        
        static func captionMedium() -> Font {
            return getFontManager().font(size: 12, weight: .medium)
        }
        
        static func footnote() -> Font {
            return getFontManager().font(size: 10, weight: .regular)
        }
        
        // 特別な用途
        static func chatBubble() -> Font {
            return getFontManager().font(size: 15, weight: .regular)
        }
        
        static func characterName() -> Font {
            return getFontManager().font(size: 20, weight: .bold)
        }
        
        static func buttonText() -> Font {
            return getFontManager().font(size: 16, weight: .semibold)
        }
    }
}

// View用の便利なモディファイア
extension Text {
    // 新しい動的フォントスタイル - サイズ比率を保つ
    func dynamicLargeTitle() -> some View {
        self.font(FontSettingsManager.shared.font(size: 34, weight: .bold))
    }
    
    func dynamicTitle() -> some View {
        self.font(FontSettingsManager.shared.font(size: 28, weight: .bold))
    }
    
    func dynamicTitle2() -> some View {
        self.font(FontSettingsManager.shared.font(size: 22, weight: .bold))
    }
    
    func dynamicTitle3() -> some View {
        self.font(FontSettingsManager.shared.font(size: 20, weight: .semibold))
    }
    
    func dynamicHeadline() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .semibold))
    }
    
    func dynamicBody() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .regular))
    }
    
    func dynamicBodyMedium() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .medium))
    }
    
    func dynamicCallout() -> some View {
        self.font(FontSettingsManager.shared.font(size: 16, weight: .regular))
    }
    
    func dynamicCaption() -> some View {
        self.font(FontSettingsManager.shared.font(size: 12, weight: .regular))
    }
    
    func dynamicCaptionMedium() -> some View {
        self.font(FontSettingsManager.shared.font(size: 12, weight: .medium))
    }
    
    func dynamicCaption2() -> some View {
        self.font(FontSettingsManager.shared.font(size: 11, weight: .regular))
    }
    
    func dynamicFootnote() -> some View {
        self.font(FontSettingsManager.shared.font(size: 13, weight: .regular))
    }
    
    func dynamicChatBubble() -> some View {
        self.font(FontSettingsManager.shared.font(size: 16, weight: .regular))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
    }
    
    func dynamicCharacterName() -> some View {
        self.font(FontSettingsManager.shared.font(size: 20, weight: .bold))
    }
    
    func dynamicButtonText() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .semibold))
    }
}

// TextField用の動的フォント
extension TextField {
    func dynamicFont(_ styleFunction: @escaping () -> Font) -> some View {
        self.font(styleFunction())
    }
    
    func dynamicBody() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .regular))
    }
}

// SecureField用の動的フォント
extension SecureField {
    func dynamicFont(_ styleFunction: @escaping () -> Font) -> some View {
        self.font(styleFunction())
    }
    
    func dynamicBody() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .regular))
    }
}

// Button用の動的フォント
extension Button {
    func dynamicFont(_ styleFunction: @escaping () -> Font) -> some View {
        self.font(styleFunction())
    }
}

// TextEditor用の動的フォント
extension TextEditor {
    func dynamicFont(_ styleFunction: @escaping () -> Font) -> some View {
        self.font(styleFunction())
    }
    
    func dynamicBody() -> some View {
        self.font(FontSettingsManager.shared.font(size: 17, weight: .regular))
    }
}

// フォント設定をアプリ全体で共有するためのEnvironmentKey
struct FontSettingsKey: EnvironmentKey {
    static let defaultValue = FontSettingsManager()
}

extension EnvironmentValues {
    var fontSettings: FontSettingsManager {
        get { self[FontSettingsKey.self] }
        set { self[FontSettingsKey.self] = newValue }
    }
}

// フォントプレビュー用のView
struct FontPreviewView: View {
    let fontFamily: AppFontFamily
    let fontSize: FontSizeScale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サンプルテキスト")
                .font(previewFont(size: 18, weight: .semibold))
            
            Text("あいうえお ABCDE 12345")
                .font(previewFont(size: 16, weight: .regular))
            
            Text("キャラクターアプリのフォント設定")
                .font(previewFont(size: 14, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func previewFont(size: CGFloat, weight: Font.Weight) -> Font {
        let adjustedSize = size * fontSize.scale
        
        if let customFontName = fontFamily.fontName {
            return Font.custom(customFontName, size: adjustedSize).weight(weight)
        } else {
            return Font.system(size: adjustedSize, weight: weight, design: fontFamily.fontDesign)
        }
    }
}