import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @AppStorage("scheduleNotificationEnabled") private var scheduleNotificationEnabled: Bool = true
    @AppStorage("diaryNotificationEnabled") private var diaryNotificationEnabled: Bool = true

    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            // 背景グラデーション
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // カスタムヘッダー
                headerSection

                // 通知設定リスト
                settingsListView
            }
        }
        .alert("通知許可が必要です", isPresented: $showPermissionAlert) {
            Button("設定を開く", role: .none) {
                openNotificationSettings()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("通知を受け取るには、デバイスの設定から通知を許可してください。")
        }
        .onAppear {
            checkNotificationPermission()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(colorSettings.getCurrentTextColor())
            }
            .padding(.leading, 16)

            Spacer()

            Text("通知設定")
                .dynamicTitle3()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .fontWeight(.semibold)

            Spacer()

            // バランス調整用の透明ボタン
            Color.clear
                .frame(width: 44, height: 44)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(
            Color.white.opacity(0.1)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Settings List

    private var settingsListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 通知許可状態
                notificationPermissionSection

                // 予定の通知
                scheduleNotificationSection

                // 日記の通知
                diaryNotificationSection

                // 説明セクション
                infoSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Permission Section

    private var notificationPermissionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: NotificationManager.shared.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(NotificationManager.shared.isAuthorized ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NotificationManager.shared.isAuthorized ? "通知が許可されています" : "通知が許可されていません")
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .fontWeight(.semibold)

                    Text(NotificationManager.shared.isAuthorized ? "通知を受け取ることができます" : "デバイスの設定から通知を許可してください")
                        .dynamicCaption()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                }

                Spacer()

                if !NotificationManager.shared.isAuthorized {
                    Button {
                        openNotificationSettings()
                    } label: {
                        Text("設定")
                            .dynamicCaption()
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorSettings.getCurrentAccentColor().opacity(0.1))
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                NotificationManager.shared.isAuthorized ? Color.green.opacity(0.3) : Color.orange.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    // MARK: - Schedule Notification Section

    private var scheduleNotificationSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $scheduleNotificationEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("予定の通知")
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentTextColor())
                            .fontWeight(.semibold)

                        Text("予定の開始時刻前に通知")
                            .dynamicCaption()
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: colorSettings.getCurrentAccentColor()))
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .onChange(of: scheduleNotificationEnabled) { newValue in
                if newValue && !NotificationManager.shared.isAuthorized {
                    scheduleNotificationEnabled = false
                    showPermissionAlert = true
                }
            }
        }
    }

    // MARK: - Diary Notification Section

    private var diaryNotificationSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $diaryNotificationEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("日記の通知")
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentTextColor())
                            .fontWeight(.semibold)

                        Text("毎日23:55に日記作成を通知")
                            .dynamicCaption()
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: colorSettings.getCurrentAccentColor()))
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .onChange(of: diaryNotificationEnabled) { newValue in
                if newValue && !NotificationManager.shared.isAuthorized {
                    diaryNotificationEnabled = false
                    showPermissionAlert = true
                } else {
                    updateDiaryNotification(enabled: newValue)
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                Text("通知について")
                    .dynamicCallout()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("• 予定の通知：各予定に設定した時刻に通知されます")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))

                Text("• 日記の通知：キャラクターが日記を書いたことを毎日お知らせします")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))

                Text("• 通知をオフにしても、アプリ内で予定や日記を確認できます")
                    .dynamicCaption()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Functions

    private func checkNotificationPermission() {
        NotificationManager.shared.checkAuthorizationStatus()
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func updateDiaryNotification(enabled: Bool) {
        if enabled {
            // 日記通知を再スケジュール
            if !authManager.characterId.isEmpty {
                // キャラクター名を取得して通知をスケジュール
                let db = authManager.db
                db.collection("users").document(authManager.userId)
                    .collection("characters").document(authManager.characterId)
                    .getDocument { document, error in
                        if let data = document?.data() {
                            let characterName = data["name"] as? String ?? "キャラクター"
                            NotificationManager.shared.scheduleDailyDiaryNotification(
                                characterName: characterName,
                                characterId: authManager.characterId,
                                userId: authManager.userId
                            )
                        }
                    }
            }
        } else {
            // 日記通知をキャンセル
            if !authManager.characterId.isEmpty {
                NotificationManager.shared.cancelDailyDiaryNotification(characterId: authManager.characterId)
            }
        }
    }
}

#Preview {
    NotificationPreferencesView()
        .environmentObject(AuthManager())
}
