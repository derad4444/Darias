// functions/const/answerAppQuestion.js
// アプリに関する質問 & ユーザーデータ参照に答えるCloud Function

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const db = getFirestore();

// ============================================================
// アプリガイド（システムプロンプトに埋め込む）
// ============================================================
const APP_GUIDE = `
# DARIASアプリ 機能ガイド

## 基本機能一覧
- **チャット**: キャラクターと会話できる。メモ・タスク・予定の追加もチャットから可能。
- **メモ**: テキストメモを保存・管理できる。
- **タスク（TODO）**: やることリストを管理できる。優先度・期日・タグ設定可能。
- **予定（カレンダー）**: 日程を管理できる。月間カレンダーで確認可能。
- **日記**: アクティビティ型日記が定期的に自動生成される。

## チャットでできること
| 操作 | 入力例 |
|------|--------|
| メモを追加 | 「〇〇をメモして」「メモしといて：〇〇」|
| タスクを追加 | 「〇〇をタスクに追加」「TODO：〇〇」|
| 予定を追加 | 「明日14時に会議」「来週月曜に歯医者の予定」|
| キャラクターと会話 | 自由にメッセージを送る |
| アプリの使い方を質問 | 「〇〇はどうやるの？」|

## メモの使い方
- **チャットから追加**: 「〇〇をメモして」と入力 → 確認ダイアログ → 追加/編集/キャンセル
- **メモ画面から追加**: 右下の＋ボタン → 新規メモ作成
- **編集**: メモ一覧からタップして編集（自動保存）
- **タグ・ピン留め**: メモ詳細画面で設定可能

## タスクの使い方
- **チャットから追加**: 「〇〇をタスクに追加」「TODO：〇〇」と入力
- **タスク画面から追加**: 右下の＋ボタン
- **完了にする**: タスク一覧でチェックボックスをタップ
- **優先度**: 高・中・低 の3段階

## 予定の使い方
- **チャットから追加**: 日時を含む文章を送ると自動検出 → 確認ダイアログ
- **カレンダーから追加**: 右下の＋ボタン
- **確認**: カレンダー画面（月間表示）

## キャラクターについて
- BIG5性格診断をもとにキャラクターの性格が変化する
- 診断はチャットの会話を通じて自動的に進む
`;

// ============================================================
// ユーザーデータをFirestoreから取得
// ============================================================
async function fetchUserData(userId, dataTypes) {
  const results = {};
  const now = new Date();

  if (dataTypes.includes("schedules")) {
    try {
      // 前後30日の予定を取得
      const from = new Date(now);
      from.setDate(from.getDate() - 1);
      const to = new Date(now);
      to.setDate(to.getDate() + 30);

      const snap = await db
          .collection("users").doc(userId)
          .collection("schedules")
          .where("startDate", ">=", from)
          .where("startDate", "<=", to)
          .orderBy("startDate")
          .limit(20)
          .get();

      results.schedules = snap.docs.map((doc) => {
        const d = doc.data();
        return {
          title: d.title,
          startDate: d.startDate?.toDate()?.toLocaleDateString("ja-JP", {timeZone: "Asia/Tokyo"}),
          endDate: d.endDate?.toDate()?.toLocaleDateString("ja-JP", {timeZone: "Asia/Tokyo"}),
          isAllDay: d.isAllDay,
          location: d.location || "",
        };
      });
    } catch (e) {
      console.warn("schedules fetch error:", e.message);
    }
  }

  if (dataTypes.includes("todos")) {
    try {
      const snap = await db
          .collection("users").doc(userId)
          .collection("todos")
          .where("isCompleted", "==", false)
          .orderBy("createdAt", "descending")
          .limit(20)
          .get();

      results.todos = snap.docs.map((doc) => {
        const d = doc.data();
        return {
          title: d.title,
          priority: d.priority || "中",
          dueDate: d.dueDate?.toDate()?.toLocaleDateString("ja-JP", {timeZone: "Asia/Tokyo"}) || null,
        };
      });
    } catch (e) {
      console.warn("todos fetch error:", e.message);
    }
  }

  if (dataTypes.includes("memos")) {
    try {
      const snap = await db
          .collection("users").doc(userId)
          .collection("memos")
          .orderBy("updatedAt", "descending")
          .limit(10)
          .get();

      results.memos = snap.docs.map((doc) => {
        const d = doc.data();
        return {title: d.title, tag: d.tag || ""};
      });
    } catch (e) {
      console.warn("memos fetch error:", e.message);
    }
  }

  return results;
}

// ============================================================
// Cloud Function本体
// ============================================================
exports.answerAppQuestion = onCall(
    {
      region: "asia-northeast1",
      memory: "256MiB",
      timeoutSeconds: 60,
      minInstances: 0,
      enforceAppCheck: false,
    },
    async (request) => {
      const {data} = request;
      const {userId, userMessage, dataTypes = []} = data;

      if (!userId || !userMessage) {
        return {error: "Missing userId or userMessage"};
      }

      try {
        // 必要に応じてユーザーデータを取得
        let userDataSection = "";
        if (dataTypes.length > 0) {
          const userData = await fetchUserData(userId, dataTypes);
          if (Object.keys(userData).length > 0) {
            userDataSection = "\n\n## あなたのデータ（参考情報）\n" +
              JSON.stringify(userData, null, 2);
          }
        }

        // 日本時間の現在日時
        const nowStr = new Date().toLocaleDateString("ja-JP", {
          year: "numeric", month: "long", day: "numeric",
          weekday: "long", timeZone: "Asia/Tokyo",
        });

        const systemPrompt =
          `あなたはDARIASというアプリのキャラクターです。` +
          `ユーザーのアプリに関する質問や、データについての質問に答えてください。` +
          `回答は100文字以内で、フレンドリーに答えてください。` +
          `現在日時：${nowStr}` +
          APP_GUIDE +
          userDataSection;

        const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [
                {role: "system", content: systemPrompt},
                {role: "user", content: userMessage},
              ],
              temperature: 0.7,
              max_tokens: 200,
            },
        );

        const reply = completion?.choices?.[0]?.message?.content?.trim() ?? "うまく答えられなかったよ、ごめんね。";
        console.log(`✅ answerAppQuestion: "${userMessage}" → "${reply}"`);

        return {reply};
      } catch (e) {
        console.error("answerAppQuestion error:", e);
        return {reply: "うまく答えられなかったよ、ごめんね。"};
      }
    },
);
