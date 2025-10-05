// src/functions/scheduledTasks.js - 軽量化版

const {onSchedule} = require("firebase-functions/v2/scheduler");

// 遅延インポートで軽量化
let CONFIG; let Logger; let generateHolidays; let generateDiary; let admin; let errorHandler;
let logger;

function initializeDependencies() {
  if (!CONFIG) {
    CONFIG = require("../config/config").CONFIG;
    Logger = require("../utils/logger").Logger;
    generateHolidays = require("../../const/generateHolidays").generateHolidays;
    generateDiary = require("../../const/generateDiary").generateDiary;
    admin = require("firebase-admin");
    errorHandler = require("../utils/errorHandler");

    logger = new Logger("ScheduledTasks");
  }
}

/**
 * 日記自動生成（毎日23:50 JST）
 */
const scheduledDiaryGeneration = onSchedule(
    {
      schedule: "50 23 * * *", // 毎日23:50 JST
      timeZone: "Asia/Tokyo",
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 540,
      secrets: ["OPENAI_API_KEY"],
    },
    async (event) => {
      // 実行時に依存関係を初期化
      initializeDependencies();

      const db = admin.firestore();
      const snapshot = await db.collection("CharacterDetail").get();

      logger.info("Starting daily diary generation", {
        characterCount: snapshot.docs.length,
      });

      let successCount = 0;
      let errorCount = 0;

      // 並行制御: 同時に5件まで処理
      const pLimit = (await import("p-limit")).default;
      const limit = pLimit(5);

      const processCharacter = async (doc) => {
        const characterId = doc.id;
        try {
          await generateDiary(characterId);
          successCount++;
          logger.info("Diary generated successfully", {characterId});
          return {success: true, characterId};
        } catch (error) {
          errorCount++;
          logger.error("Failed to generate diary", error, {characterId});
          return {success: false, characterId, error};
        }
      };

      const promises = snapshot.docs.map((doc) =>
        limit(() => processCharacter(doc)),
      );

      const results = await Promise.allSettled(promises);

      // 失敗した処理を集計
      const failures = results
          .filter((result) => result.status === "rejected" ||
              !result.value?.success)
          .map((result) => result.value || result.reason);

      logger.success("Daily diary generation completed", {
        total: snapshot.docs.length,
        success: successCount,
        errors: errorCount,
        // 最初の5件のみログ
        failures: failures.length > 0 ? failures.slice(0, 5) : undefined,
      });
    },
);


// キャラクター詳細生成は段階的生成に統合されました
// generateCharacterReply.js での BIG5 診断完了時にリアルタイム生成

/**
 * 祝日登録（毎年1月1日1:00 JST）
 */
const scheduledHolidays = onSchedule(
    {
      schedule: "0 1 1 1 *", // 毎年1月1日1:00 JST
      region: "asia-northeast1",
      timeZone: "Asia/Tokyo",
      memory: "512MiB",
      timeoutSeconds: 300,
    },
    async (event) => {
      // 実行時に依存関係を初期化
      initializeDependencies();

      const now = new Date();
      const year = now.getFullYear();

      logger.info("Starting holiday generation", {year});

      try {
        await generateHolidays(year);
        logger.success("Holiday generation completed", {year});
      } catch (error) {
        logger.error("Holiday generation failed", error, {year});
        throw error;
      }
    },
);

module.exports = {
  scheduledDiaryGeneration,
  scheduledHolidays,
};
