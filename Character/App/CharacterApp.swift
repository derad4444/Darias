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
        // Firebase初期化
        FirebaseApp.configure()

        // App Check設定（デバッグ・本番を自動切り替え）
        configureAppCheck()
    }
    
    private func configureAppCheck() {
        #if DEBUG
        // 開発環境ではデバッグプロバイダーを使用
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #else
        // 本番環境ではApp Attestationプロバイダーを使用
        if #available(iOS 14.0, *) {
            let providerFactory = AppAttestProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
        } else {
            // iOS 14未満の場合はデバイスチェックプロバイダーを使用
            let providerFactory = DeviceCheckProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            StartView1()  // ← 起動ビュー名に合わせてください
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
        print("通知がタップされました: \(response.notification.request.content.title)")
        completionHandler()
    }
}
