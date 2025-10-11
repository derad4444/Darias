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
        print("🔄 リワード広告の読み込みを開始...")
        let request = Request()
        RewardedAd.load(
            with: adUnitID,
            request: request,
            completionHandler: { ad, error in
                if let error = error {
                    print("❌ リワード広告の読み込み失敗: \(error.localizedDescription)")
                    self.isReady = false
                    return
                }
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isReady = true
                print("✅ リワード広告の読み込み成功")
            }
        )
    }

    func showAd(from rootViewController: UIViewController, onReward: @escaping () -> Void) {
        guard let ad = rewardedAd, isReady else {
            print("⚠️ リワード広告がまだ読み込まれていません。再読み込みします...")
            loadAd()
            return
        }

        print("✅ リワード広告を表示します")
        ad.present(from: rootViewController) {
            let reward = ad.adReward
            print("✅ リワード広告視聴完了: \(reward.amount) \(reward.type)")
            // Reward received
            onReward()
        }
    }

    // MARK: - FullScreenContentDelegate Methods

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("📱 リワード広告が閉じられました")
        loadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ リワード広告の表示に失敗: \(error.localizedDescription)")
        loadAd()
    }
}
