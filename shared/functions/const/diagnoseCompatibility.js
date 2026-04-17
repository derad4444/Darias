// functions/const/diagnoseCompatibility.js
// カテゴリ別相性診断を生成するCloud Function

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");
const {FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();

// ============================================================
// カテゴリ設定
// ============================================================
const CATEGORY_CONFIGS = {
  friendship: {
    label: "友情",
    topic: "友人としての日常的な付き合い方・笑いのセンス・困った時に頼れるか",
    commentLabel: "友情の現状（30文字以内）",
    adviceLabel: "友情をよりよくするアドバイス（60文字以内）",
  },
  romance: {
    label: "恋愛",
    topic: "感情的な共鳴・ドキドキ感と安心感のバランス・愛情表現のスタイル",
    commentLabel: "恋愛相性の現状（30文字以内・控えめに）",
    adviceLabel: "恋愛面でのアドバイス（60文字以内）",
  },
  work: {
    label: "仕事",
    topic: "役割分担・アイデア出し・締め切り意識・お互いの強みの活かし方",
    commentLabel: "仕事相性の現状（30文字以内）",
    adviceLabel: "仕事でうまくやるためのアドバイス（60文字以内）",
  },
  trust: {
    label: "信頼",
    topic: "誠実さ・約束を守る姿勢・正直に話せるか・長期的な信頼関係",
    commentLabel: "信頼関係の現状（30文字以内）",
    adviceLabel: "信頼をさらに深めるアドバイス（60文字以内）",
  },
};

// ============================================================
// BIG5指紋・キャッシュキー生成
// ============================================================
function toFingerprint(info) {
  return `o${info.openness}c${info.conscientiousness}e${info.extraversion}a${info.agreeableness}n${info.neuroticism}`;
}

// ============================================================
// キャラクター情報（BIG5 + 性別）を取得
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
// スコア計算（決定論的）
// ============================================================
function calcSimilarity(a, b) {
  const diff = Math.abs(a - b);
  return Math.max(0, 100 - diff * 20);
}

function calcGenreScores(my, friend) {
  const friendship = Math.round(
      calcSimilarity(my.extraversion, friend.extraversion) * 0.4 +
      (my.agreeableness + friend.agreeableness) / 2 * 20 * 0.4 +
      (100 - Math.abs(my.neuroticism - friend.neuroticism) * 15) * 0.2,
  );

  const romanceBase = Math.round(
      calcSimilarity(my.neuroticism, friend.neuroticism) * 0.4 +
      (my.agreeableness + friend.agreeableness) / 2 * 20 * 0.35 +
      calcSimilarity(my.openness, friend.openness) * 0.25,
  );
  const romance = Math.min(82, Math.max(20, romanceBase));

  const work = Math.round(
      (my.conscientiousness + friend.conscientiousness) / 2 * 20 * 0.5 +
      calcSimilarity(my.openness, friend.openness) * 0.5,
  );

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
// ユーザードキュメントへの保存
// ============================================================
async function saveToUserDoc(userId, friendId, category, categoryData, scores) {
  try {
    const docRef = db.collection("users").doc(userId)
        .collection("compatibilityResults").doc(friendId);

    await docRef.set(
        {
          scores,
          [category]: {
            comment: categoryData.comment,
            advice: categoryData.advice,
            conversation: categoryData.conversation,
            big5Key: categoryData.big5Key,
            createdAt: categoryData.createdAt ?? new Date(),
          },
          unlockedCategories: FieldValue.arrayUnion(category),
        },
        {merge: true},
    );
  } catch (e) {
    console.warn("saveToUserDoc error:", e.message);
  }
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
      const {userId, friendId, category} = request.data;

      if (!userId || !friendId || !category) {
        return {error: "Missing userId, friendId, or category"};
      }

      const config = CATEGORY_CONFIGS[category];
      if (!config) {
        return {error: `Unknown category: ${category}`};
      }

      // 双方のキャラクター情報を取得
      const [myInfo, friendInfo] = await Promise.all([
        fetchCharacterInfo(userId),
        fetchCharacterInfo(friendId),
      ]);

      if (!myInfo || !friendInfo) {
        return {error: "BIG5データが不足しています"};
      }

      // スコア計算（全カテゴリ、決定論的）
      const scores = calcGenreScores(myInfo, friendInfo);
      const categoryScore = scores[category];

      // BIG5キー生成
      const myFp = toFingerprint(myInfo);
      const friendFp = toFingerprint(friendInfo);
      const sorted = [myFp, friendFp].sort();
      const big5Key = `${sorted[0]}|${sorted[1]}`;
      const needsFlip = sorted[0] !== myFp;

      // カテゴリ別キャッシュを確認
      const cacheKey = `${big5Key}_${category}`;
      const cacheRef = db.collection("compatibilityCache").doc(cacheKey);
      const cacheDoc = await cacheRef.get();

      if (cacheDoc.exists) {
        console.log(`✅ カテゴリキャッシュヒット: ${cacheKey}`);
        const cached = cacheDoc.data();
        const conversation = (cached.conversation ?? []).map((msg) => ({
          ...msg,
          isMyCharacter: needsFlip ? !msg.isMyCharacter : msg.isMyCharacter,
        }));
        const resultData = {...cached, conversation, scores};

        await saveToUserDoc(userId, friendId, category, {...cached, conversation}, scores);
        return resultData;
      }

      // ─────────────────────────────────────────
      // キャッシュなし → AI生成（カテゴリ特化）
      // ─────────────────────────────────────────
      const mySpeech = buildSpeechStyle(myInfo, "自分キャラ");
      const friendSpeech = buildSpeechStyle(friendInfo, "相手キャラ");

      const systemPrompt = `あなたは2人のキャラクターが${config.label}面での相性について語り合う会話を生成するAIです。

【重要なルール】
- 会話は4〜5ターン（交互に話す）
- 各キャラクターは指定された口調・一人称を必ず守る
- キャラクターの名前は「自分」「相手」とだけ呼ぶ（固有名詞は使わない）
- 話題は「${config.topic}」に集中する
- 自然で温かみのある会話として生成する
- コメントは現状を表す30文字以内の短文
- アドバイスはBIG5の特性を活かした具体的な行動提案（60文字以内）

必ずJSON形式で返してください:
{
  "conversation": [
    {"isMyCharacter": true, "text": "..."},
    {"isMyCharacter": false, "text": "..."}
  ],
  "comment": "${config.commentLabel}",
  "advice": "${config.adviceLabel}"
}`;

      const userPrompt = `${mySpeech}

${friendSpeech}

【${config.label}スコア: ${categoryScore}%】

この2人が${config.label}の相性診断結果について自然に語り合う会話を生成してください。`;

      const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

      let gptResult = null;
      try {
        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4.1-mini",
              messages: [
                {role: "system", content: systemPrompt},
                {role: "user", content: userPrompt},
              ],
              temperature: 0.75,
              max_tokens: 600,
              response_format: {type: "json_object"},
            },
        );
        const raw = completion?.choices?.[0]?.message?.content?.trim() ?? "{}";
        gptResult = JSON.parse(raw);
      } catch (e) {
        console.warn("GPT error:", e.message);
        gptResult = {
          conversation: [
            {isMyCharacter: true, text: `${config.label}の相性は${categoryScore}%だって`},
            {isMyCharacter: false, text: "そうなんだ、どんな感じだった？"},
            {isMyCharacter: true, text: `${config.topic.split("・")[0]}が特に気になったよ`},
            {isMyCharacter: false, text: "なるほど、これからも仲良くしていこうね"},
            {isMyCharacter: true, text: "うん、よろしくね！"},
          ],
          comment: `${config.label}の相性は${categoryScore}%`,
          advice: `${config.topic.split("・")[0]}を意識して関わってみよう`,
        };
      }

      const categoryData = {
        comment: gptResult.comment ?? "",
        advice: gptResult.advice ?? "",
        conversation: gptResult.conversation ?? [],
        big5Key,
        createdAt: new Date(),
      };

      // カテゴリ別キャッシュに保存
      try {
        await cacheRef.set(categoryData);
      } catch (e) {
        console.warn("Cache save error:", e.message);
      }

      // ユーザードキュメントに保存
      await saveToUserDoc(userId, friendId, category, categoryData, scores);

      return {...categoryData, scores};
    },
);
