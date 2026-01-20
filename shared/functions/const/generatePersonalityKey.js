// functions/utils/generatePersonalityKey.js

/**
 * Big5スコアと性別から一意のpersonalityKeyを生成する
 * @param {Object} big5 - Big5スコア（openness, conscientiousnessなど）
 * @param {string} gender - 性別（male/female）省略可能、後方互換性のため
 * @return {string} - personalityKey（例: O3_C3_E3_A3_N3_female）
 */
function generatePersonalityKey(big5, gender) {
  const baseKey = (
    `O${big5.openness}_C${big5.conscientiousness}_E${big5.extraversion}_` +
    `A${big5.agreeableness}_N${big5.neuroticism}`
  );

  // genderが指定されている場合は末尾に追加
  return gender ? `${baseKey}_${gender}` : baseKey;
}

module.exports = {
  generatePersonalityKey,
};
