import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var gender = "未設定"
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    let genderOptions = ["未設定", "男性", "女性"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 上部広告
            // if !isPremium {
            //     BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
            //         .frame(maxWidth: .infinity, maxHeight: 50)
            //         .padding(.top, 8)
            // }
            
            ZStack {
                // ✅ 背景グラデーション
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("アカウント作成")
                        .font(.title)
                        .bold()
                    
                    TextField("名前", text: $name)
                        .dynamicBody()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("メールアドレス", text: $email)
                        .dynamicBody()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("パスワード", text: $password)
                        .dynamicBody()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // ✅ 性別選択（任意）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("性別（任意）")
                            .dynamicCaption()
                            .foregroundColor(.secondary)
                        Picker("性別", selection: $gender) {
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                    
                    Button {
                        authManager.signUp(email: email, password: password, name: name, gender: gender) { result in
                            switch result {
                            case .success():
                                dismiss() // 成功したら画面を閉じる
                            case .failure(let error):
                                errorMessage = getJapaneseErrorMessage(error)
                            }
                        }
                    } label: {
                        Text("アカウント作成")
                            .dynamicButtonText()
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(hex: "#A084CA"))
                    .cornerRadius(12)
                    
                    HStack {
                        Text("既に作成済みの方はこちら")
                            .foregroundColor(.blue)
                            .underline()
                            .onTapGesture {
                                dismiss()
                            }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Error Message Helper

    private func getJapaneseErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError

        // FirebaseAuthのエラーコードで判定
        if nsError.domain == AuthErrorDomain {
            // エラーコードのraw valueで判定
            switch nsError.code {
            case 17008: // invalidEmail
                return "メールアドレスの形式が正しくありません。"
            case 17007: // emailAlreadyInUse
                return "このメールアドレスはすでに使用されています。"
            case 17026: // weakPassword
                return "パスワードは6文字以上で入力してください。"
            case 17020: // networkError
                return "ネットワークエラーが発生しました。接続を確認してください。"
            case 17011: // userNotFound
                return "ユーザーが見つかりません。"
            case 17009: // wrongPassword
                return "パスワードが正しくありません。"
            case 17010: // userDisabled
                return "このアカウントは無効化されています。"
            case 17999: // tooManyRequests
                return "リクエストが多すぎます。しばらく待ってから再度お試しください。"
            case 17006: // operationNotAllowed
                return "この操作は許可されていません。"
            default:
                // その他のエラーは英語メッセージから日本語に変換を試みる
                return translateErrorMessage(error.localizedDescription)
            }
        }

        return translateErrorMessage(error.localizedDescription)
    }

    private func translateErrorMessage(_ message: String) -> String {
        let msg = message.lowercased()

        if msg.contains("badly formatted") || msg.contains("invalid email") {
            return "メールアドレスの形式が正しくありません。"
        } else if msg.contains("already in use") {
            return "このメールアドレスはすでに使用されています。"
        } else if msg.contains("password") && (msg.contains("at least") || msg.contains("weak")) {
            return "パスワードは6文字以上で入力してください。"
        } else if msg.contains("network") {
            return "ネットワークエラーが発生しました。"
        } else {
            return "エラーが発生しました: \(message)"
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthManager())
    }
}
