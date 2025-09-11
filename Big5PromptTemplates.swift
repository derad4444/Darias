import Foundation

struct Big5PromptTemplates {
    
    // 基本プロンプトテンプレート
    static func generatePromptForPersonality(o: Int, c: Int, e: Int, a: Int, n: Int) -> String {
        let traits = [
            "経験への開放性: \(o)/5 (\(getTraitDescription(.openness, score: o)))",
            "誠実性: \(c)/5 (\(getTraitDescription(.conscientiousness, score: c)))",
            "外向性: \(e)/5 (\(getTraitDescription(.extraversion, score: e)))",
            "協調性: \(a)/5 (\(getTraitDescription(.agreeableness, score: a)))",
            "情緒安定性: \(n)/5 (\(getTraitDescription(.neuroticism, score: n)))"
        ]
        
        let personalityKey = "O\(o)_C\(c)_E\(e)_A\(a)_N\(n)_female"
        
        return """
        以下のBig5性格特性を持つ女性の詳細な性格解析を、5つのカテゴリー別に作成してください。

        【Big5スコア】
        \(traits.joined(separator: "\n"))

        【personalityKey】: \(personalityKey)

        【出力形式】
        各カテゴリーについて、以下のJSON形式で出力してください：

        ```json
        {
          "career": {
            "personality_type": "○○タイプ（15文字程度）",
            "detailed_text": "500文字の詳細解析文",
            "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
          },
          "romance": {
            "personality_type": "○○タイプ（15文字程度）",
            "detailed_text": "500文字の詳細解析文",
            "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
          },
          "stress": {
            "personality_type": "○○タイプ（15文字程度）",
            "detailed_text": "500文字の詳細解析文",
            "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
          },
          "learning": {
            "personality_type": "○○タイプ（15文字程度）",
            "detailed_text": "500文字の詳細解析文",
            "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
          },
          "decision": {
            "personality_type": "○○タイプ（15文字程度）",
            "detailed_text": "500文字の詳細解析文",
            "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
          }
        }
        ```

        【重要な条件】
        1. detailed_textは必ず500文字程度にしてください
        2. 心理学的に正確で、このスコア組み合わせに特有の特徴を反映させてください
        3. 前向きで建設的な表現を使用してください
        4. 具体的で実用的な内容にしてください
        5. 日本人女性の文化的背景を考慮してください
        """
    }
    
    private enum TraitType {
        case openness, conscientiousness, extraversion, agreeableness, neuroticism
    }
    
    private static func getTraitDescription(_ trait: TraitType, score: Int) -> String {
        switch trait {
        case .openness:
            switch score {
            case 1: return "伝統重視・現実的"
            case 2: return "やや保守的"
            case 3: return "バランス型"
            case 4: return "新しいもの好き"
            case 5: return "創造性重視・冒険的"
            default: return "普通"
            }
        case .conscientiousness:
            switch score {
            case 1: return "自由奔放・柔軟"
            case 2: return "やや自由"
            case 3: return "バランス型"
            case 4: return "計画的・責任感"
            case 5: return "完璧主義・規律重視"
            default: return "普通"
            }
        case .extraversion:
            switch score {
            case 1: return "内向的・一人好み"
            case 2: return "やや内向的"
            case 3: return "バランス型"
            case 4: return "社交的・活動的"
            case 5: return "非常に外向的・エネルギッシュ"
            default: return "普通"
            }
        case .agreeableness:
            switch score {
            case 1: return "競争的・批判的"
            case 2: return "やや競争的"
            case 3: return "バランス型"
            case 4: return "協力的・思いやり"
            case 5: return "非常に協調的・利他的"
            default: return "普通"
            }
        case .neuroticism:
            switch score {
            case 1: return "非常に情緒安定"
            case 2: return "情緒安定"
            case 3: return "バランス型"
            case 4: return "やや敏感"
            case 5: return "情緒不安定・敏感"
            default: return "普通"
            }
        }
    }
    
    // バッチ生成用（開放性ごと）
    static func generatePromptsForOpenness(_ openness: Int) -> [(key: String, prompt: String)] {
        var results: [(key: String, prompt: String)] = []
        
        for c in 1...5 {
            for e in 1...5 {
                for a in 1...5 {
                    for n in 1...5 {
                        let key = "O\(openness)_C\(c)_E\(e)_A\(a)_N\(n)_female"
                        let prompt = generatePromptForPersonality(o: openness, c: c, e: e, a: a, n: n)
                        results.append((key: key, prompt: prompt))
                    }
                }
            }
        }
        
        return results
    }
}

// 使用例:
// let prompts = Big5PromptTemplates.generatePromptsForOpenness(1)
// print("開放性1のパターン数: \(prompts.count)")
// print("最初のプロンプト:\n\(prompts[0].prompt)")