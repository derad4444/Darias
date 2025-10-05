const OpenAI = require("openai");
const admin = require("firebase-admin");
const {generatePersonalityKey} = require("./generatePersonalityKey");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Big5スコアと性別から性格分析（5分野）を生成してFirestoreに保存
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {string} apiKey - OpenAI APIキー
 * @param {boolean} isPremium - プレミアムユーザーかどうか
 * @return {Promise<Object>} - 生成された分析データ
 */
async function generateBig5Analysis(big5Scores, gender, apiKey, isPremium = false) {
  try {
    // personalityKey生成
    const personalityKey = generatePersonalityKey(big5Scores);

    // 既存データチェック
    const existingDoc = await db.collection("Big5Analysis")
        .doc(personalityKey).get();
    if (existingDoc.exists) {
      console.log(`✅ Big5Analysis already exists: ${personalityKey}`);
      return existingDoc.data();
    }

    console.log(`🔄 Generating Big5Analysis: ${personalityKey}`);

    // OpenAI クライアント作成
    const openai = new OpenAI({apiKey});

    // 最適化されたプロンプト作成
    const prompt = OPTIMIZED_PROMPTS.big5Analysis(big5Scores, gender);

    // OpenAI API呼び出し（リトライ付き）
    let analysisResult;
    const maxRetries = 3;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // サブスクリプション状態に基づくモデル選択（有料ユーザーは最新モデル）
        const model = isPremium ? "gpt-4o-2024-11-20" : "gpt-4o-mini";

        const response = await openai.chat.completions.create({
          model: model,
          messages: [{role: "user", content: prompt}],
          temperature: 0.7,
        });

        let content = response.choices[0].message.content.trim();

        // マークダウン記法除去
        if (content.startsWith("```json")) {
          content = content.replace(/^```json\s*/, "")
              .replace(/```$/, "").trim();
        }

        // JSON解析
        analysisResult = JSON.parse(content);
        console.log(`✅ OpenAI API success on attempt ${attempt}`);
        break;
      } catch (error) {
        console.error(`❌ OpenAI API attempt ${attempt} failed:`, error.message);

        if (attempt === maxRetries) {
          throw new Error(`OpenAI API failed after ${maxRetries} attempts: ` +
            `${error.message}`);
        }

        // 指数バックオフで待機
        await new Promise((resolve) =>
          setTimeout(resolve, Math.pow(2, attempt) * 1000));
      }
    }

    // 文字数カウント
    const totalCharacterCount = Object.values(analysisResult).join("").length;

    // Firestoreに保存するデータ構築
    const analysisData = {
      personality_key: personalityKey,
      career_analysis: analysisResult.career_analysis || "",
      romance_analysis: analysisResult.romance_analysis || "",
      stress_analysis: analysisResult.stress_analysis || "",
      learning_analysis: analysisResult.learning_analysis || "",
      decision_analysis: analysisResult.decision_analysis || "",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      big5_scores: big5Scores,
      character_count: totalCharacterCount,
    };

    // Firestore保存
    await db.collection("Big5Analysis").doc(personalityKey).set(analysisData);

    console.log(`✅ Big5Analysis generated successfully: ${personalityKey} ` +
      `(${totalCharacterCount} chars)`);
    return analysisData;
  } catch (error) {
    console.error(`❌ generateBig5Analysis failed:`, error);
    throw error;
  }
}

// HTTP callable関数のラッパー
const {onCall} = require("firebase-functions/v2/https");

/**
 * HTTP Callable版 - Big5性格分析生成
 */
const generateBig5AnalysisCallable = onCall(
  {
    region: "asia-northeast1",
    memory: "1GiB",
    timeoutSeconds: 300,
    secrets: ["OPENAI_API_KEY"],
  },
  async (request) => {
    const {data} = request;
    try {
      const { personalityKey, isPremium } = data;

      if (!personalityKey) {
        throw new Error("personalityKey is required");
      }

      // personalityKeyから Big5Scores と gender を解析
      const { big5Scores, gender } = parsePersonalityKey(personalityKey);

      // OpenAI APIキーを取得
      const {OPENAI_API_KEY} = require("../src/config/config");
      const apiKey = OPENAI_API_KEY.value().trim();
      if (!apiKey) {
        throw new Error("OpenAI API key not configured");
      }

      // 分析データ生成
      const result = await generateBig5Analysis(big5Scores, gender, apiKey, isPremium);

      return result;
    } catch (error) {
      console.error("❌ generateBig5AnalysisCallable error:", error);
      throw new Error("Big5分析生成に失敗しました");
    }
  }
);

/**
 * personalityKeyから Big5Scores と gender を解析
 * @param {string} personalityKey - "O3_C4_E2_A5_N1_male" 形式
 * @return {Object} - {big5Scores, gender}
 */
function parsePersonalityKey(personalityKey) {
  const parts = personalityKey.split("_");

  if (parts.length !== 6) {
    throw new Error("Invalid personalityKey format");
  }

  const big5Scores = {
    openness: parseInt(parts[0].substring(1)),
    conscientiousness: parseInt(parts[1].substring(1)),
    extraversion: parseInt(parts[2].substring(1)),
    agreeableness: parseInt(parts[3].substring(1)),
    neuroticism: parseInt(parts[4].substring(1))
  };

  const gender = parts[5];

  return { big5Scores, gender };
}

module.exports = {generateBig5Analysis, generateBig5AnalysisCallable};
