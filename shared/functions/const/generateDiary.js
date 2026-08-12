// functions/const/generateDiary.js
const OpenAI = require("openai");
const admin = require("firebase-admin");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");
const {getDream} = require("../src/utils/dreamStore");

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
  const strength = charData.strength || "";
  // 夢は本人限定の dream/current から取得（未移行ユーザーは details.dream にフォールバック）
  const dream = await getDream(userId, characterId, charData);

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

  // 日本時間の日付文字列（YYYY-MM-DD）。
  // dailyMissions のドキュメントIDと、日記の created_date に使う。
  const jstNow = new Date(new Date().toLocaleString("en-US", {timeZone: "Asia/Tokyo"}));
  const createdDate = `${jstNow.getFullYear()}-` +
    `${String(jstNow.getMonth() + 1).padStart(2, "0")}-` +
    `${String(jstNow.getDate()).padStart(2, "0")}`;

  // 「今日」の範囲（**JSTの0時〜24時**）。
  //
  // Cloud Functions の Node は既定でUTC動作するため、`new Date().setHours(0,0,0,0)` は
  // **UTCの0時**になる。以前はそれを使っていたため集計範囲が JST 9:00〜翌9:00 となり、
  // **JST 0:00〜9:00 に行った会話・会議・冒険が日記に反映されなかった**
  // （日記の日付 createdDate はJSTなので、範囲だけが9時間ずれていた）。
  //
  // createdDate と同じJSTの日付から範囲を作り、全ての集計で共有する。
  const JST_OFFSET_MS = 9 * 60 * 60 * 1000;
  const today = new Date(
      Date.UTC(jstNow.getFullYear(), jstNow.getMonth(), jstNow.getDate()) - JST_OFFSET_MS,
  );
  const tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000);
  console.log(
      `📆 集計範囲(JST基準): ${today.toISOString()} 〜 ${tomorrow.toISOString()}`,
  );

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

  // 今日のデイリーミッション達成状況
  //
  // 保存済みの allCompleted は判定条件が変わる前の値が残っていることがあるため、
  // クライアント（daily_mission_model.dart）と同じ式で組み立て直す。
  // 手帳廃止で「スケジュール確認(diaryViewed)」は条件から外れている。
  let dailyMissionSummary = "";
  let dailyMissionCleared = false;
  try {
    const missionSnap = await db.collection("users").doc(userId)
        .collection("dailyMissions").doc(createdDate).get();
    if (missionSnap.exists) {
      const m = missionSnap.data() || {};
      dailyMissionCleared =
        m.loginDone === true && (m.chatCount || 0) >= 6 && m.diaryRead === true;
      if (dailyMissionCleared) {
        dailyMissionSummary = "・今日のミッションを全て達成";
      }
    }
  } catch (e) {
    // dailyMissions が存在しない場合はスキップ
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

      // 会議が結論テキストを返しても、ユーザーの中で答えが出たとは限らないため
      // facts では「相談した」という事実だけを書く
      const fact = concern ?
        `「${concern}」について相談した` :
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
  // デイリーミッションの達成が一番の成果なので、他に何件あっても先頭に置く
  if (dailyMissionCleared) facts.push("デイリーミッションをクリアした");
  if (chatCount > 0) facts.push(`会話を${chatCount}件やりとりした`);
  facts.push(...meetingFacts);
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
      dailyMissionSummary,
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

  // AIが返すのは ai_comment のみ。facts は上でFirestoreの実データから組み立て済み。
  //
  // **壊れた出力を絶対にユーザーへ出さない。**
  // 以前は JSON.parse に失敗すると生の応答をそのまま ai_comment にしていたため、
  // モデルが暴走したときの多言語トークンの羅列が日記に保存されていた。
  // 1度だけ再試行し、それでも駄目なら安全な定型文にする。
  const aiComment = await requestAiComment(openai, model, prompt);

  // Firestoreに保存
  const diaryRef = db.collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("diary").doc();

  // createdDate（JSTの YYYY-MM-DD）は関数冒頭で算出済み
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
/**
 * ai_comment が実用に耐える文章かを判定する。
 *
 * モデルが暴走すると多言語のトークンが延々と並ぶ（例: 「محتوى json 480 512 0 0 َ ...」）。
 * 日本語の日記として明らかに壊れているものを弾くための最低限のチェック。
 *
 * @param {string} text 判定対象
 * @return {boolean} 日記として出せるなら true
 */
function isUsableComment(text) {
  if (typeof text !== "string") return false;
  const t = text.trim();
  // 短すぎる／長すぎる（プロンプトは250〜350文字を指示している）
  if (t.length < 40 || t.length > 800) return false;
  // 日本語（ひらがな・カタカナ・漢字）が半分未満なら壊れているとみなす
  const jp = (t.match(/[ぁ-んァ-ヶ一-龠]/g) || []).length;
  if (jp / t.length < 0.5) return false;
  // JSONの破片が混ざっている
  if (/["{}]\s*$|^\s*[[{]/.test(t)) return false;
  return true;
}

/**
 * ai_comment をAIに生成させる。壊れていたら1度だけ再試行し、
 * それでも駄目なら安全な定型文を返す（生の応答は絶対に返さない）。
 *
 * @param {object} openai OpenAIクライアント
 * @param {string} model モデル名
 * @param {string} prompt プロンプト
 * @return {Promise<string>} 日記に載せるコメント
 */
async function requestAiComment(openai, model, prompt) {
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const response = await openai.chat.completions.create({
        model: model,
        messages: [{role: "user", content: prompt}],
        response_format: {type: "json_object"},
        // 上限を切らないと暴走時に延々と生成し続ける。
        // ai_comment は250〜350文字（日本語 ~1.5chars/token）なので 600 で十分。
        max_tokens: 600,
        // 既定の 1.0 は出力が不安定になりやすい。日記は堅実さを優先する。
        temperature: 0.8,
      });

      const raw = (response.choices[0].message.content || "").trim();
      let comment = "";
      try {
        const parsed = JSON.parse(raw);
        comment = typeof parsed.ai_comment === "string" ? parsed.ai_comment : "";
      } catch (e) {
        console.warn(`日記コメントのJSON解析に失敗 (${attempt}回目):`, e.message);
      }

      if (isUsableComment(comment)) return comment.trim();
      console.warn(`日記コメントが不正 (${attempt}回目). 長さ=${comment.length}`);
    } catch (e) {
      console.warn(`日記コメントの生成に失敗 (${attempt}回目):`, e.message);
    }
  }

  // 2回とも駄目だった。**生の応答は使わない。**
  // 日記が空になるより、当たり障りのない一文が入っているほうが体験として良い。
  console.error("日記コメントの生成に2回とも失敗したため定型文を使用");
  return "今日もおつかれさま。うまく言葉にできない日もあるけれど、" +
    "こうして一日を振り返れたこと自体が積み重ねになるよ。また明日、話そう。";
}

exports.generateDiary = generateDiary;
