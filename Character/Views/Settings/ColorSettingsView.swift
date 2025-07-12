import SwiftUI

struct ColorSettingsView: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // 背景プレビュー
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 設定セクション
                            VStack(spacing: 20) {
                                // 背景タイプ選択
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("背景タイプ")
                                        .dynamicHeadline()
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    
                                    Picker("背景タイプ", selection: $colorSettings.useGradient) {
                                        Text("グラデーション").tag(true)
                                        Text("一色").tag(false)
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: colorSettings.useGradient) { _ in
                                        colorSettings.saveColors()
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                // 背景色設定
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("背景色")
                                        .dynamicHeadline()
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    
                                    VStack(spacing: 12) {
                                        HStack {
                                            Text(colorSettings.useGradient ? "開始色" : "背景色")
                                                .dynamicCallout()
                                                .foregroundColor(colorSettings.getCurrentTextColor())
                                            Spacer()
                                            ColorPicker("", selection: $colorSettings.backgroundStartColor)
                                                .labelsHidden()
                                                .onChange(of: colorSettings.backgroundStartColor) { _ in
                                                    colorSettings.saveColors()
                                                }
                                        }
                                        
                                        if colorSettings.useGradient {
                                            HStack {
                                                Text("終了色")
                                                    .dynamicCallout()
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                                Spacer()
                                                ColorPicker("", selection: $colorSettings.backgroundEndColor)
                                                    .labelsHidden()
                                                    .onChange(of: colorSettings.backgroundEndColor) { _ in
                                                        colorSettings.saveColors()
                                                    }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                
                                // 文字色設定
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("文字色")
                                            .dynamicHeadline()
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                        Spacer()
                                        ColorPicker("", selection: $colorSettings.textColor)
                                            .labelsHidden()
                                            .onChange(of: colorSettings.textColor) { _ in
                                                colorSettings.saveColors()
                                            }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                
                                // アクセントカラー設定
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("ボタン色")
                                            .dynamicHeadline()
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                        Spacer()
                                        ColorPicker("", selection: $colorSettings.accentColor)
                                            .labelsHidden()
                                            .onChange(of: colorSettings.accentColor) { _ in
                                                colorSettings.saveColors()
                                            }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                
                                // リセットボタン
                                Button(action: {
                                    colorSettings.resetToDefault()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("デフォルトに戻す")
                                            .dynamicCallout()
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("カラー設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            }
        }
    }
}

struct ColorSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ColorSettingsView()
    }
}
