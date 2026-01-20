import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ContactView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var fontSettings = FontSettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: ContactCategory = .other
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let maxMessageLength = 1000

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                navigationHeader
                mainContent
            }
        }
        .navigationBarHidden(true)
        .alert("送信完了", isPresented: $showSuccessAlert) {
            Button("確認", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("問い合わせメールを送信しました。\n\n・確認メールが届いているかご確認ください\n・迷惑メールフォルダもチェックしてください\n・通常2-3営業日以内に返答いたします")
        }
        .alert("送信エラー", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var backgroundView: some View {
        colorSettings.getCurrentBackgroundGradient()
            .ignoresSafeArea()
    }

    private var navigationHeader: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .font(.title2)
            }

            Spacer()

            Text("お問い合わせ")
                .dynamicTitle3()
                .foregroundColor(colorSettings.getCurrentTextColor())

            Spacer()

            Button(action: {
                sendContact()
            }) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("送信")
                        .dynamicBody()
                        .foregroundColor(isFormValid ? colorSettings.getCurrentAccentColor() : colorSettings.getCurrentTextColor().opacity(0.5))
                }
            }
            .disabled(!isFormValid || isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                categorySection
                messageSection
                characterCountSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お問い合わせ種類")
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .fontWeight(.medium)

            Menu {
                ForEach(ContactCategory.allCases, id: \.self) { category in
                    Button(category.displayName) {
                        selectedCategory = category
                    }
                }
            } label: {
                HStack {
                    Text(selectedCategory.displayName)
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorSettings.getCurrentTextColor().opacity(0.1))
                )
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お問い合わせ内容")
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .fontWeight(.medium)

            TextEditor(text: $messageText)
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorSettings.getCurrentTextColor().opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorSettings.getCurrentAccentColor().opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var characterCountSection: some View {
        HStack {
            Spacer()
            Text("\(messageText.count) / \(maxMessageLength)")
                .dynamicCaption()
                .foregroundColor(
                    messageText.count > maxMessageLength
                        ? .red
                        : colorSettings.getCurrentTextColor().opacity(0.7)
                )
        }
    }

    private var isFormValid: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        messageText.count <= maxMessageLength
    }

    private func sendContact() {
        guard isFormValid else { return }

        isLoading = true

        let deviceInfo = getDeviceInfo()
        let contactId = UUID().uuidString

        let contactData: [String: Any] = [
            "userId": authManager.userId,
            "userEmail": "",
            "userName": "",
            "category": selectedCategory.rawValue,
            "categoryDisplay": selectedCategory.displayName,
            "subject": selectedCategory.emailSubject,
            "message": messageText.trimmingCharacters(in: .whitespacesAndNewlines),
            "status": "pending",
            "createdAt": Timestamp(),
            "adminEmailSent": false,
            "userEmailSent": false,
            "deviceInfo": deviceInfo
        ]

        let db = Firestore.firestore()

        db.collection("users").document(authManager.userId).getDocument { userDoc, error in
            if let error = error {
                self.handleError("ユーザー情報の取得に失敗しました: \(error.localizedDescription)")
                return
            }

            guard let userData = userDoc?.data(),
                  let userEmail = userData["email"] as? String,
                  let userName = userData["name"] as? String else {
                self.handleError("ユーザー情報が見つかりません")
                return
            }

            var updatedContactData = contactData
            updatedContactData["userEmail"] = userEmail
            updatedContactData["userName"] = userName

            db.collection("contacts").document(contactId).setData(updatedContactData) { error in
                self.isLoading = false

                if let error = error {
                    self.handleError("お問い合わせの送信に失敗しました: \(error.localizedDescription)")
                } else {
                    self.showSuccessAlert = true
                }
            }
        }
    }

    private func getDeviceInfo() -> [String: String] {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"

        return [
            "appVersion": "\(appVersion) (\(buildNumber))",
            "iosVersion": device.systemVersion,
            "deviceModel": device.model,
            "deviceName": device.name
        ]
    }

    private func handleError(_ message: String) {
        isLoading = false
        errorMessage = message
        showErrorAlert = true
    }
}

enum ContactCategory: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case usage = "usage"
    case account = "account"
    case personality = "personality"
    case calendar = "calendar"
    case character = "character"
    case premium = "premium"
    case other = "other"

    var displayName: String {
        switch self {
        case .bug: return "バグ報告・不具合"
        case .feature: return "機能要望・改善提案"
        case .usage: return "使い方・操作方法"
        case .account: return "アカウント・ログイン"
        case .personality: return "AI性格診断について"
        case .calendar: return "カレンダー・予定管理"
        case .character: return "キャラクター機能"
        case .premium: return "プレミアム機能・課金"
        case .other: return "その他"
        }
    }

    var emailSubject: String {
        return "【DARIAS】\(displayName)"
    }
}

#Preview {
    NavigationStack {
        ContactView()
            .environmentObject(AuthManager())
    }
}