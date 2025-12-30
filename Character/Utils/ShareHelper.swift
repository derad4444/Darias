// Character/Utils/ShareHelper.swift

import Foundation

struct ShareHelper {
    // 性格解析結果を共有
    static func sharePersonalityAnalysis(
        stage: Int,
        strengths: String,
        weaknesses: String,
        dreams: String
    ) -> [Any] {
        let text = """
        🎯 段階\(stage)の性格解析が完了！

        長所: \(strengths)
        短所: \(weaknesses)
        夢: \(dreams)

        あなたもAIキャラクターと話してみませんか？
        #性格診断 #AIキャラクター
        """

        return [text]
    }

    // 会議結果を共有
    static func shareMeetingConclusion(
        concern: String,
        conclusion: String
    ) -> [Any] {
        let truncatedConcern = String(concern.prefix(50))
        let truncatedConclusion = String(conclusion.prefix(100))

        let text = """
        💭 6人の自分で会議しました

        相談内容:
        \(truncatedConcern)\(concern.count > 50 ? "..." : "")

        会議の結論:
        \(truncatedConclusion)\(conclusion.count > 100 ? "..." : "")

        #自分会議 #AI #悩み相談
        """

        return [text]
    }
}
