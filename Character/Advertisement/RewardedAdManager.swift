import GoogleMobileAds
import SwiftUI

class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isReady: Bool = false
    private var rewardedAd: RewardedAd?
    
    // ✅ ここにリワード広告ユニットIDを設定（テストID例）
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = Request()
        RewardedAd.load(
            with: adUnitID,
            request: request,
            completionHandler: { ad, error in
                if let error = error {
                    self.isReady = false
                    return
                }
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isReady = true
            }
        )
    }

    func showAd(from rootViewController: UIViewController, onReward: @escaping () -> Void) {
        guard let ad = rewardedAd else {
            return
        }

        ad.present(from: rootViewController) {
            let reward = ad.adReward
            // Reward received
            onReward()
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadAd()
    }
}
