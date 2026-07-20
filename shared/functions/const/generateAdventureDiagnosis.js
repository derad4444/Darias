// functions/const/generateAdventureDiagnosis.js
//
// ローグライク「心の迷宮」全踏破時の総合診断テキストを生成する callable 関数。
// クライアントが全ラン横断で集計した「上位の行動傾向」と推定元素を渡し、
// 「あなたはこういう選択を多く取る（summary）」と「その活かし方（advice）」を生成する。
// 生成結果の保存（roguelike_meta/diagnosis）はクライアント側で行う。

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

exports.generateAdventureDiagnosis = onCall(
    {
      region: "asia-northeast1",
      memory: "512MiB",
      timeoutSeconds: 120,
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
        const {userId, characterName, topTraits, inferredElement, homeElement} = data;
        if (!userId || !topTraits) {
          return {summary: "", advice: "", error: true};
        }

        const apiKey = OPENAI_API_KEY.value().trim();
        if (!apiKey) {
          throw new HttpsError("internal", "OpenAI API key not configured");
        }
        const openai = getOpenAIClient(apiKey);

        const prompt = OPTIMIZED_PROMPTS.adventureDiagnosis({
          characterName: characterName || "あなた",
          topTraits: topTraits,
          inferredElement: inferredElement || "無",
          homeElement: homeElement || "無",
        });

        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: "gpt-4o-mini",
              messages: [{role: "user", content: prompt}],
              max_completion_tokens: 600,
              response_format: {type: "json_object"},
            },
        );

        let content = completion.choices[0].message.content?.trim() || "{}";
        if (content.startsWith("```")) {
          content = content
              .replace(/^```json\s*/, "")
              .replace(/^```\s*/, "")
              .replace(/```$/, "")
              .trim();
        }
        let parsed;
        try {
          parsed = JSON.parse(content);
        } catch (e) {
          parsed = {};
        }

        const usage = completion.usage || {};
        console.log(`📊 adventureDiagnosis tokens: input=${usage.prompt_tokens} output=${usage.completion_tokens} total=${usage.total_tokens}`);

        return {
          summary: (parsed.summary || "").toString(),
          advice: (parsed.advice || "").toString(),
        };
      } catch (error) {
        console.error("❌ generateAdventureDiagnosis error:", error);
        throw new HttpsError("internal", `診断生成に失敗しました: ${error.message}`);
      }
    },
);
