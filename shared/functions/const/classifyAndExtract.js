// functions/const/classifyAndExtract.js
// AIによるメッセージ分類（app_qa/chat）
// 性格診断はバッジ質問の回答で行うため、ここではタグを抽出しない

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

exports.classifyAndExtract = onCall(
    {
      region: "asia-northeast1",
      memory: "256MiB",
      timeoutSeconds: 60,
      minInstances: 0,
      enforceAppCheck: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "認証が必要です");
      }
      const {data} = request;
      try {
        const {userMessage: rawMessage} = data;
        if (!rawMessage) {
          return {error: "Missing userMessage"};
        }
        const userMessage = rawMessage.substring(0, 100);

        // 現在の日付情報を取得（日本時間）
        const now = new Date();
        const currentDate = now.toLocaleDateString('ja-JP', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          weekday: 'long',
          timeZone: 'Asia/Tokyo',
        });
        const currentTime = now.toLocaleTimeString('ja-JP', {
          hour: '2-digit',
          minute: '2-digit',
          timeZone: 'Asia/Tokyo',
        });

        console.log("🕐 classifyAndExtract - date/time (JST):", currentDate, currentTime);
        console.log("📝 User message:", userMessage);

        const prompt = OPTIMIZED_PROMPTS.classifyAndExtract(currentDate, currentTime, userMessage);
        const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [{role: "user", content: prompt}],
            },
        );

        const resultText = completion.choices[0].message.content.trim();
        console.log("GPT Response:", resultText);

        // Markdownのコードブロックタグを除去してJSONパース
        let parsed;
        try {
          const cleaned = resultText.replace(/```json\s*/g, '').replace(/```\s*$/g, '').trim();
          parsed = JSON.parse(cleaned);
        } catch (e) {
          console.error("JSON parse error:", e, "Raw:", resultText);
          return {type: "chat"};
        }

        const type = parsed.type;
        console.log("✅ Classified as:", type);

        if (type === "app_qa") {
          return {type: "app_qa"};
        }

        // デフォルト: chat
        return {type: "chat"};
      } catch (e) {
        console.error("🔥 Error in classifyAndExtract:", e);
        return {type: "chat"};
      }
    },
);
