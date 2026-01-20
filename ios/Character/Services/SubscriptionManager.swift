import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isLoading = false
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var shouldShowBannerAd = true
    @Published var adFrequency: Int = 5

    // テスト用の手動オーバーライド
    @Published var isTestModeEnabled = false
    @Published var testSubscriptionStatus: SubscriptionStatus = .free

    // デバッグ用のAppStorage参照
    @AppStorage("isPremium") private var debugIsPremium: Bool = false

    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private let purchaseManager = PurchaseManager.shared
    private var currentMonitoringUserId: String?

    private init() {
        // PurchaseManagerの状態変化を監視
        Task {
            await purchaseManager.loadProducts()
        }
    }

    enum SubscriptionStatus {
        case free
        case premium
        case unknown
    }

    struct UserSubscriptionData {
        let status: SubscriptionStatus
        let expiresAt: Date?
        let autoRenewal: Bool
        let adSettings: AdSettings

        struct AdSettings {
            let bannerEnabled: Bool
            let videoAdEnabled: Bool
            let lastVideoAdShown: Date?
        }
    }

    // MARK: - Public Methods

    /// ユーザーのサブスクリプション状態を取得・監視開始
    func startMonitoring() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ SubscriptionManager: No authenticated user, cannot start monitoring")
            subscriptionStatus = .unknown
            shouldShowBannerAd = false
            return
        }

        // 既に同じユーザーを監視中の場合はスキップ
        if currentMonitoringUserId == userId, userListener != nil {
            print("✅ Already monitoring user \(userId), skipping duplicate")
            return
        }

        print("🔍 SubscriptionManager: Starting monitoring for user \(userId)")

        // 既存のリスナーを削除（ユーザー切り替え対応）
        stopMonitoring()

        isLoading = true
        currentMonitoringUserId = userId

        // リアルタイム監視開始 - subscription/currentドキュメントを監視
        userListener = db.collection("users").document(userId)
            .collection("subscription").document("current")
            .addSnapshotListener { [weak self] document, error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    print("❌ Subscription monitoring error: \(error.localizedDescription)")
                    self.subscriptionStatus = .free // エラー時は無料扱い
                    self.shouldShowBannerAd = true
                    return
                }

                guard let document = document, document.exists,
                      let data = document.data() else {
                    print("ℹ️ No subscription document found, setting to free")
                    self.subscriptionStatus = .free
                    self.shouldShowBannerAd = true
                    return
                }

                print("✅ Subscription document found: \(data)")
                self.updateSubscriptionFromDocument(data: data)
            }
    }

    /// 監視停止
    func stopMonitoring() {
        userListener?.remove()
        userListener = nil
        currentMonitoringUserId = nil
    }

    /// 手動でサブスクリプション状態を更新
    func refreshSubscriptionStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            subscriptionStatus = .unknown
            shouldShowBannerAd = false
            return
        }

        isLoading = true

        // PurchaseManagerの状態もチェック
        let isPremiumFromPurchase = await purchaseManager.isPremiumUser()

        do {
            let document = try await db.collection("users").document(userId)
                .collection("subscription").document("current").getDocument()

            if document.exists, let data = document.data() {
                updateSubscriptionFromDocument(data: data)
            } else if isPremiumFromPurchase {
                // Firestoreにサブスクリプション情報がない場合、PurchaseManagerの情報を使用
                subscriptionStatus = .premium
                shouldShowBannerAd = false
            } else {
                subscriptionStatus = .free
                shouldShowBannerAd = true
            }
        } catch {
            // エラー時はPurchaseManagerの状態を使用
            subscriptionStatus = isPremiumFromPurchase ? .premium : .free
            shouldShowBannerAd = !isPremiumFromPurchase
        }

        isLoading = false
    }

    /// PurchaseManagerから呼び出される同期版メソッド
    func refreshSubscriptionStatus() {
        Task {
            await refreshSubscriptionStatus()
        }
    }

    /// バナー広告を表示すべきかチェック
    func shouldDisplayBannerAd() -> Bool {
        // DEBUGビルドの場合、AppStorageの値を優先
        #if DEBUG
        if debugIsPremium {
            return false
        }
        #endif

        let currentStatus = isTestModeEnabled ? testSubscriptionStatus : subscriptionStatus

        switch currentStatus {
        case .premium:
            return false
        case .free:
            return shouldShowBannerAd
        case .unknown:
            return false // 不明時は表示しない
        }
    }

    /// 動画広告表示チェック（5回毎）
    func shouldShowVideoAd(chatCount: Int) -> Bool {
        let currentStatus = isTestModeEnabled ? testSubscriptionStatus : subscriptionStatus
        guard currentStatus == .free else { return false }
        guard chatCount > 0 && chatCount % adFrequency == 0 else { return false }
        return true
    }

    // MARK: - Private Methods

    private func updateSubscriptionFromDocument(data: [String: Any]) {
        // subscription/currentドキュメントから直接読み取り
        let status = data["status"] as? String ?? "free"
        let plan = data["plan"] as? String ?? "free"

        print("📊 Subscription data - status: \(status), plan: \(plan)")

        // 期限チェック
        var isValidPremium = false
        if status == "active" || plan == "premium" {
            if let endDateTimestamp = data["end_date"] as? Timestamp {
                let endDate = endDateTimestamp.dateValue()
                isValidPremium = Date() < endDate
                print("📅 Subscription end date: \(endDate), is valid: \(isValidPremium)")
            } else {
                // end_date が null の場合は無期限premium (StoreKitのみの場合)
                isValidPremium = true
                print("♾️ Subscription has no end date (lifetime premium)")
            }
        }

        self.subscriptionStatus = isValidPremium ? .premium : .free

        // プレミアムユーザーは広告を表示しない
        self.shouldShowBannerAd = !isValidPremium

        print("✨ Final subscription status: \(subscriptionStatus), show banner: \(shouldShowBannerAd)")
    }

    // MARK: - Analytics & Usage Tracking

    /// 広告表示をトラッキング
    func trackBannerAdImpression() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let impressionData: [String: Any] = [
            "type": "banner_impression",
            "timestamp": Timestamp(),
            "user_tier": subscriptionStatus == .premium ? "premium" : "free",
            "screen": "home"
        ]

        // ログコレクションに記録（必要に応じて）
        db.collection("ad_analytics").addDocument(data: impressionData)
    }

    /// プレミアムアップグレード推奨情報を取得
    func getUpgradeRecommendation() -> UpgradeRecommendation? {
        guard subscriptionStatus == .free else { return nil }

        return UpgradeRecommendation(
            title: "プレミアムにアップグレード",
            message: "最新AIで高品質なキャラクター体験",
            benefits: [
                "広告完全非表示",
                "最新AIモデル (GPT-4o-2024-11-20)",
                "無制限チャット履歴",
                "より高度な解析",
                "音声生成機能"
            ]
        )
    }

    struct UpgradeRecommendation {
        let title: String
        let message: String
        let benefits: [String]
    }
}

// MARK: - Convenience Extensions

extension SubscriptionManager {
    var isPremium: Bool {
        // DEBUGビルドの場合、AppStorageの値を優先
        #if DEBUG
        if debugIsPremium {
            return true
        }
        #endif

        let currentStatus = isTestModeEnabled ? testSubscriptionStatus : subscriptionStatus
        return currentStatus == .premium
    }

    var isFree: Bool {
        let currentStatus = isTestModeEnabled ? testSubscriptionStatus : subscriptionStatus
        return currentStatus == .free
    }

    var isUnknown: Bool {
        let currentStatus = isTestModeEnabled ? testSubscriptionStatus : subscriptionStatus
        return currentStatus == .unknown
    }

    // MARK: - Test Methods

    /// テストモードの有効/無効を切り替え
    func toggleTestMode() {
        isTestModeEnabled.toggle()
    }

    /// テスト用サブスクリプション状態を切り替え
    func toggleTestSubscription() {
        testSubscriptionStatus = testSubscriptionStatus == .free ? .premium : .free
    }

    /// テスト用サブスクリプション状態を直接設定
    func setTestSubscription(_ status: SubscriptionStatus) {
        testSubscriptionStatus = status
    }

    /// 現在の実効サブスクリプション状態を取得
    var effectiveSubscriptionStatus: SubscriptionStatus {
        return isTestModeEnabled ? testSubscriptionStatus : subscriptionStatus
    }

    /// 状態表示用文字列
    var statusDisplayText: String {
        let effective = effectiveSubscriptionStatus
        let prefix = isTestModeEnabled ? "🧪 テスト: " : ""

        switch effective {
        case .free:
            return "\(prefix)無料ユーザー"
        case .premium:
            return "\(prefix)有料ユーザー"
        case .unknown:
            return "\(prefix)状態不明"
        }
    }
}