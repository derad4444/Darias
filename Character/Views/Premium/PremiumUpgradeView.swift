import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var selectedFeature: PremiumFeature? = nil

    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection

                        // 機能比較
                        featureComparisonSection

                        // 料金プラン
                        pricingSection

                        // 購入ボタン
                        purchaseSection

                        // 法的情報
                        legalSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await purchaseManager.loadProducts()
        }
        .sheet(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 閉じるボタン
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }

            // タイトル
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                Text("プレミアムにアップグレード")
                    .dynamicTitle()
                    .fontWeight(.bold)
                    .foregroundColor(colorSettings.getCurrentTextColor())

                Text("広告なしで快適なキャラクター体験を")
                    .dynamicBody()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }

    private var featureComparisonSection: some View {
        VStack(spacing: 16) {
            Text("機能比較")
                .dynamicTitle2()
                .fontWeight(.semibold)
                .foregroundColor(colorSettings.getCurrentTextColor())

            VStack(spacing: 12) {
                featureRow(
                    icon: "rectangle.slash",
                    title: "広告非表示",
                    free: "バナー・リワード広告",
                    premium: "完全非表示",
                    feature: .adFree
                )

                featureRow(
                    icon: "clock.arrow.circlepath",
                    title: "チャット履歴",
                    free: "50メッセージまで",
                    premium: "無制限保存",
                    feature: .unlimitedHistory
                )

                featureRow(
                    icon: "sparkles",
                    title: "AIモデル",
                    free: "標準モデル",
                    premium: "最新モデル",
                    feature: .latestAIModel
                )

                featureRow(
                    icon: "person.crop.circle.badge.plus",
                    title: "キャラクター分析",
                    free: "基本分析",
                    premium: "より高度な解析",
                    feature: .detailedAnalysis
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private func featureRow(icon: String, title: String, free: String, premium: String, feature: PremiumFeature) -> some View {
        Button(action: { selectedFeature = feature }) {
            HStack(spacing: 16) {
                // アイコン
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                    .frame(width: 30)

                // 機能名
                Text(title)
                    .dynamicBody()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 無料プラン
                VStack {
                    Text("無料")
                        .dynamicCaption()
                        .foregroundColor(.gray)
                    Text(free)
                        .dynamicCaption()
                        .foregroundColor(.red)
                }
                .frame(width: 60)

                // プレミアムプラン
                VStack {
                    Text("プレミアム")
                        .dynamicCaption()
                        .foregroundColor(.gray)
                    Text(premium)
                        .dynamicCaption()
                        .foregroundColor(.green)
                }
                .frame(width: 80)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorSettings.getCurrentTextColor().opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorSettings.getCurrentAccentColor().opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var pricingSection: some View {
        VStack(spacing: 16) {
            Text("料金プラン")
                .dynamicTitle2()
                .fontWeight(.semibold)
                .foregroundColor(colorSettings.getCurrentTextColor())

            if let product = purchaseManager.getMonthlyProduct() {
                VStack(spacing: 12) {

                    VStack(spacing: 8) {
                        HStack {
                            Text(product.displayPrice)
                                .dynamicTitle()
                                .fontWeight(.bold)
                                .foregroundColor(colorSettings.getCurrentAccentColor())

                            Text("/ 月")
                                .dynamicBody()
                                .foregroundColor(.gray)
                        }

                        Text("7日間無料トライアル")
                            .dynamicCaption()
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorSettings.getCurrentAccentColor().opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorSettings.getCurrentAccentColor(), lineWidth: 2)
                        )
                )
            } else {
                // 商品読み込み中や失敗時のフォールバック表示
                VStack(spacing: 8) {
                    HStack {
                        Text("月額980円")
                            .dynamicTitle()
                            .fontWeight(.bold)
                            .foregroundColor(colorSettings.getCurrentAccentColor())

                        Text("/ 月")
                            .dynamicBody()
                            .foregroundColor(.gray)
                    }

                    Text("7日間無料トライアル")
                        .dynamicCaption()
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorSettings.getCurrentAccentColor().opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorSettings.getCurrentAccentColor(), lineWidth: 2)
                        )
                )
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 16) {
            if purchaseManager.isLoading {
                ProgressView("読み込み中...")
                    .foregroundColor(colorSettings.getCurrentTextColor())
            } else if let product = purchaseManager.getMonthlyProduct() {
                // 購入ボタン
                Button(action: {
                    Task {
                        let success = await purchaseManager.purchase(product)
                        if success {
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("プレミアムを開始")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [colorSettings.getCurrentAccentColor(), colorSettings.getCurrentAccentColor().opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(purchaseManager.isLoading)

                // 復元ボタン
                Button(action: {
                    Task {
                        await purchaseManager.restorePurchases()
                    }
                }) {
                    Text("購入を復元")
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            } else if !purchaseManager.isLoading {
                // 商品読み込み失敗時のフォールバック購入ボタン
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await purchaseManager.loadProducts()
                        }
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("プレミアムを開始")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [colorSettings.getCurrentAccentColor(), colorSettings.getCurrentAccentColor().opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }

                    Text("商品情報を読み込んでいます...")
                        .dynamicCaption()
                        .foregroundColor(.gray)
                }
            }

            // エラーメッセージ
            if let error = purchaseManager.purchaseError {
                Text(error)
                    .dynamicCaption()
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var legalSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("• 無料トライアル期間終了24時間前に自動更新されます")
                    .font(.caption)
                Text("• 購入確定時にApple IDアカウントに課金されます")
                    .font(.caption)
                Text("• 設定 > Apple ID > サブスクリプションから管理できます")
                    .font(.caption)
            }
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button("利用規約") {
                    showTerms = true
                }
                .foregroundColor(colorSettings.getCurrentAccentColor())

                Button("プライバシーポリシー") {
                    showPrivacy = true
                }
                .foregroundColor(colorSettings.getCurrentAccentColor())
            }
            .font(.caption)
        }
    }
}

enum PremiumFeature: CaseIterable {
    case adFree
    case unlimitedHistory
    case latestAIModel
    case detailedAnalysis

    var title: String {
        switch self {
        case .adFree: return "広告非表示"
        case .unlimitedHistory: return "チャット履歴"
        case .latestAIModel: return "AIモデル"
        case .detailedAnalysis: return "キャラクター分析"
        }
    }

    var description: String {
        switch self {
        case .adFree:
            return "バナー広告とリワード広告（動画広告）が完全に非表示になり、快適にご利用いただけます。"
        case .unlimitedHistory:
            return "無料版では最新50メッセージまでですが、プレミアムなら全てのチャット履歴を無制限に保存・閲覧できます。"
        case .latestAIModel:
            return "最新のAIモデルを使用してより自然で高品質な会話をお楽しみいただけます。"
        case .detailedAnalysis:
            return "基本分析に加えて、より高度で詳細なキャラクター解析機能をご利用いただけます。"
        }
    }
}

struct PremiumUpgradeView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumUpgradeView()
    }
}