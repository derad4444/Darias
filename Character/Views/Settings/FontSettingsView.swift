// Views/Settings/FontSettingsView.swift

import SwiftUI

struct FontSettingsView: View {
    @ObservedObject var fontSettings = FontSettingsManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // 統一された背景
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()
                
                List {
                // フォントファミリー選択
                Section(header: Text("フォントファミリー").dynamicCallout()) {
                    ForEach(fontSettings.availableFonts) { font in
                        Button(action: {
                            fontSettings.fontFamily = font
                            // フォント変更を即座に反映させる
                            fontSettings.objectWillChange.send()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(font.displayName)
                                        .font(previewFont(for: font, size: 16, weight: .medium))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    
                                }
                                
                                Spacer()
                                
                                if fontSettings.fontFamily == font {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(colorSettings.getCurrentAccentColor())
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 12)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.3))
                                .background(BlurView(style: .systemUltraThinMaterial))
                        )
                    }
                }
                
                // フォントサイズ選択
                Section(header: Text("フォントサイズ").dynamicCallout()) {
                    ForEach(FontSizeScale.allCases) { size in
                        Button(action: {
                            fontSettings.fontSize = size
                            // フォントサイズ変更を即座に反映させる
                            fontSettings.objectWillChange.send()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(size.displayName)
                                        .font(previewFont(for: fontSettings.fontFamily, size: 16 * size.scale, weight: .medium))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    
                                    Text("倍率: \(String(format: "%.1f", size.scale))x")
                                        .font(.caption)
                                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                    
                                }
                                
                                Spacer()
                                
                                if fontSettings.fontSize == size {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(colorSettings.getCurrentAccentColor())
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 12)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.3))
                                .background(BlurView(style: .systemUltraThinMaterial))
                        )
                    }
                }
                
                
                // リセット
                Section {
                    Button {
                        fontSettings.fontFamily = .systemDefault
                        fontSettings.fontSize = .medium
                        fontSettings.objectWillChange.send()
                    } label: {
                        Text("デフォルトに戻す")
                            .dynamicBody()
                            .foregroundColor(.red)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.3))
                            .background(BlurView(style: .systemUltraThinMaterial))
                    )
                }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("フォント設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完了")
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                    }
                }
            }
        }
    }
    
    // プレビュー用のフォント生成
    private func previewFont(for fontFamily: AppFontFamily, size: CGFloat, weight: Font.Weight) -> Font {
        if let customFontName = fontFamily.fontName {
            return Font.custom(customFontName, size: size).weight(weight)
        } else {
            return Font.system(size: size, weight: weight, design: fontFamily.fontDesign)
        }
    }
}

// プレビュー用
struct FontSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FontSettingsView()
            .environmentObject(FontSettingsManager.shared)
    }
}
