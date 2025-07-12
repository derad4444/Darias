import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var gender = "男性"
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    let genderOptions = ["男性", "女性"]
    
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
                    
                    // ✅ 性別選択
                    Picker("性別", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    
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
                                let msg = error.localizedDescription
                                if msg.contains("badly formatted") {
                                    errorMessage = "メールアドレスの形式が正しくありません。"
                                } else if msg.contains("already in use") {
                                    errorMessage = "このメールアドレスはすでに使用されています。"
                                } else if msg.contains("Password should be at least") {
                                    errorMessage = "パスワードは6文字以上で入力してください。"
                                } else {
                                    errorMessage = msg
                                }
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
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthManager())
    }
}
