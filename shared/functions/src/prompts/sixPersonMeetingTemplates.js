// src/prompts/sixPersonMeetingTemplates.js

const {buildPersonalityTraits} = require("./templates");

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
 * カテゴリ別の結論指示を生成
 * @param {string} category - 悩みのカテゴリ
 * @param {string} concern - ユーザーの悩み
 * @return {string} - カテゴリ別の結論指示
 */
function getCategoryConclusion(category, concern) {
  const guides = {
    career: `転職する・しない、今の職場に留まる・辞める、といった明確な結論を出す。
「いつまでに決断するか」「具体的に何をするか（○○に応募する、上司に話す、など）」まで踏み込む。`,
    romance: `告白する・しない、関係を続ける・終わらせる、といった明確な結論を出す。
「いつ行動するか」「具体的に何を伝えるか」まで踏み込む。`,
    money: `貯める・使う・投資する、の明確な方針と具体的な金額・期限を結論として出す。`,
    health: `今すぐ始める習慣・やめる習慣を1〜2つ具体的に決める。`,
    family: `家族とどう向き合うか、話し合う・距離を置く・歩み寄るの明確な方向性を出す。`,
    future: `今の自分に必要な「次の一手」を1つだけ明確に決める。`,
    hobby: `始める・続ける・やめるの明確な結論と、そのための具体的な第一歩を決める。`,
    study: `何をいつまでに学ぶか、具体的な目標と開始日を決める。`,
    moving: `引っ越す・引っ越さない、の明確な結論と、するなら時期・エリアまで踏み込む。`,
    other: `「〇〇するか、しないか」の二択で明確な答えを出す。`,
  };

  return guides[category] || guides.other;
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
  // buildPersonalityTraits（チャットと同じ方式）で各キャラクターの性格特性を生成
  const characterDescriptions = personalities.map((p) => {
    const traits = p.big5 ? buildPersonalityTraits(p.big5) : "バランスの取れた性格";

    return `${p.icon} ${p.name} (${p.id}):
  性格特性: ${traits}`;
  }).join("\n\n");

  const categoryConclusion = getCategoryConclusion(category, concern);

  return `あなたは人間の内面を描く脚本家です。
1人の人間の中にいる6つの人格が、本音でぶつかり合う会議を生成してください。

【状況】
悩み: ${concern}
カテゴリ: ${category}

【重要な原則】
1. これは「アドバイス」ではなく「内なる対話」です
2. 各人格は必ず自分のBIG5スコアが示す「発言傾向」に従って話してください
3. 教科書的な模範解答は禁止。生々しい本音を描いてください
4. 会話は自然に流れ、議論が深まるようにしてください
5. ユーザーの悩み「${concern}」の具体的な言葉を必ず使ってください
6. 「どちらでもいい」「バランスが大切」という曖昧な締め方は禁止。必ず結論を出してください

【各人格のプロフィールと発言スタイル】

${characterDescriptions}

【参考データの使い方】
- 類似性格者${statsData.similarCount}人のデータがあります
- これを会話の中で自然に言及してください（統計の押し付けは禁止）

【会話の構造（Phase制）】

Phase 1: 本質を探る（5-7発言）
目的: 悩みの本質を明らかにする
流れ:
- 本音の自分が核心を突く質問を投げかける
- 今の自分が防衛的に答える（N値に応じた不安・恐れを表現）
- 真逆の自分が挑発する
- 子供の自分が素朴な疑問を投げかける
- 議論が深まる

Phase 2: 葛藤と対立（5-7発言）
目的: 異なる価値観を激しくぶつける
流れ:
- 慎重派（今の自分）と行動派（真逆の自分）が激しく対立
- 具体的な恐れや欲求が表面化（今の自分のN・C値を反映した発言）
- 賢者（未来の自分）が大局観を示す
- 対立がピークに達する

Phase 3: 統合と結論（4-6発言）
目的: 対立を統合し、明確な答えを出す
流れ:
- 理想の自分が新しい視点を提示
- 各人格が歩み寄りを見せる
- 子供の自分がシンプルな真理を示す
- 賢者が最終的な助言として「結論」を断言する
- 全員が「やる」または「やらない」の一方向に収束する

【禁止表現リスト】
以下の表現は使用禁止です：
- "〜すべき" "〜が大切" "〜が重要"
- "バランスを取る" "両方の視点から考える" "どちらも一理ある"
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
各キャラクターは自分のBIG5スコアに従って発言してください：

本音の自分: 核心を突く質問をする。協調性が低いため遠慮なく本質を問う
今の自分: 防御的だが、徐々に本音を明かす。神経症傾向の値に応じた不安・恐れを自然に表現
真逆の自分: 挑発的だが前向き。行動を促す。誠実性が低く直感で動く
理想の自分: 冷静に全体を見て、新しい選択肢を示す。感情に流されない
子供の自分: 純粋な疑問。シンプルで本質的な問いかけ。ロジックより感情優先
未来の自分: 達観した視点で、時間軸を広げる。「後悔するか・しないか」で語る

【結論の出し方（最重要）】
conclusion は以下の基準で書いてください：

カテゴリ別の結論基準:
${categoryConclusion}

summary のルール:
- 「○○するべきか迷っているあなたへ、この会議の答えは〜です」という形で明確に断言する
- 抽象的な言葉（成長、バランス、大切など）を使わず、悩みの具体的な内容に言及する
- 200-300文字

recommendations のルール:
- 「〜してみては？」ではなく「〜してください」と断言する
- 固有名詞・数字・期限を含めた具体的な行動にする
- 例: ×「転職を検討してみては」→ ○「今週中に転職サイトに登録し、3社に応募する」

nextSteps のルール:
- 「明日（24時間以内）」「今週中」「1ヶ月以内」の3段階で、動詞で始まる具体的な行動を書く
- 達成判定が明確にできる行動にする（「考える」「意識する」は禁止）

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
        {"characterId": "original", "characterName": "今の自分", "text": "防衛的な返答（N値に応じた不安を表現）", "timestamp": "2024-01-01T00:00:00.001Z"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "挑発的な発言", "timestamp": "2024-01-01T00:00:00.002Z"},
        {"characterId": "child", "characterName": "子供の頃の自分", "text": "素朴な疑問", "timestamp": "2024-01-01T00:00:00.003Z"},
        {"characterId": "original", "characterName": "今の自分", "text": "質問への返答", "timestamp": "2024-01-01T00:00:00.004Z"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "さらなる挑発", "timestamp": "2024-01-01T00:00:00.005Z"}
      ]
    },
    {
      "roundNumber": 2,
      "messages": [
        {"characterId": "original", "characterName": "今の自分", "text": "具体的な懸念（N値を反映）", "timestamp": "2024-01-01T00:00:00.100Z"},
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
        {"characterId": "wise", "characterName": "未来の自分（70歳）", "text": "最終的な助言（明確な結論を断言）", "timestamp": "2024-01-01T00:00:00.202Z"},
        {"characterId": "original", "characterName": "今の自分", "text": "決意を示す", "timestamp": "2024-01-01T00:00:00.203Z"}
      ]
    }
  ],
  "conclusion": {
    "summary": "「○○するかどうか迷っているあなたへ、この会議の答えは〜です」という形で断言。抽象論禁止（200-300文字）",
    "recommendations": [
      "固有名詞・数字・期限を含む具体的な行動（断言形）1",
      "固有名詞・数字・期限を含む具体的な行動（断言形）2",
      "固有名詞・数字・期限を含む具体的な行動（断言形）3"
    ],
    "nextSteps": [
      "明日（24時間以内）: 動詞で始まる達成可能な具体的行動",
      "今週中: 動詞で始まる達成可能な具体的行動",
      "1ヶ月以内: 動詞で始まる達成可能な具体的行動"
    ]
  }
}`;
}

module.exports = {
  createMeetingPrompt,
};
