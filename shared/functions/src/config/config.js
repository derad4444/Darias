// src/config/index.js

const functions = require("firebase-functions");

// .env 環境変数の .value() 互換ラッパー
function createEnvSecret(name) {
  return {
    value: () => process.env[name] || "",
  };
}
const OPENAI_API_KEY = createEnvSecret("OPENAI_API_KEY");
const GMAIL_USER = createEnvSecret("GMAIL_USER");
const GMAIL_APP_PASSWORD = createEnvSecret("GMAIL_APP_PASSWORD");

// アプリケーション設定
const CONFIG = {
  // Firebase設定
  firebase: {
    region: "asia-northeast1",
    timeZone: "Asia/Tokyo",
  },

  // Cloud Tasks設定
  cloudTasks: {
    project: process.env.GCLOUD_PROJECT ??
      process.env.GCP_PROJECT ?? "my-character-app",
    queue: "generate-character-queue",
    location: "asia-northeast1",
  },

  // スケジュール設定
  schedules: {
    diaryGeneration: "every day 23:50", // 日記生成
    characterDetails: "every day 00:00", // キャラクター詳細生成
    holidayGeneration: "0 1 1 1 *", // 祝日登録（毎年1月1日）
  },

  // タイムアウト設定（秒）
  timeouts: {
    default: 120,
    characterDetails: 600,
  },

  // 制限値
  limits: {
    characterDetailsDelayDays: 14, // キャラクター詳細生成の遅延日数
  },
};

module.exports = {
  CONFIG,
  OPENAI_API_KEY,
  GMAIL_USER,
  GMAIL_APP_PASSWORD,
};
