// functions/index.js - 遅延ロード版

console.log("Cloud Functions v2 initialized with lazy loading");

// 遅延ロードで依存関係を分離
Object.defineProperty(exports, "generateCharacterReply", {
  get: () => require("./const/generateCharacterReply").generateCharacterReply,
  enumerable: true,
});

Object.defineProperty(exports, "extractSchedule", {
  get: () => require("./const/extractSchedule").extractSchedule,
  enumerable: true,
});

Object.defineProperty(exports, "generateVoice", {
  get: () => require("./const/generateVoice").generateVoice,
  enumerable: true,
});

Object.defineProperty(exports, "scheduledHolidays", {
  get: () => require("./src/functions/scheduledTasks").scheduledHolidays,
  enumerable: true,
});

Object.defineProperty(exports, "generateMonthlyReview", {
  get: () =>
    require("./src/functions/generateMonthlyReview").generateMonthlyReview,
  enumerable: true,
});

Object.defineProperty(exports, "generateMonthlyReviewHttp", {
  get: () =>
    require("./src/functions/generateMonthlyReview").generateMonthlyReviewHttp,
  enumerable: true,
});

Object.defineProperty(exports, "sendRegistrationEmail", {
  get: () => require("./src/functions/sendRegistrationEmail").sendRegistrationEmail,
  enumerable: true,
});

// ヘルスチェック関数は直接エクスポート（軽量）
const {health} = require("./health");
exports.health = health;

console.log("All Cloud Functions exported with lazy loading");
