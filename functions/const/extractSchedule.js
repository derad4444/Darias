// functions/const/extractSchedule.js

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore, admin} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");

const db = getFirestore();

exports.extractSchedule = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 120,
      minInstances: 0,
      enforceAppCheck: false, // App Checkを無効化
      secrets: ["OPENAI_API_KEY"],
    },
    async (request) => {
      const {data} = request;
      try {
        const {userId, userMessage} = data;
        if (!userId || !userMessage) {
          return {error: "Missing userId or userMessage"};
        }

        // 現在の日付情報を取得
        const now = new Date();
        const currentDate = now.toLocaleDateString('ja-JP', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          weekday: 'long'
        });
        const currentTime = now.toLocaleTimeString('ja-JP', {
          hour: '2-digit',
          minute: '2-digit'
        });

        // プロンプト作成
        const prompt = `現在の日時: ${currentDate} ${currentTime}

以下のメッセージから予定を抽出してください: "${userMessage}"

予定がない場合: {"hasSchedule":false}
予定がある場合: {"hasSchedule":true,"title":"予定名","isAllDay":false,` +
    `"startDate":"ISO8601形式の開始日時","endDate":"ISO8601形式の終了日時","location":"場所",` +
    `"tag":"","memo":"","repeatOption":"none","remindValue":0,"remindUnit":"none"}

重要な指示:
- 「明日」は${new Date(now.getTime() + 24*60*60*1000).toLocaleDateString('ja-JP')}を指します
- 「今日」は${now.toLocaleDateString('ja-JP')}を指します  
- 「来週」は7日後以降を指します

時間設定の重要なルール（必ず従ってください）:
- 時刻が明確に指定されていない場合は、必ず00:00開始、23:59終了に設定し、isAllDay: trueにしてください
- 例：「明日会議」→ 明日00:00から23:59まで、isAllDay: true
- 例：「今日映画」→ 今日00:00から23:59まで、isAllDay: true
- 開始時刻のみ指定されている場合のみ、終了時刻は開始時刻から1時間後とし、isAllDay: falseにします
- 期間指定（例：「8月20日から23日まで」「月曜から金曜まで」）の場合：
  * 開始日の00:00をstartDateに設定
  * 終了日の23:59をendDateに設定
  * 複数日にわたる場合でも1つの予定として登録
  * 複数日の期間予定でもisAllDay: trueに設定

- ISO8601形式の例: "2025-08-17T00:00:00+09:00", "2025-08-17T23:59:00+09:00"
- 不明なフィールドは""または0を使用してください
- 10:00や11:00のような任意の時刻を勝手に設定しないでください

重要: 回答は純粋なJSON形式のみで、マークダウンのコードブロック記号は使用しないでください。`;

        // OpenAIのAPIクライアントを取得
        const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

        // GPT-4o-miniにプロンプトを送信して予定抽出を実行
        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [{role: "user", content: prompt}],
              temperature: 0,
            },
        );

        // GPTの返答内容（JSON形式の文字列）を取得・整形
        const resultText = completion.choices[0].message.content.trim();
        console.log("GPT Response:", resultText);

        // GPTの出力JSONをパース（Markdownタグを除去してから変換）
        let scheduleData;
        try {
          // Markdownのコードブロックタグを除去
          let cleanedText = resultText.replace(/```json\s*/g, '').replace(/```\s*$/g, '').trim();
          console.log("Cleaned response:", cleanedText);
          
          scheduleData = JSON.parse(cleanedText);
        } catch (e) {
          console.error("JSON parse error:", e);
          console.error("Original text:", resultText);
          return {error: "Failed to parse AI response"};
        }

        // GPTの返答が「予定なし」の場合は、そのまま処理終了
        if (!scheduleData.hasSchedule) {
          return {hasSchedule: false, message: "No schedule found"};
        }

        // 00:00-23:59の場合は自動的にisAllDayをtrueに設定
        const startDate = new Date(scheduleData.startDate);
        const endDate = new Date(scheduleData.endDate);
        const isFullDay = startDate.getHours() === 0 && startDate.getMinutes() === 0 &&
                         endDate.getHours() === 23 && endDate.getMinutes() === 59;
        
        // 予定データを構造化（保存はしない - クライアント側で確認後に保存）
        const scheduleDoc = {
          title: scheduleData.title || "",
          isAllDay: isFullDay || scheduleData.isAllDay || false,
          startDate: admin.firestore.Timestamp.fromDate(startDate),
          endDate: admin.firestore.Timestamp.fromDate(endDate),
          location: scheduleData.location || "",
          tag: scheduleData.tag || "",
          memo: scheduleData.memo || "",
          repeatOption: scheduleData.repeatOption || "none",
          remindValue: scheduleData.remindValue || 0,
          remindUnit: scheduleData.remindUnit || "none",
          created_at: admin.firestore.Timestamp.now(),
        };

        return {
          hasSchedule: true,
          scheduleData: scheduleDoc,
          message: "予定楽しんでね！"
        };
      } catch (e) {
        console.error("🔥 Error in extractSchedule:", e);
        return {error: "Internal server error"};
      }
    },
);
