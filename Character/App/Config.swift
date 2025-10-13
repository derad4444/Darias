import Foundation

// MARK: - Configuration Management
struct Config {
    private static let bundle = Bundle.main
    
    // MARK: - App Check Configuration
    static var appCheckDebugToken: String? {
        #if DEBUG
        return bundle.object(forInfoDictionaryKey: "APP_CHECK_DEBUG_TOKEN") as? String
        #else
        return nil // 本番環境ではデバッグトークンを無効化
        #endif
    }
    
    // MARK: - AdMob Configuration

    /// AdMob アプリID
    static var adMobApplicationID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544~1458002511" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289~6221721976" // 本番用ID
        #endif
    }

    // MARK: - Banner Ad Unit IDs

    /// ホーム画面バナー
    static var homeScreenBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/4098604324"
        #endif
    }

    /// 設定画面上部バナー
    static var settingsTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5277429400"
        #endif
    }

    /// 設定画面下部バナー
    static var settingsBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/3392027317"
        #endif
    }

    /// カレンダー画面バナー
    static var calendarScreenBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/3964347732"
        #endif
    }

    /// 予定詳細画面バナー
    static var scheduleDetailBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/8452782303"
        #endif
    }

    /// 予定編集画面上部バナー
    static var scheduleEditTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5826618960"
        #endif
    }

    /// 予定編集画面下部バナー
    static var scheduleEditBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/4993841454"
        #endif
    }

    /// 予定追加画面上部バナー
    static var scheduleAddTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/1338184394"
        #endif
    }

    /// 予定追加画面下部バナー
    static var scheduleAddBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5028542613"
        #endif
    }

    /// チャット履歴画面バナー
    static var chatHistoryBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/1045065575"
        #endif
    }

    /// キャラクター詳細画面上部バナー
    static var characterDetailTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/3715460944"
        #endif
    }

    /// キャラクター詳細画面下部バナー
    static var characterDetailBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/1066721657"
        #endif
    }

    // MARK: - Rewarded Ad Unit ID

    /// リワード動画広告
    static var rewardedAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/5224354917" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5095991225"
        #endif
    }
    
    // MARK: - Build Configuration
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isProductionBuild: Bool {
        return !isDebugBuild
    }
}