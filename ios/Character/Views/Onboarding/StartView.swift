import SwiftUI
import FirebaseCore

struct StartView2: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @State private var showMainApp = false
    
    // バージョン自動取得
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "Ver\(version)"
        } else {
            return "Ver1.0.0" // 万一取得できなかった時の予備
        }
    }
    
    var body: some View {
        ZStack {
            // 白固定背景
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280, height: 200)

                Text("画面をタップしてはじめる")
                    .font(.title3)
                    .foregroundColor(.gray)

                Spacer()

                VStack(spacing: 8) {
                    Text("© 2025 DERAD")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 24)
            }
            .padding()
            
            // 🔽 バージョン表記を左上に配置
            VStack {
                HStack {
                    Text(appVersion)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }
                Spacer()
            }
        }
        .onTapGesture {
            showMainApp = true
        }
        .fullScreenCover(isPresented: $showMainApp) {
            // 正常な認証フローでMainTabViewを表示
            RootView()
                .environmentObject(authManager)
        }
    }
}

// プレビュー画面表示
struct StartView2_Previews: PreviewProvider {
    static var previews: some View {
        StartView2()
    }
}
