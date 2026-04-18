// const/extractFromImage.js
// 画像からスケジュール・メモ・タスクを抽出するCloud Function

const {onCall} = require("firebase-functions/v2/https");
const {admin} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const PROMPTS = {
  schedule: (currentDate) => `
現在日時: ${currentDate}
この画像からスケジュール・予定に関する情報を抽出してください。
チラシ、カレンダー、ホワイトボード、スクリーンショットなど様々な画像に対応してください。

以下のJSON形式のみで返してください（他のテキスト不要）:
{
  "title": "予定のタイトル",
  "isAllDay": false,
  "startDate": "YYYY-MM-DDTHH:mm:ss",
  "endDate": "YYYY-MM-DDTHH:mm:ss",
  "location": "場所（不明な場合は空文字）",
  "memo": "備考・説明（不明な場合は空文字）"
}

- 日時が読み取れない場合は今日の日付・現在時刻を使用
- 終了日時が不明な場合は開始から1時間後
- 終日イベントの場合はisAllDay: true
`.trim(),

  memo: () => `
この画像からテキスト・メモ・ノートの内容を抽出してください。

以下のJSON形式のみで返してください（他のテキスト不要）:
{
  "title": "タイトル（1行目または内容を要約した短いフレーズ）",
  "content": "本文の内容（改行はそのまま保持）"
}
`.trim(),

  schedules: (currentDate) => `
現在日時: ${currentDate}
この画像からすべての予定・イベント情報を抽出してください。
カレンダー、チラシ、スケジュール表など複数の予定が含まれる場合はすべて抽出してください。

以下のJSON形式のみで返してください（他のテキスト不要）:
{
  "schedules": [
    {
      "title": "予定のタイトル",
      "isAllDay": false,
      "startDate": "YYYY-MM-DDTHH:mm:ss",
      "endDate": "YYYY-MM-DDTHH:mm:ss",
      "location": "場所（不明な場合は空文字）",
      "memo": "備考（不明な場合は空文字）"
    }
  ]
}

- 予定が1件も見つからない場合は schedules を空配列で返す
- 日時が不明な場合は今日の日付・現在時刻を使用
- 終了日時が不明な場合は開始から1時間後
- 終日イベントの場合はisAllDay: true
`.trim(),

  todo: (currentDate) => `
現在日時: ${currentDate}
この画像からタスク・TODOの情報を抽出してください。
付箋、手書きメモ、タスクリストなど様々な画像に対応してください。

以下のJSON形式のみで返してください（他のテキスト不要）:
{
  "title": "タスクのタイトル",
  "description": "詳細・説明（不明な場合は空文字）",
  "dueDate": "YYYY-MM-DDTHH:mm:ss または null",
  "priority": "low または medium または high"
}

- 優先度が不明な場合は medium
- 期限が読み取れない場合は null
`.trim(),
};

exports.extractFromImage = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 60,
      minInstances: 0,
      enforceAppCheck: false,
    },
    async (request) => {
      const {imageBase64, targetType} = request.data;

      if (!imageBase64 || !targetType) {
        return {error: "Missing required fields"};
      }

      if (!["schedule", "memo", "todo", "schedules"].includes(targetType)) {
        return {error: "Invalid targetType"};
      }

      const now = new Date();
      const currentDate = now.toLocaleDateString("ja-JP", {
        year: "numeric",
        month: "long",
        day: "numeric",
        weekday: "long",
        timeZone: "Asia/Tokyo",
      });

      const prompt = PROMPTS[targetType](currentDate);
      const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

      let resultText;
      try {
        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [
                {
                  role: "user",
                  content: [
                    {
                      type: "image_url",
                      image_url: {
                        url: `data:image/jpeg;base64,${imageBase64}`,
                        detail: "high",
                      },
                    },
                    {type: "text", text: prompt},
                  ],
                },
              ],
              temperature: 0,
              response_format: {type: "json_object"},
            },
        );
        resultText = completion.choices[0].message.content.trim();
      } catch (e) {
        console.error("OpenAI vision error:", e);
        return {error: "AI processing failed"};
      }

      let data;
      try {
        data = JSON.parse(resultText);
      } catch (e) {
        console.error("JSON parse error:", resultText);
        return {error: "Failed to parse AI response"};
      }

      // Firestoreタイムスタンプに変換
      if (targetType === "schedule") {
        try {
          if (data.startDate) {
            data.startDate = admin.firestore.Timestamp.fromDate(new Date(data.startDate));
          }
          if (data.endDate) {
            data.endDate = admin.firestore.Timestamp.fromDate(new Date(data.endDate));
          }
        } catch (_) {}
      }

      if (targetType === "schedules" && Array.isArray(data.schedules)) {
        data.schedules = data.schedules.map((s) => {
          try {
            if (s.startDate) s.startDate = admin.firestore.Timestamp.fromDate(new Date(s.startDate));
            if (s.endDate) s.endDate = admin.firestore.Timestamp.fromDate(new Date(s.endDate));
          } catch (_) {}
          return s;
        });
      }

      if (targetType === "todo" && data.dueDate) {
        try {
          data.dueDate = admin.firestore.Timestamp.fromDate(new Date(data.dueDate));
        } catch (_) {
          data.dueDate = null;
        }
      }

      console.log(`extractFromImage [${targetType}] success`);
      return {result: data};
    },
);
