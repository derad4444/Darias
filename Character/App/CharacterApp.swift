import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import GoogleMobileAds
import UserNotifications

@main
struct CharacterApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var fontSettings = FontSettingsManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // App Check設定を最初に実行
        configureAppCheck()
        
        // Firebase初期化
        FirebaseApp.configure()
        
    }
    
    private func configureAppCheck() {
        #if DEBUG
        // デバッグビルド：デバッグプロバイダーを使用
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // デバッグトークンをログ出力
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AppCheck.appCheck().token(forcingRefresh: false) { token, error in
                if let token = token {
                } else if let error = error {
                }
            }
        }
        #else
        // 本番リリース：DeviceCheck/App Attestを使用（自動）
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            StartView2()  // アプリロゴ画面のみ表示
                .preferredColorScheme(.light)  // ライトモード固定（ダークモード無効化）
                .environmentObject(authManager)
                .environmentObject(fontSettings)
                .onReceive(fontSettings.$fontFamily) { _ in
                    // フォント変更時にビューを強制更新
                    DispatchQueue.main.async {
                        fontSettings.objectWillChange.send()
                    }
                }
                .onReceive(fontSettings.$fontSize) { _ in
                    // フォントサイズ変更時にビューを強制更新
                    DispatchQueue.main.async {
                        fontSettings.objectWillChange.send()
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        MobileAds.shared.start()
        
        // 通知デリゲートを設定
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // フォアグラウンドで通知を受信した場合の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでもバナー、音、バッジを表示
        completionHandler([.banner, .sound, .badge])
    }
    
    // 通知をタップした場合の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // 通知タップ時の処理を追加可能
        // Notification tapped
        completionHandler()
    }
}
