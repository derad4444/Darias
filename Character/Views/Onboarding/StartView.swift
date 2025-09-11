import SwiftUI
import FirebaseCore

struct StartView1: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @State private var showStartScreen = false

    var body: some View {
        ZStack {
            if showStartScreen {
                StartView2()
            } else {
                ZStack {
                    // スプラッシュ②：明るいグラデ背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()

                    //企業ロゴ
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 180, height: 120)
                        
                        VStack {
                            Image(systemName: "building.2")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Company Logo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .onAppear {
            // 🔴 デバッグ用: すぐにLive2D画面に遷移
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showStartScreen = true
                }
            }
        }
    }
}

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
            // スプラッシュ②：明るいグラデ背景
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 180, height: 120)
                    
                    VStack {
                        Image(systemName: "app.badge")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("App Logo")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Text("画面をタップしてはじめる")
                    .font(.title3)
                    .foregroundColor(.gray)

                Spacer()

                VStack(spacing: 8) {
                    Text("© 2025 DERAD")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    Text("Created with Midjourney")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
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
        .onAppear {
            // 🔴 デバッグ用: 自動的にHomeViewに遷移
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showMainApp = true
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
struct StartView1_Previews: PreviewProvider {
    static var previews: some View {
        StartView1()
    }
}
