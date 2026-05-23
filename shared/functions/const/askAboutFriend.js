// functions/const/askAboutFriend.js
// フレンドの好みをキャラクター会話形式で回答するCloud Function

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const db = getFirestore();

// ============================================================
// キャラクター情報（BIG5 + 性別）を取得（diagnoseCompatibilityと同様）
// ============================================================
async function fetchCharacterInfo(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    if (!userData) return null;

    const characterId = userData["character_id"];
    if (!characterId) return null;

    const detailDoc = await db
        .collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("details").doc("current")
        .get();

    const detail = detailDoc.data();
    if (!detail) return null;

    const analysisLevel = detail["analysis_level"] ?? 0;
    const scores = (analysisLevel > 0 ? detail["confirmedBig5Scores"] : null) ?? detail["convertedBig5Scores"];
    if (!scores) return null;

    const gender = detail["gender"] ?? userData["characterGender"] ?? "女性";

    return {
      openness: scores.openness ?? 3,
      conscientiousness: scores.conscientiousness ?? 3,
      extraversion: scores.extraversion ?? 3,
      agreeableness: scores.agreeableness ?? 3,
      neuroticism: scores.neuroticism ?? 3,
      gender,
    };
  } catch (e) {
    console.warn("fetchCharacterInfo error:", e.message);
    return null;
  }
}

// ============================================================
// 性別 + BIG5から口調の説明を生成
// ============================================================
function buildSpeechStyle(info, label) {
  const isFemale = info.gender === "女性";
  const e = info.extraversion;
  const a = info.agreeableness;
  const n = info.neuroticism;
  const o = info.openness;
  const c = info.conscientiousness;

  const pronoun = isFemale ? "私" : (e >= 4 ? "俺" : "僕");
  let tone = "";

  if (isFemale) {
    if (e >= 4) tone = "明るく社交的で、語尾に「〜だよ」「〜ね」「〜かな」を使う元気な女の子";
    else if (e <= 2) tone = "おっとりしていて、「〜かな」「〜ね」「〜だと思う」など落ち着いた口調の女の子";
    else tone = "自然体で「〜だよ」「〜ね」「〜かな」をバランスよく使う女の子";
  } else {
    if (e >= 4) tone = `ハキハキしていて「${pronoun}はさ」「〜だよな」「〜じゃん」など活発な男の子`;
    else if (e <= 2) tone = `控えめで「〜だと思う」「〜かな」「〜だね」など落ち着いた口調の男の子`;
    else tone = `「〜だね」「〜かな」「${pronoun}は〜」など普通の口調の男の子`;
  }

  if (a >= 4) tone += "。相手を気遣う優しい表現を好む";
  if (n >= 4) tone += "。少し心配性で感情豊かな面がある";
  if (o >= 4) tone += "。好奇心旺盛で新しいことに興味を示す";
  if (c >= 4) tone += "。物事をしっかり考えてから話す";

  return `【${label}】一人称:「${pronoun}」、口調:${tone}\nBIG5: 開放性${o} 誠実性${c} 外向性${e} 協調性${a} 神経症${n}`;
}

// ============================================================
// Cloud Function本体
// ============================================================
exports.askAboutFriend = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 90,
      enforceAppCheck: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "認証が必要です");
      }
      const {userId, friendId, friendName, question} = request.data;
      if (request.auth.uid !== userId) {
        throw new HttpsError("permission-denied", "ユーザーIDが一致しません");
      }
      if (!userId || !friendId || !question) {
        return {error: "Missing userId, friendId, or question"};
      }
      if (question.length > 100) {
        return {error: "質問が長すぎます"};
      }

      const [myInfo, friendInfo] = await Promise.all([
        fetchCharacterInfo(userId),
        fetchCharacterInfo(friendId),
      ]);

      if (!myInfo || !friendInfo) {
        return {error: "BIG5データが不足しています"};
      }

      const mySpeech = buildSpeechStyle(myInfo, "自分キャラ");
      const friendSpeech = buildSpeechStyle(friendInfo, "相手キャラ");

      const systemPrompt = `あなたは2人のキャラクターが「${question}」というテーマで語り合う会話を生成するAIです。

【重要なルール】
- 会話は4〜5ターン（交互に話す）
- 各キャラクターは指定された口調・一人称を必ず守る
- キャラクターの名前は「自分」「相手」とだけ呼ぶ（固有名詞は使わない）
- 「相手キャラ」の発言はBIG5の特性から自然に導き出した好みや傾向を反映させる
- 「自分キャラ」は質問・掘り下げ・まとめ役として振る舞い、最後に具体的な提案をする
- 会話は「自分キャラ」の発言から始める
- recommendation は相手の性格から導き出した具体的な提案（60文字以内）

必ずJSON形式で返してください:
{
  "conversation": [
    {"isMyCharacter": true, "text": "..."},
    {"isMyCharacter": false, "text": "..."}
  ],
  "recommendation": "具体的なおすすめや傾向（60文字以内）"
}`;

      const userPrompt = `${mySpeech}

${friendSpeech}

【テーマ】${question}

この2人が上記テーマについて、相手キャラの性格・好みを探りながら自然に語り合う会話を生成してください。`;

      const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

      let gptResult = null;
      try {
        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [
                {role: "system", content: systemPrompt},
                {role: "user", content: userPrompt},
              ],
              response_format: {type: "json_object"},
            },
        );
        const raw = completion?.choices?.[0]?.message?.content?.trim() ?? "{}";
        gptResult = JSON.parse(raw);
      } catch (e) {
        console.warn("GPT error:", e.message);
        gptResult = {
          conversation: [
            {isMyCharacter: true, text: `${question}について聞いてみるね`},
            {isMyCharacter: false, text: "うーん、自分なりの好みがあるかな"},
            {isMyCharacter: true, text: "もう少し詳しく教えて？"},
            {isMyCharacter: false, text: "性格的にはこだわりより実用重視かも"},
            {isMyCharacter: true, text: "なるほど、参考にするね！"},
          ],
          recommendation: "性格データから具体的な傾向を読み取れませんでした",
        };
      }

      const resultConversation = gptResult.conversation ?? [];
      const resultRecommendation = gptResult.recommendation ?? "";

      // 履歴をFirestoreに保存（非同期・エラーは無視）
      try {
        await db.collection("users").doc(userId).collection("askHistory").add({
          friendId,
          friendName: friendName ?? "",
          question,
          recommendation: resultRecommendation,
          conversation: resultConversation,
          createdAt: new Date(),
        });
      } catch (saveErr) {
        console.warn("askHistory save error:", saveErr.message);
      }

      return {
        conversation: resultConversation,
        recommendation: resultRecommendation,
      };
    },
);
