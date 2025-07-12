import SwiftUI

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
                                errorMessage = error.localizedDescription
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
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthManager())
    }
}
