// functions/const/classifyAndExtract.js
// AIによるメッセージ分類＋内容抽出（memo/task/schedule/app_qa/chat）

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {admin} = require("../src/utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");
const {calculateAndSaveAxisScores} = require("../src/personality/axisCalculator");

const VALID_TAGS = new Set([
  'social_reference', 'solo_preference', 'group_activity', 'initiating',
  'quiet_environment', 'planning_language', 'spontaneous_language', 'goal_oriented',
  'emotional_expression', 'logical_reasoning', 'intuitive_decision', 'data_driven',
  'cooperative_language', 'independent_stance', 'self_paced', 'change_seeking', 'worry_anxiety',
]);

// タグ保存 + signalCountインクリメント（トランザクション）→ 新しいカウントを返す
async function savePersonalitySignal(userId, tags, messageType) {
  const db = admin.firestore();
  const metaRef = db.collection('users').doc(userId).collection('personalityMeta').doc('current');
  const signalRef = db.collection('users').doc(userId).collection('personalitySignals').doc();

  let newCount;
  await db.runTransaction(async (t) => {
    const metaDoc = await t.get(metaRef);
    newCount = ((metaDoc.data() || {}).signalCount || 0) + 1;

    t.set(signalRef, {
      tags,
      messageType,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    t.set(metaRef, {
      signalCount: newCount,
      lastSignalAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  console.log(`✅ personalitySignal保存: [${tags.join(', ')}] count=${newCount} user=${userId}`);
  return newCount;
}

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

        // 性格シグナルタグをFirestoreに保存（エラーが出てもメインフローに影響させない）
        const rawTags = Array.isArray(parsed.tags) ? parsed.tags : [];
        const validatedTags = rawTags.filter(t => VALID_TAGS.has(t)).slice(0, 3);
        if (validatedTags.length > 0) {
          try {
            const newCount = await savePersonalitySignal(request.auth.uid, validatedTags, type);
            if (newCount % 10 === 0) {
              console.log(`🔄 軸スコア再計算トリガー: count=${newCount}`);
              await calculateAndSaveAxisScores(request.auth.uid, newCount);
            }
          } catch (e) {
            console.error('⚠️ personalitySignal処理エラー:', e);
          }
        }

        if (type === "schedule") {
          const rawSchedules = parsed.schedules;
          if (!Array.isArray(rawSchedules) || rawSchedules.length === 0) {
            return {type: "chat"};
          }
          const processedSchedules = rawSchedules.map((item) => {
            const startDate = new Date(item.startDate);
            const endDate = new Date(item.endDate);
            return {
              title: item.title || "",
              isAllDay: item.isAllDay || false,
              startDate: admin.firestore.Timestamp.fromDate(startDate),
              endDate: admin.firestore.Timestamp.fromDate(endDate),
              location: item.location || "",
              tag: item.tag || "",
              memo: item.memo || "",
              repeatOption: item.repeatOption || "none",
              remindValue: item.remindValue || 0,
              remindUnit: item.remindUnit || "none",
              created_at: admin.firestore.Timestamp.now(),
            };
          });
          return {type: "schedule", schedules: processedSchedules};
        }

        if (type === "memo") {
          return {type: "memo", items: Array.isArray(parsed.items) ? parsed.items : []};
        }

        if (type === "task") {
          return {type: "task", items: Array.isArray(parsed.items) ? parsed.items : []};
        }

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
