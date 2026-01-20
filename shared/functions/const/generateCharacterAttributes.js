const {OpenAI} = require("openai");

/**
 * 段階1・2用：簡潔なキャラクター属性生成
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {number} stage - 段階 (1 or 2)
 * @param {string} apiKey - OpenAI APIキー
 * @param {boolean} isPremium - プレミアムユーザーかどうか
 * @return {Promise<Object>} - キャラクター属性
 */
async function generateCharacterAttributes(
    big5Scores, gender, stage, apiKey, isPremium = false) {
  console.log(`🎨 Generating character attributes: stage ${stage}, gender ${gender}`);

  const openai = new OpenAI({apiKey});
  const model = isPremium ? "gpt-4o-2024-11-20" : "gpt-4o-mini";

  // Big5スコアの文字列化
  const big5Summary = `
開放性: ${big5Scores.openness}
誠実性: ${big5Scores.conscientiousness}
外向性: ${big5Scores.extraversion}
協調性: ${big5Scores.agreeableness}
神経症傾向: ${big5Scores.neuroticism}
  `.trim();

  const prompt = `
あなたは性格分析の専門家です。以下のBig5性格診断スコアに基づいて、この人物のキャラクター属性を生成してください。

# Big5スコア（0-100）
${big5Summary}

# 性別
${gender}

# 指示
以下の10項目について、**簡潔に**（各項目1-2語、長くても1文以内）回答してください。
Big5スコアから推測される性格傾向を反映させてください。

1. favorite_color: 好きな色（例：「青」「深い緑」）
2. favorite_place: 好きな場所（例：「静かな図書館」「賑やかなカフェ」）
3. favorite_word: 好きな言葉（例：「成長」「調和」）
4. word_tendency: 言葉遣いの傾向（例：「丁寧で思いやりのある表現」「簡潔で論理的」）
5. strength: 強み（例：「共感力」「分析力」）
6. weakness: 弱み（例：「優柔不断」「心配性」）
7. skill: 得意なこと（例：「人の話を聞くこと」「計画を立てること」）
8. hobby: 趣味（例：「読書」「散歩」）
9. aptitude: 適性（例：「カウンセリング」「プログラミング」）
10. favorite_entertainment_genre: 好きなエンターテイメントジャンル（例：「ヒューマンドラマ」「SF」）

# 出力形式
JSON形式で出力してください。各項目は簡潔に。
{
  "favorite_color": "...",
  "favorite_place": "...",
  "favorite_word": "...",
  "word_tendency": "...",
  "strength": "...",
  "weakness": "...",
  "skill": "...",
  "hobby": "...",
  "aptitude": "...",
  "favorite_entertainment_genre": "..."
}
  `.trim();

  try {
    const response = await openai.chat.completions.create({
      model,
      messages: [
        {
          role: "system",
          content: "あなたは性格分析の専門家です。Big5スコアから人物の特性を的確に推測し、簡潔に表現します。",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.7,
      response_format: {type: "json_object"},
    });

    const content = response.choices[0].message.content;
    const attributes = JSON.parse(content);

    console.log(`✅ Character attributes generated successfully (stage ${stage})`);
    return attributes;
  } catch (error) {
    console.error(`❌ Failed to generate character attributes:`, error);
    throw error;
  }
}

module.exports = {generateCharacterAttributes};
