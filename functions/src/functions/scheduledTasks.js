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

      // 全ユーザーを取得
      const usersSnapshot = await db.collection("users").get();

      logger.info("Starting daily diary generation", {
        userCount: usersSnapshot.docs.length,
      });

      let successCount = 0;
      let errorCount = 0;
      let totalCharacters = 0;

      // 並行制御: 同時に5件まで処理
      const pLimit = (await import("p-limit")).default;
      const limit = pLimit(5);

      const processCharacter = async (userId, characterId) => {
        try {
          await generateDiary(characterId, userId);
          successCount++;
          logger.info("Diary generated successfully", {userId, characterId});
          return {success: true, userId, characterId};
        } catch (error) {
          errorCount++;
          logger.error("Failed to generate diary", error, {userId, characterId});
          return {success: false, userId, characterId, error};
        }
      };

      const promises = [];

      // 各ユーザーのキャラクターを取得して処理
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const characterId = userData.character_id;

        logger.info("Checking user", {userId, characterId});

        // character_idが存在し、details/currentドキュメントがあるか確認
        if (!characterId) {
          logger.info("User has no character_id", {userId});
          continue;
        }

        // キャラクター詳細が存在するか確認
        const detailsDoc = await db.collection("users").doc(userId)
            .collection("characters").doc(characterId)
            .collection("details").doc("current").get();

        if (!detailsDoc.exists) {
          logger.info("Character details not found", {userId, characterId});
          continue;
        }

        totalCharacters++;
        promises.push(limit(() => processCharacter(userId, characterId)));
      }

      const results = await Promise.allSettled(promises);

      // 失敗した処理を集計
      const failures = results
          .filter((result) => result.status === "rejected" ||
              !result.value?.success)
          .map((result) => result.value || result.reason);

      logger.success("Daily diary generation completed", {
        totalUsers: usersSnapshot.docs.length,
        totalCharacters: totalCharacters,
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
