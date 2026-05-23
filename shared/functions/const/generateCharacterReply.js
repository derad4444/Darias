// functions/const/generateCharacterReply.js
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS, buildPersonalityTraitsFromAxes} = require("../src/prompts/templates");
const firestoreCache = require("../src/utils/firestoreCache");

// 感情判定関数
async function detectEmotion(openai, messageText) {
  try {
    // メッセージが空や短すぎる場合はnormalを返す
    if (!messageText || messageText.trim().length < 3) {
      return "";
    }

    const emotionPrompt = OPTIMIZED_PROMPTS.emotionDetect(messageText);

    const completion = await safeOpenAICall(
        openai.chat.completions.create.bind(openai.chat.completions),
        {
          model: "gpt-4o-mini",
          messages: [{role: "user", content: emotionPrompt}],
        },
    );

    if (!completion || !completion.choices || !completion.choices[0]) {
      console.warn("Invalid emotion detection response");
      return "";
    }

    const emotion = completion.choices[0].message.content.trim().toLowerCase();

    // 有効な感情のみを返す
    const validEmotions = ["normal", "smile", "angry", "cry", "sleep"];
    if (validEmotions.includes(emotion)) {
      return emotion === "normal" ? "" : `_${emotion}`;
    }

    console.warn(`Invalid emotion detected: ${emotion}, using normal`);
    return ""; // normalの場合は空文字
  } catch (error) {
    console.error("Emotion detection error:", error);
    console.error("Error details:", {
      message: error.message,
      code: error.code,
      status: error.status,
    });
    return ""; // エラー時はnormal（空文字）
  }
}

// 統一初期化を使用
const {getFirestore, admin} = require("../src/utils/firebaseInit");

const db = getFirestore();

// フェーズ別 max_completion_tokens（日本語 ~1.5chars/token + バッファ）
function getMaxTokensForPhase(phase) {
  if (phase === 2) return 250; // ~150文字
  if (phase === 3) return 350; // ~220文字
  return 200;                  // ~120文字 (phase 1)
}

// 最適化されたプロンプト生成関数（BIG5詳細形式を使用）
function buildCharacterPrompt(big5, gender, dreamText, userMessage, meetingContext, traitsOverride = null, phase = 1) {
  // Android度計算（将来的な利用のため残す）
  const androidScore = (6 - big5.agreeableness) + (6 - big5.extraversion) +
      (6 - big5.neuroticism);

  // タイプ判定（将来的な利用のため残す）
  let type; let style; let question;

  if (androidScore >= 9) {
    type = "AI";
    style = gender === "female" ?
        "logical,friendly,sys terms" : "logical,systematic,clear steps";
    question = gender === "female" ? "info gather Q+" : "param check Q+";
  } else if (androidScore <= 6) {
    type = "Human";
    style = gender === "female" ?
        "empathy,support,feelings" : "solve,advise,encourage";
    question = "feelings Q+";
  } else {
    type = "Learning";
    style = gender === "female" ?
        "logic+emotion,sys+feel mix" : "efficient+warm,logic+care";
    question = "info+emotion Q+";
  }

  // BIG5詳細形式を使用した新しいプロンプト（5軸スコアがある場合はtraitsOverrideを優先）
  return OPTIMIZED_PROMPTS.characterReply(type, gender, big5, dreamText, userMessage, style, question, meetingContext, traitsOverride, phase);
}

// 無意味な入力を検出する関数
function isMeaninglessInput(message) {
  const text = message.trim();

  // 3文字未満
  if (text.length < 3) return true;

  // 同じ文字の繰り返し (あああ、うう、www等)
  if (/^(.)\1+$/.test(text)) return true;

  // 記号のみ
  if (/^[!?！？。、\s]+$/.test(text)) return true;

  // 母音のみの繰り返し (あいうえお等)
  if (/^[あいうえおアイウエオ]+$/.test(text) && text.length <= 5) return true;

  return false;
}

// フォールバック返答をランダムに取得
function getRandomFallbackReply(gender) {
  const fallbackReplies = gender === "female" ? [
    "ん？どうしたの？",
    "何か言いたいことある？",
    "うーん、よく聞こえなかったかも",
    "もう少し詳しく教えて？",
    "どうしたの？何かあった？",
    "え、なになに？",
  ] : [
    "ん？どうした？",
    "何か言いたいことある？",
    "うーん、よく聞こえなかったかも",
    "もう少し詳しく教えて？",
    "どうした？何かあった？",
    "え、なになに？",
  ];

  const randomIndex = Math.floor(Math.random() * fallbackReplies.length);
  return fallbackReplies[randomIndex];
}

exports.generateCharacterReply = onCall(
    {
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 300,
      minInstances: 0,
      enforceAppCheck: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "認証が必要です");
      }
      const {data} = request;
      if (data.userId && request.auth.uid !== data.userId) {
        throw new HttpsError("permission-denied", "ユーザーIDが一致しません");
      }
      try {
        const {characterId, userMessage, userId, isPremium, chatHistory, meetingContext, phase = 1} = data;
        console.log(`🔍 generateCharacterReply called: userId=${userId} characterId=${characterId} phase=${phase} msg="${userMessage?.substring(0,30)}"`);
        if (!characterId || !userMessage || !userId) {
          console.error(`❌ Missing params: characterId=${characterId} userId=${userId} userMessage=${userMessage}`);
          return {reply: "一時的なエラーが発生しました。再起動してみてください。", voiceUrl: "", error: true};
        }

        // 無意味な入力を検出してフォールバック返答を返す
        if (isMeaninglessInput(userMessage)) {
          console.log(`🚫 Meaningless input detected: "${userMessage}"`);

          // キャラクター情報を取得（genderのみ必要・キャッシュ利用）
          const _charDetailKey = `charDetail_${userId}_${characterId}`;
          let _charDetailData = firestoreCache.get(_charDetailKey);
          if (_charDetailData === undefined) {
            const snap = await db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("details").doc("current").get();
            _charDetailData = snap.exists ? snap.data() : null;
            firestoreCache.set(_charDetailKey, _charDetailData);
          }

          const gender = _charDetailData ? _charDetailData.gender || "neutral" : "neutral";

          const fallbackReply = getRandomFallbackReply(gender);

          return {
            reply: fallbackReply,
            isBig5Question: false,
            emotion: "", // 通常表情
          };
        }

        // 予定問い合わせパターンの検出
        const scheduleQueryPatterns = [
          /今日.*予定/,
          /今日.*何.*ある[？?]/,
          /明日.*予定/,
          /明日.*何.*ある[？?]/,
          /予定.*教えて/,
          /予定.*ある[？?]/,
        ];

        const isScheduleQuery = scheduleQueryPatterns.some((pattern) =>
          pattern.test(userMessage.replace(/\s/g, "")),
        );

        // キャラクター詳細はキャッシュ利用（5分TTL）
        const charDetailKey = `charDetail_${userId}_${characterId}`;
        let charData = firestoreCache.get(charDetailKey);
        if (charData === undefined) {
          const snap = await db.collection("users").doc(userId)
              .collection("characters").doc(characterId)
              .collection("details").doc("current").get();
          if (!snap.exists) {
            console.error(`❌ Character details not found: userId=${userId} characterId=${characterId}`);
            return {reply: "キャラクター情報が見つかりません。再起動してください。", voiceUrl: "", error: true};
          }
          charData = snap.data();
          firestoreCache.set(charDetailKey, charData);
        } else if (charData === null) {
          console.error(`❌ Character details cache null: userId=${userId} characterId=${characterId}`);
          return {reply: "キャラクター情報が見つかりません。再起動してください。", voiceUrl: "", error: true};
        }

        // 予定問い合わせの処理
        if (isScheduleQuery) {
          console.log("📅 Schedule query detected");

          // 今日・明日を判定
          const isToday = /今日/.test(userMessage);
          const isTomorrow = /明日/.test(userMessage);

          const now = new Date();
          let targetDate = now;

          if (isTomorrow) {
            targetDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
          }

          // 対象日の開始と終了（00:00-23:59）
          const startOfDay = new Date(targetDate);
          startOfDay.setHours(0, 0, 0, 0);

          const endOfDay = new Date(targetDate);
          endOfDay.setHours(23, 59, 59, 999);

          // Firestoreから予定を取得
          const schedulesSnapshot = await db.collection("users").doc(userId)
              .collection("schedules")
              .where("startDate", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
              .where("startDate", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
              .orderBy("startDate", "asc")
              .get();

          const gender = charData.gender || "neutral";
          const dateLabel = isToday ? "今日" : isTomorrow ? "明日" : "その日";

          if (schedulesSnapshot.empty) {
            const noScheduleReply = gender === "female" ?
              `${dateLabel}は予定が入ってないみたい！何か予定を立てる？` :
              `${dateLabel}は予定が入ってないみたいだね！何か予定を立てる？`;

            return {
              reply: noScheduleReply,
              isBig5Question: false,
              emotion: "",
            };
          }

          // 予定をフォーマット
          const schedules = schedulesSnapshot.docs.map((doc) => {
            const data = doc.data();
            const startDate = data.startDate.toDate();

            // 日本時間（JST）で表示するため、toLocaleStringを使用
            const timeStr = data.isAllDay ? "終日" :
              startDate.toLocaleTimeString("ja-JP", {
                timeZone: "Asia/Tokyo",
                hour: "2-digit",
                minute: "2-digit",
                hour12: false,
              });
            return `${timeStr} ${data.title}`;
          });

          const scheduleList = schedules.join("、");
          const scheduleReply = gender === "female" ?
            `${dateLabel}の予定は${schedules.length}件あるよ！\n${scheduleList}` :
            `${dateLabel}の予定は${schedules.length}件あるね！\n${scheduleList}`;

          return {
            reply: scheduleReply,
            isBig5Question: false,
            emotion: "",
          };
        }

        const big5 = charData.confirmedBig5Scores || {
          openness: 3,
          conscientiousness: 3,
          extraversion: 3,
          agreeableness: 3,
          neuroticism: 3
        };
        const gender = charData.gender || "neutral";

        // 5軸スコアがある場合は5軸ベースの性格特性を優先使用
        const axisScores = charData.axisScores || null;
        const axisTraitsOverride = axisScores
          ? buildPersonalityTraitsFromAxes(axisScores, charData.element || null, charData.typeName || null)
          : null;

        const dreamText = charData.dream ?
        `なお、このキャラクターの夢は「${charData.dream}」です。` :
        "なお、このキャラクターの夢はまだ決まっていません。";

        // Android度を計算し、プロンプトを生成（5軸スコアがある場合は5軸特性を優先）
        const prompt = buildCharacterPrompt(
            big5, gender, dreamText, userMessage, meetingContext, axisTraitsOverride, phase);

        const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

        // サブスクリプション状態に基づくモデル選択（有料ユーザーは最新モデル）
        const model = isPremium ? "gpt-4o-2024-11-20" : "gpt-4o-mini";

        // 会話履歴を含むメッセージ配列を構築
        const messages = [
          {role: "system", content: prompt},
        ];

        // 会話履歴を追加（最大2件）
        if (chatHistory && Array.isArray(chatHistory)) {
          chatHistory.forEach((history) => {
            if (history.userMessage && history.aiResponse) {
              messages.push(
                  {role: "user", content: history.userMessage.substring(0, 100)},
                  {role: "assistant", content: history.aiResponse.substring(0, 100)},
              );
            }
          });
        }

        // 新しいユーザーメッセージを追加（100文字制限）
        messages.push({
          role: "user",
          content: userMessage.substring(0, 100),
        });

        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: model,
              messages: messages,
              max_completion_tokens: getMaxTokensForPhase(phase),
            },
        );

        const content = completion.choices[0].message.content;
        const finishReason = completion.choices[0].finish_reason;
        const refusal = completion.choices[0].message.refusal;
        const usage = completion.usage || {};
        console.log(`📊 Token usage: input=${usage.prompt_tokens} output=${usage.completion_tokens} reasoning=${usage.completion_tokens_details?.reasoning_tokens ?? 0} total=${usage.total_tokens}`);
        const reply = content ? content.trim() : '';
        if (!reply) {
          console.warn(`⚠️ Empty reply from OpenAI: finish_reason=${finishReason} refusal=${refusal} content=${JSON.stringify(content)}`);
          const fallback = charData.gender === "female" ? "ごめん、うまく言葉が出てこなかったみたい。もう一度話しかけてみて？" : "ごめん、うまく言葉が出てこなかった。もう一度話しかけてみて？";
          return {reply: fallback, voiceUrl: ""};
        }
        console.log(`✅ generateCharacterReply success: reply="${reply.substring(0, 50)}" finish=${finishReason}`);

        return {
          reply,
          voiceUrl: "",
        };
      } catch (e) {
        console.error("🔥 Error in generateCharacterReply:", e);
        console.error("🔥 Error stack:", e.stack);
        console.error("🔥 Error message:", e.message);
        console.error("🔥 Request data:", {
          characterId: data.characterId,
          userMessage: data.userMessage,
          userId: data.userId,
        });

        // エラーの種類に応じて適切なメッセージを返す
        // アプリ側の期待形式に合わせてreplyとvoiceUrlを必ず含む
        if (e.message && e.message.includes("OpenAI")) {
          return {
            reply: "AI サービスでエラーが発生しました。しばらくお待ちください。",
            voiceUrl: "",
            error: true,
          };
        } else if (e.message && e.message.includes("Voice")) {
          return {
            reply: "申し訳ございません。音声生成中にエラーが発生しました。",
            voiceUrl: "",
            error: true,
          };
        } else if (e.message && e.message.includes("CharacterDetail")) {
          return {
            reply: "キャラクター情報が見つかりません。再起動してください。",
            voiceUrl: "",
            error: true,
          };
        } else {
          return {
            reply: `一時的なエラーが発生しました。もう一度お試しください。(${e.message})`,
            voiceUrl: "",
            error: true,
          };
        }
      }
    },
);
