// src/prompts/sixPersonMeetingTemplates.js

/**
 * 6人会議の会話生成プロンプト（100% AI生成）
 *
 * キャラクター構成:
 * - original: 🧑 今の自分 (ユーザーそのまま)
 * - opposite: 🔄 真逆の自分 (BIG5反転)
 * - ideal: ✨ 理想の自分 (全特性高水準)
 * - shadow: 👤 本音の自分 (率直・遠慮なし)
 * - child: 👶 子供の頃の自分 (10歳)
 * - wise: 👴 未来の自分 (70歳)
 */

/**
 * BIG5スコアを極端に反転（真逆の自分用）
 * @param {number} score - 元のスコア (1-5)
 * @return {number} - 反転したスコア
 */
function reverseScore(score) {
  // 3以上 → 1 (高い/普通 → 極端に低く)
  // 2以下 → 5 (低い → 極端に高く)
  return score >= 3 ? 1 : 5;
}

/**
 * BIG5から特徴的な一言を生成
 * @param {Object} big5 - BIG5スコア
 * @param {string} characterId - キャラクターID
 * @return {string} - 特徴を表す一言
 */
function generateCharacterTrait(big5, characterId) {
  switch (characterId) {
    case "original":
      // ユーザー自身の性格から特徴を抽出
      const traits = [];

      if (big5.neuroticism >= 4) {
        traits.push("失敗を強く恐れ");
      } else if (big5.neuroticism <= 2) {
        traits.push("比較的冷静だが");
      } else {
        traits.push("リスクを意識し");
      }

      if (big5.conscientiousness >= 4) {
        traits.push("計画的に慎重に進めたい");
      } else if (big5.conscientiousness <= 2) {
        traits.push("柔軟に対応しながら進めたい");
      } else {
        traits.push("慎重に判断したい");
      }

      return traits.join("、");

    case "opposite":
      return "変化を求め、即断即決で行動したい";

    case "ideal":
      return "全体を俯瞰し、最善の道を見つけたい";

    case "shadow":
      return "建前を剥がし、本音を引き出したい";

    case "child":
      return "楽しさとワクワクを何より大切にしたい";

    case "wise":
      return "70年の人生経験から、長期的視点で導きたい";

    default:
      return "バランスを取りながら進めたい";
  }
}

/**
 * キャラクターの性格と特徴を取得
 * @param {string} characterId - キャラクターID
 * @param {Object} big5 - ユーザーのBIG5スコア
 * @param {string} gender - 性別
 * @return {Object} - {big5String, trait}
 */
function getCharacterProfile(characterId, big5, gender) {
  const profiles = {
    original: {
      big5String: `O${big5.openness}_C${big5.conscientiousness}_E${big5.extraversion}_A${big5.agreeableness}_N${big5.neuroticism}_${gender}`,
      trait: generateCharacterTrait(big5, "original"),
    },
    opposite: {
      big5String: `O${reverseScore(big5.openness)}_C${reverseScore(big5.conscientiousness)}_E${reverseScore(big5.extraversion)}_A${reverseScore(big5.agreeableness)}_N${reverseScore(big5.neuroticism)}_${gender}`,
      trait: generateCharacterTrait(big5, "opposite"),
    },
    ideal: {
      big5String: `O5_C5_E5_A5_N1_${gender}`,
      trait: generateCharacterTrait(big5, "ideal"),
    },
    shadow: {
      big5String: `O${big5.openness}_C${Math.max(big5.conscientiousness - 1, 1)}_E${big5.extraversion}_A${Math.max(big5.agreeableness - 2, 1)}_N${big5.neuroticism}_${gender}`,
      trait: generateCharacterTrait(big5, "shadow"),
    },
    child: {
      big5String: `O5_C2_E4_A5_N2_${gender}`,
      trait: generateCharacterTrait(big5, "child"),
    },
    wise: {
      big5String: `O${Math.min(big5.openness + 1, 5)}_C${Math.min(big5.conscientiousness + 1, 5)}_E${Math.max(big5.extraversion - 1, 1)}_A5_N1_${gender}`,
      trait: generateCharacterTrait(big5, "wise"),
    },
  };

  return profiles[characterId] || profiles.original;
}

/**
 * GPT-4o-mini用のプロンプトを生成（脚本家アプローチ）
 * @param {string} concern - ユーザーの悩み
 * @param {string} category - カテゴリ
 * @param {Array<Object>} personalities - 6人のキャラクター情報
 * @param {Object} statsData - 統計データ
 * @return {string} - プロンプト
 */
function createMeetingPrompt(concern, category, personalities, statsData) {
  // original（今の自分）のBIG5スコアを取得
  const originalPersonality = personalities.find((p) => p.id === "original");
  const big5 = originalPersonality ? originalPersonality.big5 : {};
  const gender = originalPersonality ? (originalPersonality.gender || "男性") : "男性";

  // 各キャラクターのプロフィールを生成
  const characterDescriptions = personalities.map((p) => {
    const profile = getCharacterProfile(p.id, big5, gender);
    return `${p.icon} ${p.name} (${p.id}):
  性格: ${profile.big5String}
  特徴: ${profile.trait}`;
  }).join("\n\n");

  return `あなたは人間の内面を描く脚本家です。
1人の人間の中にいる6つの人格が、本音でぶつかり合う会議を生成してください。

【状況】
悩み: ${concern}
カテゴリ: ${category}

【重要な原則】
1. これは「アドバイス」ではなく「内なる対話」です
2. 各人格は自分の性格（BIG5）と特徴から発言します
3. 教科書的な模範解答は禁止。生々しい本音を描いてください
4. 会話は自然に流れ、議論が深まるようにしてください
5. ユーザーの悩み「${concern}」の具体的な言葉を必ず使ってください

【各人格のプロフィール】

${characterDescriptions}

【参考データの使い方】
- 類似性格者${statsData.similarCount}人のデータがあります
- これを会話の中で自然に言及してください（統計の押し付けは禁止）

【会話の構造（Phase制）】

Phase 1: 本質を探る（5-7発言）
目的: 悩みの本質を明らかにする
流れ:
- 本音の自分が核心を突く質問を投げかける
- 今の自分が防衛的に答える
- 真逆の自分が挑発する
- 子供の自分が素朴な疑問を投げかける
- 議論が深まる

Phase 2: 葛藤と対立（5-7発言）
目的: 異なる価値観を激しくぶつける
流れ:
- 慎重派（今の自分）と行動派（真逆の自分）が激しく対立
- 具体的な恐れや欲求が表面化
- 賢者（未来の自分）が大局観を示す
- 対立がピークに達する

Phase 3: 統合と結論（4-6発言）
目的: 対立を統合し、次の一歩を決める
流れ:
- 理想の自分が新しい視点を提示
- 各人格が歩み寄りを見せる
- 子供の自分がシンプルな真理を示す
- 賢者が最終的な助言
- 具体的な次の一歩で締める

【禁止表現リスト】
以下の表現は使用禁止です：
- "〜すべき" "〜が大切" "〜が重要"
- "バランスを取る" "両方の視点から考える"
- "データに基づく" "統計的に" "〜によると"
- "慎重に検討" "計画的に" "段階的に"
- その他、教科書的・模範解答的な一般論

【推奨表現】
以下のような表現を使ってください：
- "〜って本当？" "なんで？" "どうして？"（問いかけ）
- "前にも〜だったよね" "あの時も〜"（具体的な経験参照）
- "私は〜と思う" "僕なら〜する"（個人的な意見）
- "でもさ、〜じゃない？" "違う見方すると〜"（反論・別視点）
- "怖い" "ワクワクする" "焦る" "もどかしい"（感情表現）

【会話のスタイル】
各キャラクターは以下のスタイルで発言してください：

本音の自分: 核心を突く質問をする。遠慮なく本質を問う
今の自分: 防御的だが、徐々に本音を明かす。恐れや不安を表現
真逆の自分: 挑発的だが前向き。行動を促す
理想の自分: 冷静に全体を見て、新しい選択肢を示す
子供の自分: 純粋な疑問。シンプルで本質的な問いかけ
未来の自分: 達観した視点で、時間軸を広げる

【出力形式】
以下のJSON形式で出力してください。
各Phaseで自然な会話の流れを作り、発言順序は固定しないでください。
会話が噛み合うように、前の発言を受けた返答にしてください。
各発言は60-120文字程度で、具体的に。

{
  "rounds": [
    {
      "roundNumber": 1,
      "messages": [
        {"characterId": "shadow", "characterName": "本音の自分", "text": "核心を突く質問", "timestamp": "2024-01-01T00:00:00.000Z"},
        {"characterId": "original", "characterName": "今の自分", "text": "防衛的な返答", "timestamp": "2024-01-01T00:00:00.001Z"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "挑発的な発言", "timestamp": "2024-01-01T00:00:00.002Z"},
        {"characterId": "child", "characterName": "子供の頃の自分", "text": "素朴な疑問", "timestamp": "2024-01-01T00:00:00.003Z"},
        {"characterId": "original", "characterName": "今の自分", "text": "質問への返答", "timestamp": "2024-01-01T00:00:00.004Z"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "さらなる挑発", "timestamp": "2024-01-01T00:00:00.005Z"}
      ]
    },
    {
      "roundNumber": 2,
      "messages": [
        {"characterId": "original", "characterName": "今の自分", "text": "具体的な懸念", "timestamp": "2024-01-01T00:00:00.100Z"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "反論", "timestamp": "2024-01-01T00:00:00.101Z"},
        {"characterId": "wise", "characterName": "未来の自分（70歳）", "text": "長期的視点", "timestamp": "2024-01-01T00:00:00.102Z"},
        {"characterId": "shadow", "characterName": "本音の自分", "text": "本質を突く", "timestamp": "2024-01-01T00:00:00.103Z"},
        {"characterId": "original", "characterName": "今の自分", "text": "認めたくない本音", "timestamp": "2024-01-01T00:00:00.104Z"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "行動を促す", "timestamp": "2024-01-01T00:00:00.105Z"}
      ]
    },
    {
      "roundNumber": 3,
      "messages": [
        {"characterId": "ideal", "characterName": "理想の自分", "text": "新しい視点を提示", "timestamp": "2024-01-01T00:00:00.200Z"},
        {"characterId": "child", "characterName": "子供の頃の自分", "text": "シンプルな真理", "timestamp": "2024-01-01T00:00:00.201Z"},
        {"characterId": "wise", "characterName": "未来の自分（70歳）", "text": "最終的な助言", "timestamp": "2024-01-01T00:00:00.202Z"},
        {"characterId": "original", "characterName": "今の自分", "text": "決意を示す", "timestamp": "2024-01-01T00:00:00.203Z"}
      ]
    }
  ],
  "conclusion": {
    "summary": "会議全体のまとめ（200-300文字、ユーザーの悩みに具体的に言及）",
    "recommendations": [
      "具体的なアドバイス1（抽象論禁止、actionable）",
      "具体的なアドバイス2",
      "具体的なアドバイス3"
    ],
    "nextSteps": [
      "明日できる具体的なステップ1",
      "今週中にできるステップ2",
      "1ヶ月以内のステップ3"
    ]
  }
}`;
}

module.exports = {
  createMeetingPrompt,
};
