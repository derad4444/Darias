import SwiftUI
import MessageUI

struct OptionView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var fontSettings = FontSettingsManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isPremium") var isPremium: Bool = false
    @AppStorage("bgmVolume") var bgmVolume: Double = 0.5
    @AppStorage("characterVolume") var characterVolume: Double = 0.8
    
    @State private var showFontSettings = false
    @State private var showColorSettings = false
    @State private var showTagSettings = false
    @State private var showContactView = false
    @State private var showMailCompose = false
    @State private var showMailUnavailableAlert = false
    @State private var showPremiumUpgrade = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmation = false
    
    private var dynamicListHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaTop: CGFloat = 47
        let safeAreaBottom: CGFloat = 34
        let navigationBarHeight: CGFloat = 44
        return screenHeight - safeAreaTop - safeAreaBottom - navigationBarHeight - 20
    }
    
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
        .sheet(isPresented: $showContactView) {
            NavigationStack {
                ContactView()
            }
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                recipients: ["darias.app4@gmail.com"],
                subject: "Dariasアプリについて"
            )
        }
        .onAppear {
            subscriptionManager.startMonitoring()
        }
        .onDisappear {
            subscriptionManager.stopMonitoring()
        }
        .alert("メール送信不可", isPresented: $showMailUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("お使いのデバイスでメール送信が利用できません。設定からメールアカウントをご確認ください。")
        }
        .alert("アカウント削除", isPresented: $showDeleteAccountAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除する", role: .destructive) {
                showDeleteConfirmation = true
            }
        } message: {
            Text("アカウントを削除すると、すべてのデータが完全に削除され、復元できなくなります。本当に削除しますか?")
        }
        .alert("最終確認", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("完全に削除", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("この操作は取り消せません。アカウントとすべてのデータを完全に削除しますか?")
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
            // 1つ目のバナー広告（一番上）
            if subscriptionManager.shouldDisplayBannerAd() {
                firstBannerAdSection
            }

            // プレミアムセクション（広告の下に表示）
            if subscriptionManager.shouldDisplayBannerAd() {
                premiumUpgradeSection
            }

            // 開発用：プレミアム切り替えスイッチ
            #if DEBUG
            debugPremiumToggleSection
            #endif

            volumeSettingsSection
            colorSettingsSection
            tagSettingsSection
            socialAndSupportSection

            // 2つ目のバナー広告（ログアウトボタンの上）
            if subscriptionManager.shouldDisplayBannerAd() {
                secondBannerAdSection
            }

            logoutSection
            deleteAccountSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(height: dynamicListHeight)
        .clipped()
    }

    // MARK: - デバッグ用プレミアム切り替え

    private var debugPremiumToggleSection: some View {
        Section(header: sectionHeader("🛠️ 開発用")) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: isPremium ? "crown.fill" : "crown")
                        .foregroundColor(isPremium ? .yellow : .gray)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("プレミアム機能テスト")
                            .dynamicBody()
                            .fontWeight(.semibold)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        Text(isPremium ? "プレミアムモード（広告なし）" : "無料モード（広告あり）")
                            .dynamicCaption()
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: $isPremium)
                        .labelsHidden()
                        .onChange(of: isPremium) { newValue in
                            // 変更を即座に反映させる
                            subscriptionManager.objectWillChange.send()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPremium ? Color.yellow.opacity(0.1) : Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isPremium ? Color.yellow.opacity(0.5) : colorSettings.getCurrentTextColor().opacity(0.2),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    // MARK: - プレミアムアップグレードセクション

    private var premiumUpgradeSection: some View {
        Section {
            Button(action: { showPremiumUpgrade = true }) {
                HStack(spacing: 16) {
                    // プレミアムアイコン
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("プレミアムにアップグレード")
                            .dynamicHeadline()
                            .fontWeight(.semibold)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        Text("広告なし・無制限チャット・特別機能")
                            .dynamicCaption()
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("月額980円")
                            .dynamicBody()
                            .fontWeight(.bold)
                            .foregroundColor(colorSettings.getCurrentAccentColor())

                        Text("7日間無料")
                            .dynamicCaption()
                            .foregroundColor(.green)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorSettings.getCurrentAccentColor().opacity(0.05),
                                    colorSettings.getCurrentAccentColor().opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.6), .orange.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // MARK: - バナー広告セクション

    private var firstBannerAdSection: some View {
        Section {
            BannerAdView(adUnitID: Config.settingsTopBannerAdUnitID)
                .frame(height: 50)
                .background(Color.clear)
                .onAppear {
                    subscriptionManager.trackBannerAdImpression()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private var secondBannerAdSection: some View {
        Section {
            BannerAdView(adUnitID: Config.settingsBottomBannerAdUnitID)
                .frame(height: 50)
                .background(Color.clear)
                .onAppear {
                    subscriptionManager.trackBannerAdImpression()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private var volumeSettingsSection: some View {
        Section(header: sectionHeader("音量設定")) {
            VStack(spacing: 20) {
                bgmVolumeControl
                characterVolumeControl
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(colorSettings.getCurrentTextColor().opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
    
    
    private var tagSettingsSection: some View {
        Section() {
            Button(action: {
                showTagSettings = true
            }) {
                settingsRowContent(
                    title: "タグ管理",
                    subtitle: "予定のタグを作成・編集"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorSettings.getCurrentTextColor().opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
    
    private var colorSettingsSection: some View {
        Section() {
            Button(action: {
                showColorSettings = true
            }) {
                settingsRowContent(
                    title: "背景色・文字色",
                    subtitle: colorSettings.useGradient ? "グラデーション" : "一色"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorSettings.getCurrentTextColor().opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
    
    private var socialAndSupportSection: some View {
        Section() {
            VStack(spacing: 0) {
                // Instagram
                Button {
                    openInstagram()
                } label: {
                    HStack {
                        Image(systemName: "camera.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)
                        Text("公式Instagram")
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentTextColor())
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .background(colorSettings.getCurrentTextColor().opacity(0.2))

                // お問い合わせ
                Button {
                    showContactView = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("お問い合わせ")
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentTextColor())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(colorSettings.getCurrentTextColor().opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
    
    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            showMailCompose = true
        } else {
            showMailUnavailableAlert = true
        }
    }

    private func openInstagram() {
        let instagramURL = "instagram://user?username=ryosuke_4444"
        let webURL = "https://www.instagram.com/ryosuke_4444"

        if let url = URL(string: instagramURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: webURL) {
            UIApplication.shared.open(url)
        }
    }

    private var deleteAccountSection: some View {
        Section {
            Button {
                showDeleteAccountAlert = true
            } label: {
                Text("アカウントを削除")
                    .dynamicBody()
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
    }

    private func deleteAccount() {
        Task {
            do {
                // Firestoreからユーザーデータを削除
                if let userId = authManager.user?.uid {
                    try await FirestoreManager.shared.deleteUserData(userId: userId)
                }

                // Firebase Authenticationからアカウントを削除
                try await authManager.deleteAccount()

                // ログアウトして画面を閉じる
                dismiss()
            } catch {
                print("アカウント削除エラー: \(error.localizedDescription)")
            }
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
