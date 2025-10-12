// functions/const/extractSchedule.js

const {onCall} = require("firebase-functions/v2/https");
const {getFirestore, admin} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

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

        // 現在の日付情報を取得（日本時間）
        const now = new Date();
        const currentDate = now.toLocaleDateString('ja-JP', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          weekday: 'long',
          timeZone: 'Asia/Tokyo'
        });
        const currentTime = now.toLocaleTimeString('ja-JP', {
          hour: '2-digit',
          minute: '2-digit',
          timeZone: 'Asia/Tokyo'
        });

        console.log("🕐 Current date/time (JST):", currentDate, currentTime);
        console.log("📝 User message:", userMessage);

        // 最適化されたプロンプト作成
        const prompt = OPTIMIZED_PROMPTS.scheduleExtract(currentDate, currentTime, userMessage);

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
