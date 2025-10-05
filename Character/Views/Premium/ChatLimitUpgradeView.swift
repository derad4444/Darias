import SwiftUI

struct ChatLimitUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    let onUpgrade: () -> Void

    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // メインコンテンツ
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("プレミアムのご案内")
                        .dynamicTitle2()
                        .fontWeight(.bold)
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    Text("広告なしでもっと快適にキャラクターとチャットしませんか？\nプレミアムなら動画広告が完全に非表示になります！")
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                // オプション
                VStack(spacing: 16) {
                    // プレミアムアップグレードボタン
                    Button(action: {
                        dismiss()
                        onUpgrade()
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("プレミアムにアップグレード")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }

                    // 後で検討ボタン
                    Button(action: {
                        dismiss()
                    }) {
                        Text("後で検討する")
                            .dynamicBody()
                            .foregroundColor(.gray)
                    }
                }

                // プレミアム特典
                VStack(spacing: 8) {
                    Text("プレミアムの特典")
                        .dynamicHeadline()
                        .fontWeight(.semibold)
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    VStack(alignment: .leading, spacing: 4) {
                        benefitRow(icon: "rectangle.slash", text: "広告完全非表示")
                        benefitRow(icon: "clock.arrow.circlepath", text: "無制限チャット履歴")
                        benefitRow(icon: "sparkles", text: "最新AIモデル")
                        benefitRow(icon: "person.crop.circle.badge.plus", text: "より高度な解析")
                    }
                }

                // 価格情報
                if let product = purchaseManager.getMonthlyProduct() {
                    VStack(spacing: 4) {
                        Text("\(product.displayPrice)/月")
                            .dynamicTitle3()
                            .fontWeight(.bold)
                            .foregroundColor(colorSettings.getCurrentAccentColor())

                        Text("7日間無料トライアル")
                            .dynamicCaption()
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorSettings.getCurrentBackgroundGradient())
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
        .task {
            await purchaseManager.loadProducts()
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(colorSettings.getCurrentAccentColor())
                .frame(width: 16)

            Text(text)
                .dynamicCaption()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))

            Spacer()
        }
    }
}

struct ChatLimitUpgradeView_Previews: PreviewProvider {
    static var previews: some View {
        ChatLimitUpgradeView(
            onUpgrade: {}
        )
    }
}