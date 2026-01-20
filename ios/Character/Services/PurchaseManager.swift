import StoreKit
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var purchaseError: String?

    private let productIDs = ["com.character.premium.monthly"]
    private var updates: Task<Void, Never>? = nil
    private var appStateObserver: NSObjectProtocol?

    private let db = Firestore.firestore()

    // 最後にレシート検証を実行した日付を保存
    @AppStorage("lastReceiptValidationDate") private var lastReceiptValidationDate: Double = 0

    private init() {
        updates = observeTransactionUpdates()
        setupAppStateObserver()
    }

    deinit {
        updates?.cancel()
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadProducts() async {
        print("🛒 PurchaseManager: Loading products...")
        isLoading = true
        purchaseError = nil

        do {
            products = try await Product.products(for: productIDs)

            // 商品が取得できなかった場合の明示的なエラー
            if products.isEmpty {
                purchaseError = "アプリ内課金商品が見つかりませんでした。しばらく時間をおいてから再度お試しください。"
                Logger.error("No products found for IDs: \(productIDs)", category: Logger.subscription)
            } else {
                Logger.success("Successfully loaded \(products.count) product(s)", category: Logger.subscription)
                print("✅ PurchaseManager: Loaded \(products.count) product(s)")
            }

            await checkPurchasedProducts()
        } catch {
            purchaseError = "商品の読み込みに失敗しました: \(error.localizedDescription)"
            Logger.error("Failed to load products", category: Logger.subscription, error: error)
            print("❌ PurchaseManager: Failed to load products - \(error)")
        }

        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            Logger.info("Starting purchase for product: \(product.id)", category: Logger.subscription)
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                Logger.success("Purchase successful: \(transaction.productID)", category: Logger.subscription)
                await handleSuccessfulPurchase(transaction)
                await transaction.finish()
                isLoading = false
                return true

            case .userCancelled:
                purchaseError = "購入がキャンセルされました"
                Logger.info("Purchase cancelled by user", category: Logger.subscription)
                isLoading = false
                return false

            case .pending:
                purchaseError = "購入が保留中です。承認後に自動的に処理されます。"
                Logger.info("Purchase pending approval", category: Logger.subscription)
                isLoading = false
                return false

            @unknown default:
                purchaseError = "不明なエラーが発生しました"
                Logger.error("Unknown purchase result", category: Logger.subscription)
                isLoading = false
                return false
            }
        } catch {
            purchaseError = "購入に失敗しました: \(error.localizedDescription)"
            Logger.error("Purchase failed", category: Logger.subscription, error: error)
            isLoading = false
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await checkPurchasedProducts()
        } catch {
            purchaseError = "購入の復元に失敗しました: \(error.localizedDescription)"
            Logger.error("Restore purchases failed", category: Logger.subscription, error: error)
        }

        isLoading = false
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [unowned self] in
            for await verification in StoreKit.Transaction.updates {
                do {
                    let transaction = try checkVerified(verification)
                    await handleSuccessfulPurchase(transaction)
                    await transaction.finish()
                } catch {
                    Logger.error("Transaction update failed", category: Logger.subscription, error: error)
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func checkPurchasedProducts() async {
        print("🔍 PurchaseManager: Checking purchased products...")
        var purchasedIDs: Set<String> = []
        var hasRevocation = false

        for await verification in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)

                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                    print("✅ PurchaseManager: Found active entitlement - \(transaction.productID)")
                } else {
                    print("⚠️ PurchaseManager: Transaction revoked at \(transaction.revocationDate!) - \(transaction.productID)")
                    hasRevocation = true
                }
            } catch {
                Logger.error("Failed to verify transaction", category: Logger.subscription, error: error)
                print("❌ PurchaseManager: Failed to verify transaction - \(error)")
            }
        }

        self.purchasedProductIDs = purchasedIDs
        print("📦 PurchaseManager: Total purchased products: \(purchasedIDs.count)")
        print("🎫 PurchaseManager: Purchased IDs: \(purchasedIDs)")

        // Firestoreのサブスクリプション状態を更新
        await updateSubscriptionStatus(hasRevocation: hasRevocation)
    }

    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        purchasedProductIDs.insert(transaction.productID)
        await updateSubscriptionStatus(hasRevocation: false)

        // Firebase Functionsでレシート検証
        await validateReceiptWithFirebase(transaction)
    }

    private func updateSubscriptionStatus(hasRevocation: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ PurchaseManager: No authenticated user, cannot update subscription")
            return
        }

        let isPremium = !purchasedProductIDs.isEmpty
        print("💾 PurchaseManager: Updating subscription status for user \(userId)")
        print("👑 PurchaseManager: isPremium = \(isPremium)")

        // 手動テスト用フラグをチェック
        do {
            let docRef = db.collection("users").document(userId)
                .collection("subscription").document("current")
            let document = try await docRef.getDocument()

            // Firestoreのデータを取得
            let firestoreData = document.data()

            if firestoreData == nil {
                print("ℹ️ PurchaseManager: No existing subscription document, creating new one")
                // ドキュメントが存在しない場合は新規作成（下のロジックで作成）
            }

            // manual_override フィールドがtrueの場合はスキップ（テスト用）
            if let data = firestoreData,
               let manualOverride = data["manual_override"] as? Bool,
               manualOverride {
                Logger.info("Manual override enabled, skipping StoreKit update", category: Logger.subscription)
                print("⚠️ PurchaseManager: Manual override enabled, skipping update")
                return
            }

            // 🚨 重要：StoreKitが空の場合、既存のプレミアム状態を上書きしない
            // ただし、返金（revocation）がある場合は保護をスキップ
            if !isPremium && !hasRevocation, let data = firestoreData {
                let existingStatus = data["status"] as? String
                let existingPlan = data["plan"] as? String

                print("🔍 PurchaseManager: Existing Firestore state - status: \(existingStatus ?? "nil"), plan: \(existingPlan ?? "nil")")

                // Firestoreに既にプレミアム状態がある場合は上書きしない
                if existingStatus == "active" || existingPlan == "premium" {
                    // 有効期限をチェック
                    if let endDateTimestamp = data["end_date"] as? Timestamp {
                        let endDate = endDateTimestamp.dateValue()
                        if Date() < endDate {
                            print("⚠️ PurchaseManager: Firestore has active premium (expires: \(endDate)), StoreKit is empty - keeping existing premium state")
                            Logger.info("Preserving existing premium status, StoreKit may not be synced yet", category: Logger.subscription)
                            return
                        } else {
                            print("ℹ️ PurchaseManager: Premium subscription expired (\(endDate)), allowing update to free")
                        }
                    } else {
                        // end_dateがnullの場合は無期限premium
                        print("⚠️ PurchaseManager: Firestore has active premium (no expiry), StoreKit is empty - keeping existing premium state")
                        Logger.info("Preserving existing premium status (no expiry), StoreKit may not be synced yet", category: Logger.subscription)
                        return
                    }
                }
            } else if hasRevocation {
                print("🚫 PurchaseManager: Revocation detected - forcing update to free regardless of Firestore state")
                Logger.warning("Transaction was revoked (refund), updating subscription to free", category: Logger.subscription)
            }

            // サブスクリプションの有効期限を取得
            var endDate: Date? = nil
            if isPremium {
                // StoreKitから最新のサブスクリプション情報を取得
                for await verification in StoreKit.Transaction.currentEntitlements {
                    do {
                        let transaction = try checkVerified(verification)
                        if transaction.productID == "com.character.premium.monthly" {
                            // サブスクリプションの有効期限を取得
                            if let expirationDate = transaction.expirationDate {
                                endDate = expirationDate
                                Logger.info("Subscription expires at: \(expirationDate)", category: Logger.subscription)
                            }
                            break
                        }
                    } catch {
                        Logger.error("Failed to verify transaction for end date", category: Logger.subscription, error: error)
                    }
                }
            }

            // 通常の更新処理
            var subscriptionData: [String: Any] = [
                "plan": isPremium ? "premium" : "free",
                "status": isPremium ? "active" : "free",
                "payment_method": "app_store",
                "auto_renewal": isPremium,
                "updated_at": Timestamp()
            ]

            // end_dateを設定（nilの場合は削除）
            if let endDate = endDate {
                subscriptionData["end_date"] = Timestamp(date: endDate)
            } else {
                // end_dateをnullに設定（無期限または無料）
                subscriptionData["end_date"] = NSNull()
            }

            try await docRef.setData(subscriptionData, merge: true)

            Logger.success("Updated subscription status: isPremium=\(isPremium), endDate=\(endDate?.description ?? "nil")", category: Logger.subscription)
            print("✅ PurchaseManager: Successfully wrote to Firestore")
            print("📄 PurchaseManager: Data = \(subscriptionData)")

            // SubscriptionManagerに通知
            await MainActor.run {
                print("🔔 PurchaseManager: Notifying SubscriptionManager to refresh")
                SubscriptionManager.shared.refreshSubscriptionStatus()
            }
        } catch {
            Logger.error("Failed to update subscription status", category: Logger.subscription, error: error)
            print("❌ PurchaseManager: Failed to write to Firestore - \(error)")
        }
    }

    private func validateReceiptWithFirebase(_ transaction: StoreKit.Transaction) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.error("User not authenticated", category: Logger.subscription)
            return
        }

        Logger.info("Starting receipt validation for user: \(userId), transaction: \(transaction.id)", category: Logger.subscription)

        do {
            // レシートデータを取得
            guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
                Logger.error("App Store receipt URL not found", category: Logger.subscription)
                return
            }

            Logger.info("Receipt URL found: \(appStoreReceiptURL.path)", category: Logger.subscription)

            guard let receiptData = try? Data(contentsOf: appStoreReceiptURL) else {
                Logger.error("Failed to load receipt data from URL", category: Logger.subscription)
                return
            }

            Logger.info("Receipt data loaded successfully. Size: \(receiptData.count) bytes", category: Logger.subscription)

            let receiptString = receiptData.base64EncodedString()

            // Firebase Functionsを呼び出してレシート検証
            let functions = Functions.functions()
            let validateReceipt = functions.httpsCallable("validateAppStoreReceipt")

            let data: [String: Any] = [
                "receiptData": receiptString,
                "transactionId": String(transaction.id)
            ]

            Logger.info("Calling Firebase Function: validateAppStoreReceipt", category: Logger.subscription)

            let result = try await validateReceipt.call(data)

            Logger.info("Firebase Function response received", category: Logger.subscription)

            if let resultData = result.data as? [String: Any],
               let success = resultData["success"] as? Bool,
               success {
                Logger.success("Receipt validation successful", category: Logger.subscription)

                // サブスクリプション状態を更新
                await updateSubscriptionStatus()
            } else {
                let errorMessage = (result.data as? [String: Any])?["error"] as? String ?? "Unknown error"
                Logger.error("Receipt validation failed: \(errorMessage)", category: Logger.subscription)
            }

        } catch let error as NSError {
            Logger.error("Receipt validation error - Domain: \(error.domain), Code: \(error.code), Message: \(error.localizedDescription)", category: Logger.subscription, error: error)

            // Functions特有のエラーの場合、詳細を記録
            if error.domain == "FIRFunctionsErrorDomain" {
                if let details = error.userInfo["details"] as? String {
                    Logger.error("Firebase Functions error details: \(details)", category: Logger.subscription)
                }
            }
        } catch {
            Logger.error("Receipt validation unexpected error", category: Logger.subscription, error: error)
        }
    }

    // MARK: - App State Monitoring

    private func setupAppStateObserver() {
        // アプリがフォアグラウンドに戻った時にサブスクリプション状態をチェック
        appStateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                print("📱 PurchaseManager: App entering foreground, checking subscription status...")
                await self.checkPurchasedProducts()
                await self.performDailyReceiptValidation()
            }
        }
    }

    /// 1日1回の定期レシート検証
    private func performDailyReceiptValidation() async {
        let now = Date().timeIntervalSince1970
        let lastValidation = Date(timeIntervalSince1970: lastReceiptValidationDate)
        let oneDayInSeconds: TimeInterval = 24 * 60 * 60

        // 最後の検証から24時間以上経過しているかチェック
        guard now - lastReceiptValidationDate > oneDayInSeconds else {
            print("ℹ️ PurchaseManager: Receipt validation already performed today (last: \(lastValidation))")
            return
        }

        print("🔄 PurchaseManager: Performing daily receipt validation...")

        // 現在のアクティブなトランザクションを取得
        for await verification in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)
                if transaction.productID == "com.character.premium.monthly" {
                    print("📝 PurchaseManager: Validating receipt for active subscription...")
                    await validateReceiptWithFirebase(transaction)
                    lastReceiptValidationDate = now
                    print("✅ PurchaseManager: Daily receipt validation completed")
                    return
                }
            } catch {
                Logger.error("Failed to verify transaction for daily validation", category: Logger.subscription, error: error)
            }
        }

        print("ℹ️ PurchaseManager: No active subscription to validate")
        lastReceiptValidationDate = now
    }

    // MARK: - Helper Methods

    func isPremiumUser() -> Bool {
        return !purchasedProductIDs.isEmpty
    }

    func getMonthlyProduct() -> Product? {
        return products.first { $0.id == "com.character.premium.monthly" }
    }
}

enum PurchaseError: Error {
    case failedVerification
    case invalidProductID
    case purchaseFailed

    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "購入の検証に失敗しました"
        case .invalidProductID:
            return "無効な商品IDです"
        case .purchaseFailed:
            return "購入に失敗しました"
        }
    }
}