// src/utils/sixPersonMeeting.js

/**
 * 6人会議機能のユーティリティ関数
 */

/**
 * BIG5スコアを変換して6つの性格パターンを生成
 * @param {Object} userBig5 - ユーザーのBIG5スコア (1-5)
 * @param {string} gender - 性別
 * @return {Array<Object>} - 6人のキャラクター情報
 */
function generateSixPersonalities(userBig5, gender) {
  const personalities = [];

  // 1. 真逆の自分
  personalities.push({
    id: "opposite",
    name: "真逆の自分",
    description: "あなたとは正反対の性格を持つ自分",
    big5: {
      openness: 6 - userBig5.openness,
      conscientiousness: 6 - userBig5.conscientiousness,
      extraversion: 6 - userBig5.extraversion,
      agreeableness: 6 - userBig5.agreeableness,
      neuroticism: 6 - userBig5.neuroticism,
    },
    gender,
    position: "left", // チャット画面での配置
  });

  // 2. 理想の自分
  personalities.push({
    id: "ideal",
    name: "理想の自分",
    description: "バランスが取れた理想的な性格の自分",
    big5: {
      openness: Math.max(userBig5.openness, 4),
      conscientiousness: Math.max(userBig5.conscientiousness, 4),
      extraversion: optimizeToMiddle(userBig5.extraversion, 3.5),
      agreeableness: Math.max(userBig5.agreeableness, 4),
      neuroticism: Math.min(userBig5.neuroticism, 2),
    },
    gender,
    position: "right",
  });

  // 3. 慎重派の自分
  personalities.push({
    id: "cautious",
    name: "慎重派の自分",
    description: "リスクを避け、計画的に行動する自分",
    big5: {
      openness: Math.max(userBig5.openness - 1, 1),
      conscientiousness: Math.min(userBig5.conscientiousness + 1, 5),
      extraversion: Math.max(userBig5.extraversion - 1, 1),
      agreeableness: userBig5.agreeableness,
      neuroticism: Math.min(userBig5.neuroticism + 1, 5),
    },
    gender,
    position: "left",
  });

  // 4. 行動派の自分
  personalities.push({
    id: "active",
    name: "行動派の自分",
    description: "直感的に動き、チャレンジを恐れない自分",
    big5: {
      openness: Math.min(userBig5.openness + 1, 5),
      conscientiousness: Math.max(userBig5.conscientiousness - 1, 1),
      extraversion: Math.min(userBig5.extraversion + 1, 5),
      agreeableness: userBig5.agreeableness,
      neuroticism: Math.max(userBig5.neuroticism - 1, 1),
    },
    gender,
    position: "right",
  });

  // 5. 感情重視の自分
  personalities.push({
    id: "emotional",
    name: "感情重視の自分",
    description: "心の声を大切にする自分",
    big5: {
      openness: Math.min(userBig5.openness + 1, 5),
      conscientiousness: userBig5.conscientiousness,
      extraversion: userBig5.extraversion,
      agreeableness: Math.min(userBig5.agreeableness + 1, 5),
      neuroticism: Math.min(userBig5.neuroticism + 1, 5),
    },
    gender,
    position: "left",
  });

  // 6. 論理重視の自分
  personalities.push({
    id: "logical",
    name: "論理重視の自分",
    description: "データと理性で判断する自分",
    big5: {
      openness: userBig5.openness,
      conscientiousness: Math.min(userBig5.conscientiousness + 1, 5),
      extraversion: userBig5.extraversion,
      agreeableness: Math.max(userBig5.agreeableness - 1, 1),
      neuroticism: Math.max(userBig5.neuroticism - 1, 1),
    },
    gender,
    position: "right",
  });

  return personalities;
}

/**
 * 値を中間値に近づける
 * @param {number} value - 現在の値 (1-5)
 * @param {number} target - 目標値
 * @return {number} - 調整後の値
 */
function optimizeToMiddle(value, target) {
  if (value < target) {
    return Math.min(value + 1, 5);
  } else if (value > target) {
    return Math.max(value - 1, 1);
  }
  return value;
}

/**
 * BIG5スコアの類似度を計算 (0.0 - 1.0)
 * @param {Object} a - BIG5スコア1
 * @param {Object} b - BIG5スコア2
 * @return {number} - 類似度 (1.0 = 完全一致, 0.0 = 全く異なる)
 */
function calculateSimilarity(a, b) {
  const diff =
    Math.abs(a.openness - b.openness) +
    Math.abs(a.conscientiousness - b.conscientiousness) +
    Math.abs(a.extraversion - b.extraversion) +
    Math.abs(a.agreeableness - b.agreeableness) +
    Math.abs(a.neuroticism - b.neuroticism);

  // 最大差分は 5 traits × 4 (max diff per trait) = 20
  return 1.0 - diff / 20.0;
}

/**
 * カテゴリ文字列から日本語表示名を取得
 * @param {string} category - カテゴリID
 * @return {string} - 日本語表示名
 */
function getCategoryDisplayName(category) {
  const categoryNames = {
    career: "キャリア・仕事",
    romance: "恋愛・人間関係",
    money: "お金・経済",
    health: "健康・ライフスタイル",
    family: "家族・子育て",
    future: "将来・人生設計",
    hobby: "趣味・自己実現",
    study: "学習・スキル",
    moving: "引っ越し・住居",
    other: "その他",
  };

  return categoryNames[category] || "その他";
}

/**
 * 悩みテキストからカテゴリを推定
 * @param {string} concern - ユーザーの悩み
 * @return {string} - 推定されたカテゴリ
 */
function detectConcernCategory(concern) {
  const keywords = {
    career: ["仕事", "転職", "キャリア", "就職", "職場", "上司", "同僚", "残業", "給料"],
    romance: ["恋愛", "恋人", "彼氏", "彼女", "結婚", "パートナー", "出会い", "片思い", "別れ"],
    money: ["お金", "貯金", "投資", "ローン", "借金", "収入", "支出", "節約"],
    health: ["健康", "病気", "ダイエット", "運動", "睡眠", "疲れ", "ストレス"],
    family: ["家族", "親", "子供", "子育て", "育児", "夫婦", "兄弟", "姉妹"],
    future: ["将来", "人生", "目標", "夢", "計画", "不安"],
    hobby: ["趣味", "やりたいこと", "好きなこと", "興味"],
    study: ["勉強", "学習", "資格", "スキル", "語学"],
    moving: ["引っ越し", "住居", "家", "マンション", "一人暮らし"],
  };

  for (const [category, words] of Object.entries(keywords)) {
    if (words.some((word) => concern.includes(word))) {
      return category;
    }
  }

  return "other";
}

/**
 * BIG5スコアからpersonalityKeyを生成
 * @param {Object} big5 - BIG5スコア
 * @param {string} gender - 性別
 * @return {string} - personalityKey
 */
function generatePersonalityKey(big5, gender) {
  const baseKey = (
    `O${Math.round(big5.openness)}_` +
    `C${Math.round(big5.conscientiousness)}_` +
    `E${Math.round(big5.extraversion)}_` +
    `A${Math.round(big5.agreeableness)}_` +
    `N${Math.round(big5.neuroticism)}`
  );

  return gender ? `${baseKey}_${gender}` : baseKey;
}

/**
 * 会話のラウンド数を計算
 * @param {number} messageCount - メッセージ総数
 * @return {number} - ラウンド数
 */
function calculateRoundCount(messageCount) {
  // 6人 × ラウンド数 = メッセージ数
  return Math.ceil(messageCount / 6);
}

module.exports = {
  generateSixPersonalities,
  calculateSimilarity,
  getCategoryDisplayName,
  detectConcernCategory,
  generatePersonalityKey,
  calculateRoundCount,
  optimizeToMiddle,
};
