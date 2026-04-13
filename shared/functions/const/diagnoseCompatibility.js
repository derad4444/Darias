// functions/const/diagnoseCompatibility.js
// フレンドとの相性診断を生成するCloud Function

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const db = getFirestore();

// ============================================================
// キャラクター情報（BIG5 + 性別 + 性格）を取得
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

    const scores = detail["confirmedBig5Scores"];
    if (!scores) return null;

    const gender = detail["gender"] ?? userData["characterGender"] ?? "女性";
    const personalityKey = detail["personalityKey"] ?? "";

    return {
      openness: scores.openness ?? 3,
      conscientiousness: scores.conscientiousness ?? 3,
      extraversion: scores.extraversion ?? 3,
      agreeableness: scores.agreeableness ?? 3,
      neuroticism: scores.neuroticism ?? 3,
      name: userData["name"] ?? "あなた",
      gender,
      personalityKey,
    };
  } catch (e) {
    console.warn("fetchCharacterInfo error:", e.message);
    return null;
  }
}

// ============================================================
// 性別 + BIG5から口調の説明を生成
// ============================================================
function buildSpeechStyle(info) {
  const isFemale = info.gender === "女性";
  const e = info.extraversion; // 外向性
  const a = info.agreeableness; // 協調性
  const n = info.neuroticism; // 神経症傾向
  const o = info.openness; // 開放性
  const c = info.conscientiousness; // 誠実性

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

  // 協調性が高い → 相手を立てる言い回し
  if (a >= 4) tone += "。相手を気遣う優しい表現を好む";
  // 神経症傾向が高い → 少し不安がり
  if (n >= 4) tone += "。少し心配性で感情豊かな面がある";
  // 開放性が高い → 好奇心旺盛
  if (o >= 4) tone += "。好奇心旺盛で新しいことに興味を示す";
  // 誠実性が高い → 丁寧な言い方
  if (c >= 4) tone += "。物事をしっかり考えてから話す";

  return `一人称:「${pronoun}」、口調:${tone}`;
}

// ============================================================
// ジャンル別スコア計算
// ============================================================
function calcSimilarity(a, b) {
  const diff = Math.abs(a - b);
  return Math.max(0, 100 - diff * 20);
}

function calcGenreScores(my, friend) {
  // 友情: 外向性の近さ + 協調性の高さ + 感情の安定さ
  const friendship = Math.round(
      calcSimilarity(my.extraversion, friend.extraversion) * 0.4 +
      (my.agreeableness + friend.agreeableness) / 2 * 20 * 0.4 +
      (100 - Math.abs(my.neuroticism - friend.neuroticism) * 15) * 0.2,
  );

  // 恋愛: スコアを抑えめに（最大85%程度）+ 感情安定 + 協調性
  // 「相性が良い可能性」程度の表現にとどめる
  const romanceBase = Math.round(
      calcSimilarity(my.neuroticism, friend.neuroticism) * 0.4 +
      (my.agreeableness + friend.agreeableness) / 2 * 20 * 0.35 +
      calcSimilarity(my.openness, friend.openness) * 0.25,
  );
  const romance = Math.min(82, Math.max(20, romanceBase)); // 上限82%でロマンチックになりすぎを防ぐ

  // 仕事: 誠実性の高さ + 開放性の近さ
  const work = Math.round(
      (my.conscientiousness + friend.conscientiousness) / 2 * 20 * 0.5 +
      calcSimilarity(my.openness, friend.openness) * 0.5,
  );

  // 信頼: 協調性 + 神経症傾向の低さ + 誠実性
  const trust = Math.round(
      (my.agreeableness + friend.agreeableness) / 2 * 20 * 0.4 +
      (100 - (my.neuroticism + friend.neuroticism) / 2 * 15) * 0.35 +
      (my.conscientiousness + friend.conscientiousness) / 2 * 20 * 0.25,
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

// ============================================================
// Cloud Function本体
// ============================================================
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
      const {userId, friendId} = data;

      if (!userId || !friendId) {
        return {error: "Missing userId or friendId"};
      }

      // 双方のキャラクター情報を取得
      const [myInfo, friendInfo] = await Promise.all([
        fetchCharacterInfo(userId),
        fetchCharacterInfo(friendId),
      ]);

      if (!myInfo || !friendInfo) {
        return {error: "BIG5データが不足しています"};
      }

      // スコア計算
      const scores = calcGenreScores(myInfo, friendInfo);

      // 口調スタイル
      const mySpeech = buildSpeechStyle(myInfo);
      const friendSpeech = buildSpeechStyle(friendInfo);

      // GPT会話・コメント生成
      const systemPrompt = `あなたは2人のキャラクター同士の相性診断会話を生成するAIです。

【重要なルール】
- 会話は6〜8ターン（交互に話す）
- 各キャラクターは指定された口調・一人称を必ず守る
- 恋愛については「もしかしたら相性が良いかも」程度に留め、過度にロマンチックな表現は避ける
- 現実的で自然な友人同士の会話として生成する
- 各ジャンルのコメントは具体的で、30文字以内の短文
- 恋愛コメントは「〜かもしれない」「〜の可能性がある」など可能性の表現にする

必ずJSON形式で返してください:
{
  "conversation": [
    {"isMyCharacter": true, "text": "..."},
    {"isMyCharacter": false, "text": "..."}
  ],
  "friendshipComment": "友情の一言（30文字以内）",
  "romanceComment": "恋愛可能性の一言（30文字以内・控えめに）",
  "workComment": "仕事相性の一言（30文字以内）",
  "trustComment": "信頼関係の一言（30文字以内）",
  "overallComment": "総合まとめ（50文字以内）"
}`;

      const userPrompt = `
【${myInfo.name}のキャラクター設定】
${mySpeech}
BIG5: 開放性${myInfo.openness} 誠実性${myInfo.conscientiousness} 外向性${myInfo.extraversion} 協調性${myInfo.agreeableness} 神経症${myInfo.neuroticism}

【${friendInfo.name}のキャラクター設定】
${friendSpeech}
BIG5: 開放性${friendInfo.openness} 誠実性${friendInfo.conscientiousness} 外向性${friendInfo.extraversion} 協調性${friendInfo.agreeableness} 神経症${friendInfo.neuroticism}

【相性スコア（参考）】
友情:${scores.friendship}% / 恋愛:${scores.romance}% / 仕事:${scores.work}% / 信頼:${scores.trust}% / 総合:${scores.overall}%

この2人が相性診断の結果を自然に語り合う会話を生成してください。
恋愛については軽く触れる程度にし、友情・信頼・仕事の話題を中心にしてください。`;

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
              temperature: 0.75,
              max_tokens: 1200,
              response_format: {type: "json_object"},
            },
        );
        const raw = completion?.choices?.[0]?.message?.content?.trim() ?? "{}";
        gptResult = JSON.parse(raw);
      } catch (e) {
        console.warn("GPT error:", e.message);
        gptResult = {
          conversation: [
            {isMyCharacter: true, text: `${friendInfo.name}、相性診断してみたよ`},
            {isMyCharacter: false, text: `どうだった？気になる`},
            {isMyCharacter: true, text: `総合${scores.overall}%だって！なかなかいい感じだと思う`},
            {isMyCharacter: false, text: `それは嬉しいね、これからも仲良くしよう`},
          ],
          friendshipComment: "気を使わない関係が築けそう",
          romanceComment: "相性が良い可能性はありそう",
          workComment: "役割分担が自然にできるコンビ",
          trustComment: "何でも話せる信頼関係",
          overallComment: "一緒にいると自然体でいられる関係です",
        };
      }

      const resultData = {
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
        createdAt: new Date(),
      };

      // 結果をFirestoreに保存（両方向）
      try {
        const batch = db.batch();
        batch.set(
            db.collection("users").doc(userId)
                .collection("compatibilityResults").doc(friendId),
            resultData,
        );
        batch.set(
            db.collection("users").doc(friendId)
                .collection("compatibilityResults").doc(userId),
            resultData,
        );
        await batch.commit();
      } catch (e) {
        console.warn("Save result error:", e.message);
      }

      return resultData;
    },
);
