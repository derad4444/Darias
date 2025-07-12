import Foundation

// MARK: - Configuration Management
struct Config {
    private static let bundle = Bundle.main
    
    // MARK: - App Check Configuration
    static var appCheckDebugToken: String {
        guard let token = bundle.object(forInfoDictionaryKey: "APP_CHECK_DEBUG_TOKEN") as? String else {
            fatalError("APP_CHECK_DEBUG_TOKEN not found in Info.plist")
        }
        return token
    }
    
    // MARK: - AdMob Configuration
    static var adMobBannerAdUnitID: String {
        guard let adUnitID = bundle.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String else {
            return "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        }
        return adUnitID
    }
    
    static var adMobRewardedAdUnitID: String {
        guard let adUnitID = bundle.object(forInfoDictionaryKey: "ADMOB_REWARDED_AD_UNIT_ID") as? String else {
            return "ca-app-pub-3940256099942544/5224354917" // テスト用ID
        }
        return adUnitID
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