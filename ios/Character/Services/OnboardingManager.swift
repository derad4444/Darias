import Foundation
import SwiftUI

class OnboardingManager: ObservableObject {
    @Published var shouldShowTip: Bool = false
    @Published var currentTipMessage: String = ""

    private let userDefaults = UserDefaults.standard
    private let hasCompletedInitialOnboardingKey = "hasCompletedInitialOnboarding"

    private let allTips: [String] = [
        "性格解析は全部で100問あるよ。好きなタイミングで「性格診断して」と話しかけてくれれば質問するから答えてね！",
        "「何日に〇〇の予定あるよ」と教えてくれれば予定追加しておくね！",
        "アプリでわからないことや欲しい機能があれば設定画面の問い合わせから開発者に連絡してね！",
        "性格解析が終わったらキャラクター詳細画面でどんな性格か確認してみてね",
        "画面の背景の色は自由に変えられるから設定画面から好みの色に変えてね！",
        "BGMの大きさは設定画面で変えられるよ",
        "{user_name}に興味があるからあなたの性格が写っちゃいそうだよ。もう1人の自分だと思って接してね！",
        "私の夢は{user_name}の夢にもなるのかな？"
    ]

    func checkAndShowTip() {
        if !userDefaults.bool(forKey: hasCompletedInitialOnboardingKey) {
            // 初回メッセージ
            currentTipMessage = "早速、お話ししましょう！"
            userDefaults.set(true, forKey: hasCompletedInitialOnboardingKey)
        } else {
            // ランダムティップ（毎回表示）
            if let randomTip = allTips.randomElement() {
                currentTipMessage = replacePlaceholders(in: randomTip)
            }
        }
        shouldShowTip = true
    }

    func dismissTip() {
        shouldShowTip = false
    }

    private func replacePlaceholders(in message: String) -> String {
        let userName = getUserName()
        return message.replacingOccurrences(of: "{user_name}", with: userName)
    }

    private func getUserName() -> String {
        // ユーザー名を取得（AuthManagerやUserDefaultsから）
        if let userName = userDefaults.string(forKey: "user_name"), !userName.isEmpty {
            return userName
        }

        // フォールバック: Firebase Authから取得を試行
        // 実際の実装ではAuthManagerから取得するのが適切
        return "あなた"
    }

    // デバッグ用: 初回状態をリセット
    func resetOnboarding() {
        userDefaults.removeObject(forKey: hasCompletedInitialOnboardingKey)
    }
}