const OpenAI = require("openai");
const admin = require("firebase-admin");
const {generatePersonalityKey} = require("./generatePersonalityKey");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Big5スコアと性別から性格分析（5分野）を生成してFirestoreに保存
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {string} apiKey - OpenAI APIキー
 * @return {Promise<Object>} - 生成された分析データ
 */
async function generateBig5Analysis(big5Scores, gender, apiKey) {
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

    // プロンプト作成
    const prompt = `Big5性格分析(開放性:${big5Scores.openness}, ` +
      `誠実性:${big5Scores.conscientiousness}, 外向性:${big5Scores.extraversion}, ` +
      `協調性:${big5Scores.agreeableness}, 神経症傾向:${big5Scores.neuroticism}) ` +
      `性別:${gender}

以下5つの分野で300-500文字ずつ分析してください。性別による内容の差は不要です。

JSON出力:
{
  "career_analysis": "仕事・キャリアの特徴を300-500文字で詳しく分析...",
  "romance_analysis": "恋愛・人間関係の特徴を300-500文字で詳しく分析...",
  "stress_analysis": "ストレス対処法を300-500文字で詳しく分析...",
  "learning_analysis": "学習スタイルを300-500文字で詳しく分析...",
  "decision_analysis": "意思決定パターンを300-500文字で詳しく分析..."
}`;

    // OpenAI API呼び出し（リトライ付き）
    let analysisResult;
    const maxRetries = 3;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await openai.chat.completions.create({
          model: "gpt-4o",
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

module.exports = {generateBig5Analysis};
