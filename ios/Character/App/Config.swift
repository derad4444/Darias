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
        return "ca-app-pub-5851550594315289/8287132245"
        #endif
    }

    /// 設定画面上部バナー
    static var settingsTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5497209577"
        #endif
    }

    /// 設定画面下部バナー
    static var settingsBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/3362000823"
        #endif
    }

    /// カレンダー画面バナー
    static var calendarScreenBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/2539873743"
        #endif
    }

    /// 予定詳細画面バナー
    static var scheduleDetailBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/8127350145"
        #endif
    }

    /// 予定編集画面上部バナー
    static var scheduleEditTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/1805376571"
        #endif
    }

    /// 予定編集画面下部バナー
    static var scheduleEditBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/2670191098"
        #endif
    }

    /// 予定追加画面上部バナー
    static var scheduleAddTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/6566748666"
        #endif
    }

    /// 予定追加画面下部バナー
    static var scheduleAddBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/3034805563"
        #endif
    }

    /// チャット履歴画面バナー
    static var chatHistoryBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/3683889865"
        #endif
    }

    /// キャラクター詳細画面上部バナー
    static var characterDetailTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/2370808193"
        #endif
    }

    /// キャラクター詳細画面下部バナー
    static var characterDetailBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5501186800"
        #endif
    }

    /// 日記詳細画面上部バナー
    static var diaryDetailTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/1226792077" // 本番用ID（要設定）
        #endif
    }

    /// 日記詳細画面下部バナー
    static var diaryDetailBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/1046936476" // 本番用ID（要設定）
        #endif
    }

    /// メモ画面上部バナー
    static var memoTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/8134270760"
        #endif
    }

    /// メモ画面下部バナー
    static var memoBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/6730400193"
        #endif
    }

    /// タスク画面上部バナー
    static var taskTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/4442437769"
        #endif
    }

    /// タスク画面下部バナー
    static var taskBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/9412511653"
        #endif
    }

    /// メモ追加画面上部バナー
    static var memoAddTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5138116921"
        #endif
    }

    /// メモ追加画面下部バナー
    static var memoAddBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/6754558720"
        #endif
    }

    /// タスク追加画面上部バナー
    static var taskAddTopBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/5441477059"
        #endif
    }

    /// タスク追加画面下部バナー
    static var taskAddBottomBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/XXXXXXXXXX" // 本番用ID（要設定）
        #endif
    }

    // MARK: - Rewarded Ad Unit ID

    /// リワード動画広告
    static var rewardedAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/5224354917" // テスト用ID
        #else
        return "ca-app-pub-5851550594315289/8397160491"
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
