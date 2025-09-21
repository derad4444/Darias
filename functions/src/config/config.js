// src/config/index.js

const functions = require("firebase-functions");
const {defineSecret} = require("firebase-functions/params");

// 環境変数とシークレットの定義
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const GMAIL_USER = defineSecret("GMAIL_USER");
const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");

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
