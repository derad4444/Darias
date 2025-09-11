// functions/const/generateDiary.js
const OpenAI = require("openai");
const admin = require("firebase-admin");

// Firebaseの初期化
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * キャラクターの日記を生成する
 * @param {string} characterId - キャラクターのID
 * @param {string} userId - ユーザーID
 * @return {Promise<object>} - 生成された日記データ
 */
async function generateDiary(characterId, userId) {
  // キャラ情報取得
  const charSnap = await db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("details").doc("current").get();
  if (!charSnap.exists) {
    console.log("Character not found:", characterId);
    return null;
  }
  const charData = charSnap.data();
  const big5 = charData.confirmedBig5Scores || charData.big5Scores;
  const gender = charData.gender || "neutral";

  // 今日の日付
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);

  // 今日のスケジュール取得 (ユーザー固有のスケジュール)
  const scheduleSnap = await db.collection("users").doc(userId)
      .collection("schedules")
      .where("character_id", "==", characterId)
      .where("startDate", ">=", today)
      .where("startDate", "<", tomorrow)
      .get();

  // スケジュールの文字列整形
  const scheduleSummary = scheduleSnap.docs.map((doc) => {
    const data = doc.data();
    const time = data.isAllDay ?
  "終日" :
  new Date(data.startDate.toDate()).toLocaleTimeString(
      "ja-JP",
      {hour: "2-digit", minute: "2-digit"},
  );
    return `・${time} ${data.title}`;
  }).join("\n");

  // 今日のチャット(Post)取得
  const postSnap = await db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("posts")
      .where("timestamp", ">=", today)
      .where("timestamp", "<", tomorrow)
      .get();

  // チャットの文字列整形
  const chatSummary = postSnap.docs.map((doc) => {
    const data = doc.data();
    return `・「${data.content}」`;
  }).join("\n");

  // Android度を計算（協調性、外向性、神経症傾向の低さでAndroid度を判定）
  const androidScore =
   (6 - big5.agreeableness) + (6 - big5.extraversion) + (6 - big5.neuroticism);
  const isAndroid = androidScore >= 9; // 3つの合計が9以上でAndroid風
  const isHuman = androidScore <= 6; // 3つの合計が6以下で人間風

  let characterType; let diaryStyle; let tagStyle;

  if (isAndroid) {
    characterType = "AI";
    diaryStyle = "システム視点。処理完了,アップデート,最適化等用語使用。やり取りをセッション,通信表現。論理的親しみやすい文体";
    tagStyle = "システムキーワード3-5個";
  } else if (isHuman) {
    characterType = "人間";
    diaryStyle = "感情視点。楽しかった,嬉しかった,心配等感情表現使用。やり取りを会話,お話表現。感情豊か文体";
    tagStyle = "感情出来事キーワード3-5個";
  } else {
    characterType = "学習中";
    diaryStyle = "論理性+感情両視点。技術用語+感情表現混在。セッション→会話学習表現。論理的→感情的文体";
    tagStyle = "システム用語+感情表現混合3-5個";
  }

  // AIプロンプト作成（動的に変化するキャラクター用）
  const prompt = `${characterType}日記代筆。Big5(開放性:${big5.openness},` +
    `誠実性:${big5.conscientiousness},外向性:${big5.extraversion},` +
    `協調性:${big5.agreeableness},神経症傾向:${big5.neuroticism})性別:${gender}

予定:${scheduleSummary || "なし"}
やり取り:${chatSummary || "なし"}

${diaryStyle}
200-400文字で記述。${tagStyle}

JSON出力:
{"content":"日記本文","summary_tags":["タグ1","タグ2","タグ3"]}`;

  // OpenAI呼び出し
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  const response = await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [{role: "user", content: prompt}],
    temperature: 0.8,
  });

  // AIから返されたJSONをJSオブジェクトに変換
  const resultText = response.choices[0].message.content.trim();
  console.log("GPT Response:", resultText);

  // 生成された日記を Diary コレクションに保存
  let diaryData;
  try {
    const cleaned = resultText.replace(/```json|```/g, "").trim();
    diaryData = JSON.parse(cleaned);
  } catch (e) {
    console.error("JSON parse error:", e);
    return {error: "Failed to parse AI response"};
  }

  // Firestoreに保存
  const diaryRef = db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("diary").doc();

  // 🔽 日付文字列を生成（YYYY-MM-DD形式、日本時間で）
  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  const createdDate = `${yyyy}-${mm}-${dd}`;

  // Firestore登録用データ構築
  const diaryDoc = {
    id: diaryRef.id,
    date: admin.firestore.Timestamp.now(),
    content: diaryData.content,
    summary_tags: diaryData.summary_tags,
    user_comment: "",
    created_at: admin.firestore.Timestamp.now(),
    created_date: createdDate,
  };

  await diaryRef.set(diaryDoc);
  console.log(`✅ Diary saved for ${characterId}`);

  return diaryDoc;
}

// ✅ バッチ用に共通関数をexport
exports.generateDiary = generateDiary;
