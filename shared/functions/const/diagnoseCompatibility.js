// functions/const/diagnoseCompatibility.js
// フレンドとの相性診断を生成するCloud Function

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const db = getFirestore();

// BIG5スコアを取得
async function fetchBig5Scores(userId) {
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

    const scores = detail["confirmedBig5Scores"];
    if (!scores) return null;

    return {
      openness: scores.openness ?? 3,
      conscientiousness: scores.conscientiousness ?? 3,
      extraversion: scores.extraversion ?? 3,
      agreeableness: scores.agreeableness ?? 3,
      neuroticism: scores.neuroticism ?? 3,
      answeredCount: detail["answeredCount"] ?? 0,
      name: userData["name"] ?? "あなた",
    };
  } catch (e) {
    console.warn("fetchBig5Scores error:", e.message);
    return null;
  }
}

// スコア差から相性値（0〜100）を計算
function calcSimilarity(a, b, invert = false) {
  const diff = Math.abs(a - b);
  const similarity = Math.max(0, 100 - diff * 20);
  return invert ? 100 - similarity : similarity;
}

// ジャンル別スコア計算
function calcGenreScores(my, friend) {
  // 友情: 外向性の近さ + 協調性の高さ
  const friendship = Math.round(
      (calcSimilarity(my.extraversion, friend.extraversion) * 0.4 +
      calcSimilarity(my.agreeableness, friend.agreeableness) * 0.4 +
      (100 - Math.abs(my.neuroticism - friend.neuroticism) * 15) * 0.2),
  );

  // 恋愛: 神経症傾向の安定さ + 協調性 + 外向性の適度な差
  const romanceDiff = Math.abs(my.extraversion - friend.extraversion);
  const romanceExtra = romanceDiff > 1.5 ? 70 : 85; // 少し違うほうが刺激的
  const romance = Math.round(
      (calcSimilarity(my.neuroticism, friend.neuroticism) * 0.35 +
      (my.agreeableness + friend.agreeableness) / 2 * 20 * 0.35 +
      romanceExtra * 0.3),
  );

  // 仕事: 誠実性の高さ + 開放性の近さ
  const work = Math.round(
      ((my.conscientiousness + friend.conscientiousness) / 2 * 20 * 0.5 +
      calcSimilarity(my.openness, friend.openness) * 0.5),
  );

  // 信頼: 協調性 + 神経症傾向の低さ
  const trust = Math.round(
      ((my.agreeableness + friend.agreeableness) / 2 * 20 * 0.5 +
      (100 - (my.neuroticism + friend.neuroticism) / 2 * 15) * 0.5),
  );

  const overall = Math.round((friendship + romance + work + trust) / 4);

  return {
    friendship: Math.min(100, Math.max(0, friendship)),
    romance: Math.min(100, Math.max(0, romance)),
    work: Math.min(100, Math.max(0, work)),
    trust: Math.min(100, Math.max(0, trust)),
    overall: Math.min(100, Math.max(0, overall)),
  };
}

exports.diagnoseCompatibility = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 90,
      minInstances: 0,
      enforceAppCheck: false,
    },
    async (request) => {
      const {data} = request;
      const {userId, friendId, myCharacterId} = data;

      if (!userId || !friendId) {
        return {error: "Missing userId or friendId"};
      }

      // 双方のBIG5スコアを取得
      const [myScores, friendScores] = await Promise.all([
        fetchBig5Scores(userId),
        fetchBig5Scores(friendId),
      ]);

      if (!myScores || !friendScores) {
        return {error: "BIG5データが不足しています"};
      }

      // ジャンル別スコア計算
      const scores = calcGenreScores(myScores, friendScores);

      // GPTでキャラクター会話 + コメント生成
      const systemPrompt = `あなたはキャラクター同士の相性診断の会話を生成するAIです。
2人のキャラクター（${myScores.name}と${friendScores.name}）がBIG5性格診断の結果をもとに、
相性について会話しています。会話は6〜8ターン程度、自然でフレンドリーな口調で生成してください。
また、ジャンルごとの一言コメントも生成してください。

形式は必ずJSON形式で返してください:
{
  "conversation": [
    {"isMyCharacter": true, "text": "..."},
    {"isMyCharacter": false, "text": "..."},
    ...
  ],
  "friendshipComment": "友情についての一言（30文字以内）",
  "romanceComment": "恋愛についての一言（30文字以内）",
  "workComment": "仕事についての一言（30文字以内）",
  "trustComment": "信頼についての一言（30文字以内）",
  "overallComment": "総合コメント（50文字以内）"
}`;

      const userPrompt = `
【${myScores.name}（自分）のBIG5スコア】
- 開放性: ${myScores.openness}/5
- 誠実性: ${myScores.conscientiousness}/5
- 外向性: ${myScores.extraversion}/5
- 協調性: ${myScores.agreeableness}/5
- 神経症傾向: ${myScores.neuroticism}/5

【${friendScores.name}のBIG5スコア】
- 開放性: ${friendScores.openness}/5
- 誠実性: ${friendScores.conscientiousness}/5
- 外向性: ${friendScores.extraversion}/5
- 協調性: ${friendScores.agreeableness}/5
- 神経症傾向: ${friendScores.neuroticism}/5

【相性スコア（参考）】
- 友情: ${scores.friendship}%
- 恋愛: ${scores.romance}%
- 仕事: ${scores.work}%
- 信頼: ${scores.trust}%
- 総合: ${scores.overall}%

キャラクター同士がこの相性結果を語り合う会話と、各ジャンルのコメントを生成してください。
`;

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
              temperature: 0.8,
              max_tokens: 1200,
              response_format: {type: "json_object"},
            },
        );

        const raw = completion?.choices?.[0]?.message?.content?.trim() ?? "{}";
        gptResult = JSON.parse(raw);
      } catch (e) {
        console.warn("GPT error:", e.message);
        // フォールバック
        gptResult = {
          conversation: [
            {isMyCharacter: true, text: `${friendScores.name}、相性を診断してみたよ！`},
            {isMyCharacter: false, text: `わあ、気になる！どんな結果だった？`},
            {isMyCharacter: true, text: `総合${scores.overall}%だって。なかなかいい感じだね`},
            {isMyCharacter: false, text: `それは嬉しい！これからも仲良くしようね`},
          ],
          friendshipComment: "気を使わない関係が築けそう",
          romanceComment: "お互いを高め合える関係",
          workComment: "役割分担が自然にできるコンビ",
          trustComment: "何でも話せる信頼関係",
          overallComment: "一緒にいると自然体でいられる関係です",
        };
      }

      return {
        friendshipScore: scores.friendship,
        romanceScore: scores.romance,
        workScore: scores.work,
        trustScore: scores.trust,
        overallScore: scores.overall,
        friendshipComment: gptResult.friendshipComment ?? "",
        romanceComment: gptResult.romanceComment ?? "",
        workComment: gptResult.workComment ?? "",
        trustComment: gptResult.trustComment ?? "",
        overallComment: gptResult.overallComment ?? "",
        conversation: gptResult.conversation ?? [],
      };
    },
);
