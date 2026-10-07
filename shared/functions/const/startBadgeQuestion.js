// functions/const/startBadgeQuestion.js
// バッジ診断の質問を出す（最初の話題・バッジ画面から）
// 設計: shared/docs/functions/バッジ診断_設計書.md「体験の流れ」

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {startQuestion} = require("../src/personality/badgeStore");
const {BADGES} = require("../src/personality/badgeQuestions");

exports.startBadgeQuestion = onCall(
    {
      region: "asia-northeast1",
      memory: "256MiB",
      timeoutSeconds: 30,
      minInstances: 0,
      enforceAppCheck: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "認証が必要です");
      }
      const {source, badgeKey} = request.data || {};
      if (source !== "opener" && source !== "badge") {
        throw new HttpsError("invalid-argument", "source が不正です");
      }
      if (source === "badge" && !BADGES[badgeKey]) {
        throw new HttpsError("invalid-argument", "badgeKey が不正です");
      }
      try {
        const question = await startQuestion(request.auth.uid, {source, badgeKey});
        console.log(`🏅 バッジ質問 user=${request.auth.uid} source=${source} q=${question?.questionId ?? "なし"}`);
        return {question};
      } catch (e) {
        console.error("🔥 startBadgeQuestion error:", e);
        throw new HttpsError("internal", "質問を用意できませんでした");
      }
    },
);
