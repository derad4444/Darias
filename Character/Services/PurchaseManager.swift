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

    private let db = Firestore.firestore()

    private init() {
        updates = observeTransactionUpdates()
    }

    deinit {
        updates?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        purchaseError = nil

        do {
            products = try await Product.products(for: productIDs)
            await checkPurchasedProducts()
        } catch {
            purchaseError = "商品の読み込みに失敗しました: \(error.localizedDescription)"
            Logger.error("Failed to load products", category: Logger.subscription, error: error)
        }

        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleSuccessfulPurchase(transaction)
                await transaction.finish()
                return true

            case .userCancelled:
                purchaseError = "購入がキャンセルされました"
                return false

            case .pending:
                purchaseError = "購入が保留中です"
                return false

            @unknown default:
                purchaseError = "不明なエラーが発生しました"
                return false
            }
        } catch {
            purchaseError = "購入に失敗しました: \(error.localizedDescription)"
            Logger.error("Purchase failed", category: Logger.subscription, error: error)
            return false
        }

        isLoading = false
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
        var purchasedIDs: Set<String> = []

        for await verification in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)

                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                Logger.error("Failed to verify transaction", category: Logger.subscription, error: error)
            }
        }

        self.purchasedProductIDs = purchasedIDs

        // Firestoreのサブスクリプション状態を更新
        await updateSubscriptionStatus()
    }

    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        purchasedProductIDs.insert(transaction.productID)
        await updateSubscriptionStatus()

        // Firebase Functionsでレシート検証
        await validateReceiptWithFirebase(transaction)
    }

    private func updateSubscriptionStatus() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let isPremium = !purchasedProductIDs.isEmpty
        let subscriptionData: [String: Any] = [
            "plan": isPremium ? "premium" : "free",
            "status": isPremium ? "active" : "free",
            "payment_method": "app_store",
            "auto_renewal": isPremium,
            "updated_at": Timestamp()
        ]

        do {
            try await db.collection("users").document(userId)
                .collection("subscription").document("current")
                .setData(subscriptionData, merge: true)

            // SubscriptionManagerに通知
            await MainActor.run {
                SubscriptionManager.shared.refreshSubscriptionStatus()
            }
        } catch {
            Logger.error("Failed to update subscription status", category: Logger.subscription, error: error)
        }
    }

    private func validateReceiptWithFirebase(_ transaction: StoreKit.Transaction) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            // レシートデータを取得
            guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
                  let receiptData = try? Data(contentsOf: appStoreReceiptURL) else {
                Logger.error("Failed to get receipt data", category: Logger.subscription)
                return
            }

            let receiptString = receiptData.base64EncodedString()

            // Firebase Functionsを呼び出してレシート検証
            let functions = Functions.functions()
            let validateReceipt = functions.httpsCallable("validateAppStoreReceipt")

            let data: [String: Any] = [
                "receiptData": receiptString,
                "transactionId": String(transaction.id)
            ]

            let result = try await validateReceipt.call(data)

            if let resultData = result.data as? [String: Any],
               let success = resultData["success"] as? Bool,
               success {
                Logger.success("Receipt validation successful", category: Logger.subscription)

                // サブスクリプション状態を更新
                await updateSubscriptionStatus()
            } else {
                Logger.error("Receipt validation failed", category: Logger.subscription)
            }

        } catch {
            Logger.error("Receipt validation error", category: Logger.subscription, error: error)
        }
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