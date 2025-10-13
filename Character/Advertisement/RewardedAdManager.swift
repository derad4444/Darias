import GoogleMobileAds
import SwiftUI

class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isReady: Bool = false
    private var rewardedAd: RewardedAd?
    
    // リワード広告ユニットID
    private let adUnitID = Config.rewardedAdUnitID

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
        guard let ad = rewardedAd, isReady else {
            loadAd()
            return
        }

        ad.present(from: rootViewController) {
            let reward = ad.adReward
            // Reward received
            onReward()
        }
    }

    // MARK: - FullScreenContentDelegate Methods

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        loadAd()
    }
}
