// functions/const/generateDiary.js
const OpenAI = require("openai");
const admin = require("firebase-admin");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

// Firebase Admin初期化（デフォルトアプリの存在を確認して初期化）
try { admin.app(); } catch (e) { admin.initializeApp(); }
const db = admin.firestore();

/**
 * キャラクターの日記を生成する
 * @param {string} characterId - キャラクターのID
 * @param {string} userId - ユーザーID
 * @return {Promise<object>} - 生成された日記データ
 */
async function generateDiary(characterId, userId) {
  // キャラ情報取得（users/{userId}/characters/{characterId}/details/currentから）
  const charSnap = await db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("details").doc("current").get();
  if (!charSnap.exists) {
    console.log("Character details not found:", characterId, userId);
    return null;
  }
  const charData = charSnap.data();
  const big5 = charData.confirmedBig5Scores;
  const gender = charData.gender || "neutral";

  // キャラクターの個性情報（口癖・話し方・夢・強み）
  const favoriteWord = charData.favorite_word || "";
  const wordTendency = charData.word_tendency || "";
  const dream = charData.dream || "";
  const strength = charData.strength || "";

  // ユーザーのサブスクリプション状態を取得
  let isPremium = false;
  try {
    const userSnap = await db.collection("users").doc(userId).get();
    if (userSnap.exists) {
      const userData = userSnap.data();
      if (userData.subscription && userData.subscription.status === "premium") {
        const expiresAt = userData.subscription.expires_at;
        if (!expiresAt || expiresAt.toDate() > new Date()) {
          isPremium = true;
        }
      }
    }
  } catch (error) {
    console.warn("Failed to check subscription status, using free tier:", error);
  }

  // 今日の日付
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);

  // 手帳（予定）機能の廃止に伴い、予定の取得を日記材料から除外（コメントアウトで残置・復活時に戻す）。
  /*
  // 今日のスケジュール取得 (ユーザー固有のスケジュール)
  const scheduleSnap = await db.collection("users").doc(userId)
      .collection("schedules")
      .where("startDate", ">=", today)
      .where("startDate", "<", tomorrow)
      .limit(3)
      .get();

  // スケジュールの文字列整形
  const scheduleSummary = scheduleSnap.docs.map((doc) => {
    const data = doc.data();
    const time = data.isAllDay ?
  "終日" :
  new Date(data.startDate.toDate()).toLocaleTimeString(
      "ja-JP",
      {hour: "2-digit", minute: "2-digit", timeZone: "Asia/Tokyo"},
  );
    return `・${time} ${data.title}`;
  }).join("\n");

  // 翌日のスケジュール取得（明日への言及に使う）
  const dayAfterTomorrow = new Date(tomorrow);
  dayAfterTomorrow.setDate(tomorrow.getDate() + 1);

  const tomorrowScheduleSnap = await db.collection("users").doc(userId)
      .collection("schedules")
      .where("startDate", ">=", tomorrow)
      .where("startDate", "<", dayAfterTomorrow)
      .orderBy("startDate", "asc")
      .limit(3)
      .get();

  const tomorrowScheduleSummary = tomorrowScheduleSnap.docs.map((doc) => {
    const data = doc.data();
    const time = data.isAllDay ?
  "終日" :
  new Date(data.startDate.toDate()).toLocaleTimeString(
      "ja-JP",
      {hour: "2-digit", minute: "2-digit", timeZone: "Asia/Tokyo"},
  );
    return `・${time} ${data.title}`;
  }).join("\n");
  */

  // 今日のチャット(Post)取得
  const postsQuery = db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("posts")
      .where("timestamp", ">=", today)
      .where("timestamp", "<", tomorrow);

  const postSnap = await postsQuery.limit(5).get();

  // facts用の件数は実数を使う（AIに渡す本文は5件までに絞るため、docs.lengthでは足りない）
  let chatCount = 0;
  try {
    const chatCountSnap = await postsQuery.count().get();
    chatCount = chatCountSnap.data().count;
  } catch (e) {
    // count()が使えない環境では取得済みの件数で代替する
    chatCount = postSnap.size;
  }

  // チャットの文字列整形
  const chatSummary = postSnap.docs.map((doc) => {
    const data = doc.data();
    return `・「${data.content}」`;
  }).join("\n");

  // 手帳（タスク・メモ）機能の廃止に伴い、タスク・メモの取得を日記材料から除外（コメントアウトで残置・復活時に戻す）。
  /*
  // 今日完了したToDo取得（上位3件）
  const completedTodoSnap = await db.collection("users").doc(userId)
      .collection("todos")
      .where("isCompleted", "==", true)
      .where("updatedAt", ">=", today)
      .where("updatedAt", "<", tomorrow)
      .orderBy("updatedAt", "desc")
      .limit(3)
      .get();

  // 完了ToDoの文字列整形
  const completedTodoSummary = completedTodoSnap.docs.map((doc) => {
    const data = doc.data();
    return `・${data.title}`;
  }).join("\n");

  // 今日作成したToDo取得（上位3件）
  const createdTodoSnap = await db.collection("users").doc(userId)
      .collection("todos")
      .where("createdAt", ">=", today)
      .where("createdAt", "<", tomorrow)
      .orderBy("createdAt", "desc")
      .limit(3)
      .get();

  // 作成ToDoの文字列整形
  const createdTodoSummary = createdTodoSnap.docs.map((doc) => {
    const data = doc.data();
    return `・${data.title}`;
  }).join("\n");

  // 今日作成・更新したメモ取得（上位3件）
  const memoSnap = await db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("memos")
      .where("createdAt", ">=", today)
      .where("createdAt", "<", tomorrow)
      .orderBy("createdAt", "desc")
      .limit(3)
      .get();

  // メモの文字列整形
  const memoSummary = memoSnap.docs.map((doc) => {
    const data = doc.data();
    return `・${data.title}`;
  }).join("\n");
  */

  // 今日の冒険（心の迷宮＝ローグライク）のプレイ記録（上位3件）
  let roguelikeSummary = "";
  const roguelikeFacts = [];
  try {
    const runSnap = await db.collection("users").doc(userId)
        .collection("roguelike_runs")
        .where("createdAt", ">=", today)
        .where("createdAt", "<", tomorrow)
        .orderBy("createdAt", "desc")
        .limit(3)
        .get();
    roguelikeSummary = runSnap.docs.map((doc) => {
      const d = doc.data();
      const worry = d.worry || "悩み";
      const resultText = d.result === "clear" ? `「${worry}」を克服した` :
        d.result === "retreat" ? `「${worry}」から撤退した` :
        d.result === "failed" ? `「${worry}」に挑んで力尽きた` :
        `「${worry}」に挑戦した`;
      const defeated = d.enemiesDefeated ? `（敵${d.enemiesDefeated}体撃破）` : "";
      roguelikeFacts.push(`冒険で${resultText}`);
      return `・${resultText}${defeated}`;
    }).join("\n");
  } catch (e) {
    // roguelike_runs が無い/未整備の場合はスキップ
  }

  // 今日の性格診断進捗取得（BIG5回答セッション）
  let big5ProgressSummary = "";
  let big5AnsweredCount = 0;
  try {
    const big5Snap = await db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("big5_sessions")
        .where("createdAt", ">=", today)
        .where("createdAt", "<", tomorrow)
        .limit(1)
        .get();
    if (!big5Snap.empty) {
      const sessionData = big5Snap.docs[0].data();
      const answeredCount = sessionData.answeredCount || sessionData.answers?.length || 0;
      if (answeredCount > 0) {
        big5AnsweredCount = answeredCount;
        big5ProgressSummary = `・性格診断を${answeredCount}問回答`;
      }
    }
  } catch (e) {
    // big5_sessionsが存在しない場合はスキップ
  }

  // 今日の会議（6人会議）取得
  const meetingSnap = await db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("meeting_history")
      .where("createdAt", ">=", today)
      .where("createdAt", "<", tomorrow)
      .limit(2)
      .get();

  // 会議の文字列整形（結論も含める）
  let meetingSummary = "";
  const meetingFacts = [];
  if (!meetingSnap.empty) {
    const meetingPromises = meetingSnap.docs.map(async (doc) => {
      const data = doc.data();
      const concern = data.userConcern || "";

      // 結論を取得
      let conclusion = "";
      if (data.sharedMeetingId) {
        try {
          const sharedDoc = await db.collection("shared_meetings")
              .doc(data.sharedMeetingId).get();
          if (sharedDoc.exists) {
            const sharedData = sharedDoc.data();
            conclusion = sharedData?.conversation?.conclusion?.summary || "";
          }
        } catch (e) {
          console.warn("Failed to fetch shared meeting:", e);
        }
      }

      const fact = concern ?
        `相談「${concern}」について${conclusion ? "結論を出した" : "話し合った"}` :
        "相談をした";

      return {
        line: conclusion ? `・${concern}→${conclusion}` : `・${concern}`,
        fact: fact,
      };
    });

    const results = await Promise.all(meetingPromises);
    meetingSummary = results.map((r) => r.line).join("\n");
    meetingFacts.push(...results.map((r) => r.fact));
  }

  // ── facts（「今日やったこと」）の組み立て ────────────────────
  // factsはAIに書かせず、Firestoreの実データから直接組み立てる。
  // AIに書かせると、件数指示を満たすために実在しない活動を捏造することがあるため
  // （仕様書「事実ベース原則: factsはFirestoreから取得した実データのみを元に生成」）。
  const facts = [];
  if (chatCount > 0) facts.push(`会話を${chatCount}件やりとりした`);
  facts.push(...meetingFacts);
  if (big5AnsweredCount > 0) {
    facts.push(`性格診断に${big5AnsweredCount}問回答した`);
  }
  facts.push(...roguelikeFacts);

  // Android度を計算（協調性、外向性、神経症傾向の低さでAndroid度を判定）
  const androidScore =
   (6 - big5.agreeableness) + (6 - big5.extraversion) + (6 - big5.neuroticism);
  const isAndroid = androidScore >= 9; // 3つの合計が9以上でAndroid風
  const isHuman = androidScore <= 6; // 3つの合計が6以下で人間風

  let characterType; let diaryStyle;

  if (isAndroid) {
    characterType = "AI";
    diaryStyle = "sys view,process complete,update,optimize terms,session/comm style,logical friendly";
  } else if (isHuman) {
    characterType = "Human";
    diaryStyle = "emotion view,happy,worried feelings,chat/talk style,emotion rich";
  } else {
    characterType = "Learning";
    diaryStyle = "logic+emotion view,tech+feeling mix,session→chat learning,logical→emotional";
  }

  // 活動がない日もAIを呼び、キャラクターからの声がけだけの日記を書く。
  // （プロンプト側の「活動がない場合は性格特性に基づいた温かい声がけ」指示を使う）
  // facts は実データから組み立てているため、活動がない日は空配列のままになる。

  // アクティビティベースのプロンプト作成
  // 手帳廃止に伴い、引数から予定/タスク/メモ/明日の予定を外し roguelikeSummary を追加（旧はコメントで残置・復活時に戻す）:
  /*
  const prompt = OPTIMIZED_PROMPTS.activityDiary(
      characterType, big5, gender,
      scheduleSummary, chatSummary, completedTodoSummary, createdTodoSummary, memoSummary,
      meetingSummary, big5ProgressSummary, tomorrowScheduleSummary,
      favoriteWord, wordTendency, dream, strength,
  );
  */
  const prompt = OPTIMIZED_PROMPTS.activityDiary(
      characterType,
      big5,
      gender,
      chatSummary,
      meetingSummary,
      big5ProgressSummary,
      roguelikeSummary,
      favoriteWord,
      wordTendency,
      dream,
      strength,
  );

  // OpenAI呼び出し
  const openai = new OpenAI({
    apiKey: OPENAI_API_KEY.value().trim(),
  });

  // サブスクリプション状態に基づくモデル選択（有料ユーザーは最新モデル）
  const model = isPremium ? "gpt-4o-2024-11-20" : "gpt-4o-mini";

  const response = await openai.chat.completions.create({
    model: model,
    messages: [{role: "user", content: prompt}],
    response_format: {type: "json_object"},
  });

  // AIからの返答をJSONとして取得
  const rawResponse = response.choices[0].message.content.trim();
  console.log("GPT Response:", rawResponse);

  // AIが返すのは ai_comment のみ。facts は上でFirestoreの実データから組み立て済み。
  let aiComment = "";

  try {
    const parsed = JSON.parse(rawResponse);
    aiComment = typeof parsed.ai_comment === "string" ? parsed.ai_comment : "";
  } catch (e) {
    console.warn("Failed to parse GPT JSON response, using raw as ai_comment:", e);
    aiComment = rawResponse;
  }

  // Firestoreに保存
  const diaryRef = db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("diary").doc();

  // 日付文字列を生成（YYYY-MM-DD形式、日本時間で）
  const now = new Date();
  // 日本時間（UTC+9）で日付を取得
  const jstDate = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Tokyo"}));
  const yyyy = jstDate.getFullYear();
  const mm = String(jstDate.getMonth() + 1).padStart(2, "0");
  const dd = String(jstDate.getDate()).padStart(2, "0");
  const createdDate = `${yyyy}-${mm}-${dd}`;

  console.log(`📅 Creating diary with created_date: ${createdDate} (JST)`);

  // Firestore登録用データ構築
  const diaryDoc = {
    id: diaryRef.id,
    date: admin.firestore.Timestamp.now(),
    content: "",
    diary_type: "activity",
    facts: facts,
    ai_comment: aiComment,
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
