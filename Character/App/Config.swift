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
    static var adMobBannerAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        #else
        guard let adUnitID = bundle.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String else {
            fatalError("ADMOB_BANNER_AD_UNIT_ID not found in Info.plist for production build")
        }
        return adUnitID
        #endif
    }

    static var adMobRewardedAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/5224354917" // テスト用ID
        #else
        guard let adUnitID = bundle.object(forInfoDictionaryKey: "ADMOB_REWARDED_AD_UNIT_ID") as? String else {
            fatalError("ADMOB_REWARDED_AD_UNIT_ID not found in Info.plist for production build")
        }
        return adUnitID
        #endif
    }

    static var adMobApplicationID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544~1458002511" // テスト用ID
        #else
        guard let appID = bundle.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String,
              !appID.contains("3940256099942544") else { // テストIDでないことを確認
            fatalError("Production AdMob Application ID not set in Info.plist")
        }
        return appID
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