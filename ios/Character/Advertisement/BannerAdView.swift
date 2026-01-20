import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    // 呼び出し側から広告IDを受け取るよう変更
    let adUnitID: String

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        // グラデーション背景を追加
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.929, green: 0.902, blue: 0.949, alpha: 1.0).cgColor, // #EDE6F2
            UIColor(red: 0.976, green: 0.965, blue: 0.941, alpha: 1.0).cgColor  // #F9F6F0
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        containerView.layer.addSublayer(gradientLayer)
        
        // バナー広告を作成
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        banner.load(Request())
        banner.backgroundColor = UIColor.clear
        
        // バナーをコンテナに追加
        containerView.addSubview(banner)
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            banner.widthAnchor.constraint(equalToConstant: 320),
            banner.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // グラデーションレイヤーのフレームを更新
        DispatchQueue.main.async {
            if let gradientLayer = uiView.layer.sublayers?.first as? CAGradientLayer {
                gradientLayer.frame = uiView.bounds
            }
        }
    }
}
