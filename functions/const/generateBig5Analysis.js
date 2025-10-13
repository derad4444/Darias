const OpenAI = require("openai");
const admin = require("firebase-admin");
const {generatePersonalityKey} = require("./generatePersonalityKey");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Big5スコアと性別から性格分析データを生成してFirestoreに保存
 * 階層構造: analysis_20, analysis_50, analysis_100
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {string} apiKey - OpenAI APIキー
 * @param {boolean} isPremium - プレミアムユーザーかどうか
 * @return {Promise<Object>} - 生成された分析データ
 */
async function generateBig5Analysis(big5Scores, gender, apiKey, isPremium = false) {
  try {
    // personalityKey生成
    const personalityKey = generatePersonalityKey(big5Scores, gender);

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

    // サブスクリプション状態に基づくモデル選択
    const model = isPremium ? "gpt-4o-2024-11-20" : "gpt-4o-mini";
    console.log(`🤖 Using model: ${model}`);

    // 3つのレベル分を生成
    const [analysis20, analysis50, analysis100] = await Promise.all([
      generateAnalysisLevel(openai, model, big5Scores, gender, 20),
      generateAnalysisLevel(openai, model, big5Scores, gender, 50),
      generateAnalysisLevel(openai, model, big5Scores, gender, 100),
    ]);

    // Firestoreに保存するデータ構築
    const analysisData = {
      personality_key: personalityKey,
      last_updated: admin.firestore.FieldValue.serverTimestamp(),
      analysis_20: analysis20,
      analysis_50: analysis50,
      analysis_100: analysis100,
      big5_scores: big5Scores,
      gender: gender,
    };

    // Firestore保存
    await db.collection("Big5Analysis").doc(personalityKey).set(analysisData);

    console.log(`✅ Big5Analysis generated successfully: ${personalityKey}`);
    return analysisData;
  } catch (error) {
    console.error(`❌ generateBig5Analysis failed:`, error);
    throw error;
  }
}

/**
 * 指定レベルの解析データを生成
 * @param {OpenAI} openai - OpenAIクライアント
 * @param {string} model - 使用するモデル
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {number} level - 解析レベル (20, 50, 100)
 * @return {Promise<Object>} - レベル別解析データ
 */
async function generateAnalysisLevel(openai, model, big5Scores, gender, level) {
  const categories = level === 20 ?
    ["career", "romance", "stress"] :
    ["career", "romance", "stress", "learning", "decision"];

  const prompt = createPrompt(big5Scores, gender, level, categories);

  const maxRetries = 3;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
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
      const result = JSON.parse(content);
      console.log(`✅ Generated analysis_${level} on attempt ${attempt}`);
      return result;
    } catch (error) {
      console.error(`❌ Analysis_${level} attempt ${attempt} failed:`, error.message);

      if (attempt === maxRetries) {
        throw new Error(`OpenAI API failed for level ${level} after ${maxRetries} attempts: ${error.message}`);
      }

      // 指数バックオフで待機
      await new Promise((resolve) =>
        setTimeout(resolve, Math.pow(2, attempt) * 1000));
    }
  }
}

/**
 * プロンプト生成
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {number} level - 解析レベル
 * @param {Array<string>} categories - カテゴリーリスト
 * @return {string} - プロンプト
 */
function createPrompt(big5Scores, gender, level, categories) {
  const levelDescription = {
    20: "基本的な性格傾向の概要",
    50: "より詳細な行動パターンと具体例",
    100: "完全な性格解析と深い洞察",
  }[level];

  const categoryDescriptions = {
    career: "仕事・キャラクタースタイル",
    romance: "恋愛・人間関係の特徴",
    stress: "ストレス対処・感情管理",
    learning: "学習・成長アプローチ",
    decision: "意思決定・問題解決スタイル",
  };

  return `以下のBig5性格特性と性別に基づいて、性格解析を生成してください。

Big5スコア (1-5の範囲):
- 開放性 (Openness): ${big5Scores.openness}
- 誠実性 (Conscientiousness): ${big5Scores.conscientiousness}
- 外向性 (Extraversion): ${big5Scores.extraversion}
- 協調性 (Agreeableness): ${big5Scores.agreeableness}
- 神経症傾向 (Neuroticism): ${big5Scores.neuroticism}

性別: ${gender === "male" ? "男性" : "女性"}
解析レベル: ${level}問回答時点 (${levelDescription})

以下のカテゴリーについて解析してください:
${categories.map((cat) => `- ${categoryDescriptions[cat]}`).join("\n")}

各カテゴリーごとに以下の形式で出力してください:
{
  "career": {
    "personality_type": "この分野での性格タイプを一言で (例: 「協調型リーダー」「慎重な意思決定者」)",
    "detailed_text": "この性格特性がこの分野でどのように現れるか、${level === 20 ? "200-300" : level === 50 ? "300-400" : "400-500"}文字で詳細に説明",
    "key_points": ["特徴1", "特徴2", "特徴3"]
  },
  "romance": {
    "personality_type": "...",
    "detailed_text": "...",
    "key_points": ["...", "...", "..."]
  },
  "stress": {
    "personality_type": "...",
    "detailed_text": "...",
    "key_points": ["...", "...", "..."]
  }${categories.includes("learning") ? `,
  "learning": {
    "personality_type": "...",
    "detailed_text": "...",
    "key_points": ["...", "...", "..."]
  }` : ""}${categories.includes("decision") ? `,
  "decision": {
    "personality_type": "...",
    "detailed_text": "...",
    "key_points": ["...", "...", "..."]
  }` : ""}
}

重要な注意事項:
- キー名は必ず "career", "romance", "stress", "learning", "decision" を使用してください
- "relationships", "stress_management", "learning_growth", "decision_making" などの別名は使用しないでください
- personality_typeは15文字以内の簡潔な表現
- detailed_textは具体的で実用的な内容にする
- key_pointsは3つの要点を箇条書きで
- 数値（スコア）は出力に含めない
- 自然な日本語で記述
- JSONフォーマットで出力`;
}

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
    neuroticism: parseInt(parts[4].substring(1)),
  };

  const gender = parts[5];

  return {big5Scores, gender};
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
        const {personalityKey, isPremium} = data;

        if (!personalityKey) {
          throw new Error("personalityKey is required");
        }

        // personalityKeyから Big5Scores と gender を解析
        const {big5Scores, gender} = parsePersonalityKey(personalityKey);

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
        throw new Error(`Big5分析生成に失敗しました: ${error.message}`);
      }
    },
);

module.exports = {generateBig5Analysis, generateBig5AnalysisCallable};
