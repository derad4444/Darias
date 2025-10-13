import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showSignUp = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 上部広告
            // if !isPremium {
            //     BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
            //         .frame(maxWidth: .infinity, maxHeight: 50)
            //         .padding(.top, 8)
            // }
            
            ZStack {
                // 背景グラデーション（ラベンダー→ベージュ）
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("ログイン")
                        .dynamicTitle()
                        .bold()

                    TextField("メールアドレス", text: $email)
                        .dynamicBody()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("パスワード", text: $password)
                        .dynamicBody()
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .dynamicCaption()
                            .foregroundColor(.red)
                    }

                    Button {
                        authManager.signIn(email: email, password: password) { result in
                            switch result {
                            case .success():
                                // 成功時の処理
                                break
                            case .failure(let error):
                                errorMessage = getJapaneseErrorMessage(error)
                            }
                        }
                    } label: {
                        Text("ログイン")
                            .dynamicButtonText()
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(hex: "#A084CA"))
                    .cornerRadius(12)
                    
                    HStack {
                        Text("初めての方はこちら")
                            .dynamicCallout()
                            .foregroundColor(.blue)
                            .underline()
                            .onTapGesture {
                                showSignUp = true
                            }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authManager)
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
            case 17004: // invalidCredential
                return "メールアドレスまたはパスワードが正しくありません。"
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
        } else if msg.contains("user not found") || msg.contains("no user") {
            return "ユーザーが見つかりません。"
        } else if msg.contains("wrong password") || msg.contains("invalid credential") {
            return "メールアドレスまたはパスワードが正しくありません。"
        } else if msg.contains("network") {
            return "ネットワークエラーが発生しました。"
        } else if msg.contains("too many requests") {
            return "リクエストが多すぎます。しばらく待ってから再度お試しください。"
        } else {
            return "エラーが発生しました: \(message)"
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthManager())
    }
}
