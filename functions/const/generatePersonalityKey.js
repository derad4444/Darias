// functions/utils/generatePersonalityKey.js

/**
 * Big5スコアから一意のpersonalityKeyを生成する
 * @param {Object} big5 - Big5スコア（openness, conscientiousnessなど）
 * @return {string} - personalityKey（例: O4_C2_A5_E3_N1）
 */
function generatePersonalityKey(big5) {
  return (
    `O${big5.openness}_C${big5.conscientiousness}_A${big5.agreeableness}_` +
    `E${big5.extraversion}_N${big5.neuroticism}`
  );
}

module.exports = {
  generatePersonalityKey,
};
