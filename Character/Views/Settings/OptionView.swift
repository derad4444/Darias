import SwiftUI

struct OptionView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var fontSettings = FontSettingsManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isPremium") var isPremium: Bool = false
    @AppStorage("bgmVolume") var bgmVolume: Double = 0.5
    @AppStorage("characterVolume") var characterVolume: Double = 0.8
    
    @State private var showFontSettings = false
    @State private var showColorSettings = false
    @State private var showTagSettings = false
    
    var body: some View {
        ZStack {
            backgroundView
            mainContentView
        }
        .navigationTitle("オプション")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showFontSettings) {
            FontSettingsView()
        }
        .sheet(isPresented: $showColorSettings) {
            ColorSettingsView()
        }
        .sheet(isPresented: $showTagSettings) {
            TagSettingsView()
        }
    }
    
    private var backgroundView: some View {
        colorSettings.getCurrentBackgroundGradient()
            .ignoresSafeArea()
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            settingsListView
        }
    }
    
    private var settingsListView: some View {
        List {
            volumeSettingsSection
            appearanceSettingsSection
            logoutSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(height: 720)
        .clipped()
    }
    
    private var volumeSettingsSection: some View {
        Section(header: sectionHeader("音量設定")) {
            VStack(spacing: 20) {
                bgmVolumeControl
                characterVolumeControl
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }
    
    private var bgmVolumeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BGM音量")
                .dynamicCallout()
                .foregroundColor(colorSettings.getCurrentTextColor())
            Slider(value: $bgmVolume, in: 0...1, step: 0.01, onEditingChanged: { _ in
                BGMPlayer.shared.updateVolume(bgmVolume)
            })
            .accentColor(colorSettings.getCurrentAccentColor())
            Text("音量: \(Int(bgmVolume * 100))%")
                .dynamicCaption()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
        }
    }
    
    private var characterVolumeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("キャラクター音声")
                .dynamicCallout()
                .foregroundColor(colorSettings.getCurrentTextColor())
            Slider(value: $characterVolume, in: 0...1, step: 0.01)
                .accentColor(colorSettings.getCurrentAccentColor())
            Text("音量: \(Int(characterVolume * 100))%")
                .dynamicCaption()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
        }
    }
    
    private var appearanceSettingsSection: some View {
        Group {
            fontSettingsRow
            tagSettingsRow
            colorSettingsRow
        }
    }
    
    private var fontSettingsRow: some View {
        Section(header: sectionHeader("フォント設定")) {
            Button(action: {
                showFontSettings = true
            }) {
                settingsRowContent(
                    title: "フォント",
                    subtitle: "\(fontSettings.fontFamily.displayName) - \(fontSettings.fontSize.displayName)"
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
    }
    
    private var tagSettingsRow: some View {
        Section(header: sectionHeader("タグ設定")) {
            Button(action: {
                showTagSettings = true
            }) {
                settingsRowContent(
                    title: "タグ管理",
                    subtitle: "予定のタグを作成・編集"
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
    }
    
    private var colorSettingsRow: some View {
        Section(header: sectionHeader("カラー設定")) {
            Button(action: {
                showColorSettings = true
            }) {
                settingsRowContent(
                    title: "背景色・文字色",
                    subtitle: colorSettings.useGradient ? "グラデーション" : "一色"
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
    }
    
    private var logoutSection: some View {
        Section {
            Button {
                authManager.signOut()
                dismiss()
            } label: {
                Text("ログアウト")
                    .dynamicBody()
                    .foregroundColor(.red)
            }
            .padding()
        }
        .listRowBackground(Color.clear)
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                // 閉じる処理
            }) {
                Image(systemName: "xmark")
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .dynamicCallout()
            .foregroundColor(colorSettings.getCurrentTextColor())
    }
    
    private func settingsRowContent(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .dynamicBody()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                Text(subtitle)
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                .font(FontSettingsManager.shared.font(size: 12, weight: .regular))
        }
    }
}

struct OptionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OptionView()
        }
    }
}