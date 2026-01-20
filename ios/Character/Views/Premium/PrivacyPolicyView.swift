import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var colorSettings = ColorSettingsManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("プライバシーポリシー")
                            .dynamicTitle()
                            .fontWeight(.bold)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        Group {
                            privacySection(
                                title: "1. 収集する情報",
                                content: "当社は、本サービスの提供にあたり、以下の情報を収集します：\n• アカウント情報（メールアドレス、ユーザー名）\n• デバイス情報（OS、デバイスID）\n• 利用状況（アプリの使用履歴、チャット内容）\n• 購入情報（サブスクリプション状況）"
                            )

                            privacySection(
                                title: "2. 情報の利用目的",
                                content: "収集した情報は以下の目的で利用します：\n• サービスの提供・運営\n• ユーザーサポート\n• サービスの改善・開発\n• 利用状況の分析\n• 不正利用の防止"
                            )

                            privacySection(
                                title: "3. 情報の共有",
                                content: "当社は、法令に基づく場合や、ユーザーの同意がある場合を除き、収集した個人情報を第三者に提供しません。ただし、以下の場合は除きます：\n• サービス提供のために必要な範囲で業務委託先に提供する場合\n• 統計的データとして、個人を特定できない形で提供する場合"
                            )

                            privacySection(
                                title: "4. 情報の保護",
                                content: "当社は、収集した個人情報について、適切な安全管理措置を講じ、不正アクセス、漏洩、滅失または毀損の防止に努めます。"
                            )

                            privacySection(
                                title: "5. Cookieの使用",
                                content: "本サービスは、ユーザーの利便性向上のためにCookieを使用する場合があります。Cookieを無効にした場合、サービスの一部機能が利用できない場合があります。"
                            )

                            privacySection(
                                title: "6. 第三者サービス",
                                content: "本アプリは以下の第三者サービスを利用しています：\n• Firebase（Google）- データ保存・分析\n• AdMob（Google）- 広告配信\n• App Store（Apple）- 決済処理\n\nこれらのサービスには各社のプライバシーポリシーが適用されます。"
                            )

                            privacySection(
                                title: "7. データの削除",
                                content: "ユーザーは、アカウント削除により個人情報の削除を求めることができます。削除申請は設定画面またはお問い合わせからご連絡ください。"
                            )

                            privacySection(
                                title: "8. 年齢制限",
                                content: "本サービスは13歳以上の方を対象としています。13歳未満の方は本サービスをご利用いただけません。"
                            )

                            privacySection(
                                title: "9. ポリシーの変更",
                                content: "当社は、必要に応じて本プライバシーポリシーを変更することがあります。変更後のポリシーは、本アプリ内で通知します。"
                            )

                            privacySection(
                                title: "10. お問い合わせ",
                                content: "本プライバシーポリシーに関するお問い合わせは、アプリ内のお問い合わせ機能からご連絡ください。"
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("制定日：2024年1月1日")
                                .font(.caption)
                            Text("最終更新日：2024年1月1日")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            }
        }
    }

    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .dynamicHeadline()
                .fontWeight(.semibold)
                .foregroundColor(colorSettings.getCurrentTextColor())

            Text(content)
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}