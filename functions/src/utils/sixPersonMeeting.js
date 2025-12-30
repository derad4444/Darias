// src/utils/sixPersonMeeting.js

/**
 * 6人会議機能のユーティリティ関数
 */

/**
 * BIG5スコアを変換して6つの性格パターンを生成
 * 仕様書 (docs/six-person-meeting/02_characters.md) に基づく
 * @param {Object} userBig5 - ユーザーのBIG5スコア (1-5)
 * @param {string} gender - 性別
 * @return {Array<Object>} - 6人のキャラクター情報
 */
function generateSixPersonalities(userBig5, gender) {
  const personalities = [];

  // 1. 今の自分 (ユーザーのBIG5そのまま)
  personalities.push({
    id: "original",
    name: "今の自分",
    icon: "🧑",
    catchphrase: "慎重派の分析家",
    description: "いつものあなた。リスクを考えてデータを重視する性格。",
    big5: {
      openness: userBig5.openness,
      conscientiousness: userBig5.conscientiousness,
      extraversion: userBig5.extraversion,
      agreeableness: userBig5.agreeableness,
      neuroticism: userBig5.neuroticism,
    },
    gender,
    position: "left", // 慎重派グループ
  });

  // 2. 真逆の自分 (全BIG5を反転)
  personalities.push({
    id: "opposite",
    name: "真逆の自分",
    icon: "🔄",
    catchphrase: "自由奔放な冒険家",
    description: "あなたとは正反対の性格。大胆で即断即決タイプ。",
    big5: {
      openness: 6 - userBig5.openness,
      conscientiousness: 6 - userBig5.conscientiousness,
      extraversion: 6 - userBig5.extraversion,
      agreeableness: 6 - userBig5.agreeableness,
      neuroticism: 6 - userBig5.neuroticism,
    },
    gender,
    position: "right", // 行動派グループ
  });

  // 3. 理想の自分 (全特性を高水準に)
  personalities.push({
    id: "ideal",
    name: "理想の自分",
    icon: "✨",
    catchphrase: "冷静な完璧主義者",
    description: "バランスが取れた成長した姿。客観的に物事を見る。",
    big5: {
      openness: Math.max(userBig5.openness, 4),
      conscientiousness: Math.max(userBig5.conscientiousness, 4),
      extraversion: optimizeToMiddle(userBig5.extraversion, 3.5),
      agreeableness: Math.max(userBig5.agreeableness, 4),
      neuroticism: Math.max(userBig5.neuroticism, 4), // 高い = 安定
    },
    gender,
    position: "left", // 慎重派グループ
  });

  // 4. 本音の自分 (協調性を下げ、率直に)
  personalities.push({
    id: "shadow",
    name: "本音の自分",
    icon: "👤",
    catchphrase: "率直な現実主義者",
    description: "建前なし。本当に思っていることをズバリ言う性格。",
    big5: {
      openness: Math.min(userBig5.openness + 1.5, 5),
      conscientiousness: Math.max(userBig5.conscientiousness - 2, 1),
      extraversion: Math.min(userBig5.extraversion + 1.5, 5),
      agreeableness: Math.max(userBig5.agreeableness - 2.5, 1), // 本音
      neuroticism: Math.max(userBig5.neuroticism - 1.5, 1),
    },
    gender,
    position: "right", // 行動派グループ
  });

  // 5. 子供の頃の自分 (10歳の頃の性格)
  personalities.push({
    id: "child",
    name: "子供の頃の自分",
    icon: "👶",
    catchphrase: "純粋な夢見る少年/少女",
    description: "10歳の頃のあなた。感情を大切にワクワクを追い求める。",
    big5: {
      openness: 5, // 子供は好奇心旺盛
      conscientiousness: 1, // 計画性低い
      extraversion: Math.max(userBig5.extraversion + 1, 4),
      agreeableness: 3, // 純粋
      neuroticism: 2, // 感情的だが回復も早い
    },
    gender,
    position: "right", // 行動派グループ
  });

  // 6. 未来の自分 (70歳の達観した自分)
  personalities.push({
    id: "wise",
    name: "未来の自分（70歳）",
    icon: "👴",
    catchphrase: "達観した人生の先輩",
    description: "70歳になったあなた。長い人生経験から冷静にアドバイスしてくれる。",
    big5: {
      openness: Math.max(userBig5.openness - 1, 2), // やや保守的
      conscientiousness: Math.min(userBig5.conscientiousness + 0.5, 5),
      extraversion: Math.max(userBig5.extraversion - 1, 2), // 落ち着く
      agreeableness: Math.min(userBig5.agreeableness + 1, 5), // 寛容
      neuroticism: Math.min(userBig5.neuroticism + 1.5, 5), // 達観
    },
    gender,
    position: "left", // 慎重派グループ
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
