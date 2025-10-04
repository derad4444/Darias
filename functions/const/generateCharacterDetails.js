const OpenAI = require("openai");
const admin = require("firebase-admin");
const {generatePersonalityKey} = require("./generatePersonalityKey");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * Big5スコアからキャラクターの性格詳細（favorite_color〜dream）を生成
 * @param {string} characterId - キャラクターID
 * @param {string} userId - ユーザーID
 * @param {string} apiKey - OpenAI APIキー
 */
async function generateCharacterDetails(characterId, userId, apiKey) {
  try {
    const charSnap = await db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("details").doc("current").get();

    if (!charSnap.exists) {
      console.log("❌ Character not found:", characterId);
      return null;
    }

    const data = charSnap.data();
    const big5Scores = data.confirmedBig5Scores || data.big5Scores;
    const gender = data.gender || "neutral";

    const openai = new OpenAI({apiKey});

    const prompt = OPTIMIZED_PROMPTS.characterDetails(big5Scores, gender);

    // OpenAIリクエスト送信
    const res = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{role: "user", content: prompt}],
      temperature: 0.7,
    });

    // もしマークダウン記法が付いていたら除去する
    let content = res.choices[0].message.content.trim();
    if (content.startsWith("```json")) {
      content = content.replace(/^```json\s*/, "").replace(/```$/, "").trim();
    }

    let characterData;
    try {
      characterData = JSON.parse(content);
    } catch (err) {
      throw new Error("GPT出力のパースに失敗しました: " + err.message);
    }

    // personalityKey生成
    const personalityKey = generatePersonalityKey(big5Scores);

    // Firestoreに保存（新しいコレクション構造に保存）
    await db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("details").doc("current").update({
          ...characterData,
          personalityKey: personalityKey,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

    console.log(`✅ 生成成功: ${characterId}`);
    return characterData;
  } catch (err) {
    console.error(`❌ 詳細生成失敗: ${characterId}`, err);
  }
}

module.exports = {generateCharacterDetails};
