// src/functions/scheduledTasks.js

const {onSchedule} = require("firebase-functions/v2/scheduler");

let CONFIG; let Logger; let generateHolidaysForTwoYears; let generateDiary; let admin; let errorHandler;
let logger;

function initializeDependencies() {
  if (!CONFIG) {
    CONFIG = require("../config/config").CONFIG;
    Logger = require("../utils/logger").Logger;
    generateHolidaysForTwoYears = require("../../const/generateHolidays").generateHolidaysForTwoYears;
    generateDiary = require("../../const/generateDiary").generateDiary;
    admin = require("firebase-admin");
    errorHandler = require("../utils/errorHandler");

    logger = new Logger("ScheduledTasks");
  }
}

/**
 * 日記自動生成（毎日23:50 JST）+ 生成後にFCMプッシュ通知を送信
 */
const scheduledDiaryGeneration = onSchedule(
    {
      schedule: "50 23 * * *",
      timeZone: "Asia/Tokyo",
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 540,
    },
    async (event) => {
      initializeDependencies();

      const db = admin.firestore();
      const usersSnapshot = await db.collection("users").get();

      logger.info("Starting daily diary generation", {
        userCount: usersSnapshot.docs.length,
      });

      let successCount = 0;
      let errorCount = 0;
      let totalCharacters = 0;

      const pLimit = (await import("p-limit")).default;
      const limit = pLimit(5);

      /**
       * 日記を生成し、FCMトークンがあれば通知を送信する
       */
      const processCharacter = async (userId, characterId, characterName, fcmToken, diaryNotificationsEnabled) => {
        try {
          await generateDiary(characterId, userId);
          successCount++;
          logger.info("Diary generated successfully", {userId, characterId});

          // FCMプッシュ通知を送信（トークンあり、かつ通知が有効な場合）
          if (fcmToken && diaryNotificationsEnabled !== false) {
            try {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: `${characterName}の日記`,
                  body: `${characterName}が今日の日記を書きました`,
                },
                data: {
                  type: "diary",
                  userId,
                  characterId,
                },
                apns: {
                  payload: {aps: {sound: "default"}},
                },
                android: {
                  notification: {sound: "default"},
                },
              });
              logger.info("Diary notification sent", {userId});
            } catch (notifError) {
              // 無効なトークンは削除してクリーンアップ
              if (notifError.code === "messaging/registration-token-not-registered") {
                await db.collection("users").doc(userId)
                    .update({fcmToken: admin.firestore.FieldValue.delete()});
                logger.info("Cleaned up invalid FCM token", {userId});
              } else {
                logger.error("Failed to send diary notification", notifError, {userId});
              }
            }
          }

          return {success: true, userId, characterId};
        } catch (error) {
          errorCount++;
          logger.error("Failed to generate diary", error, {userId, characterId});
          return {success: false, userId, characterId, error};
        }
      };

      const promises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const characterId = userData.character_id;
        const fcmToken = userData.fcmToken || null;
        const diaryNotificationsEnabled = userData.diaryNotificationsEnabled;

        logger.info("Checking user", {userId, characterId});

        if (!characterId) {
          logger.info("User has no character_id", {userId});
          continue;
        }

        const detailsDoc = await db.collection("users").doc(userId)
            .collection("characters").doc(characterId)
            .collection("details").doc("current").get();

        if (!detailsDoc.exists) {
          logger.info("Character details not found", {userId, characterId});
          continue;
        }

        const characterName = detailsDoc.data()?.name || "キャラクター";
        totalCharacters++;
        promises.push(limit(() => processCharacter(userId, characterId, characterName, fcmToken, diaryNotificationsEnabled)));
      }

      const results = await Promise.allSettled(promises);

      const failures = results
          .filter((result) => result.status === "rejected" || !result.value?.success)
          .map((result) => result.value || result.reason);

      logger.success("Daily diary generation completed", {
        totalUsers: usersSnapshot.docs.length,
        totalCharacters,
        success: successCount,
        errors: errorCount,
        failures: failures.length > 0 ? failures.slice(0, 5) : undefined,
      });
    },
);

/**
 * 祝日登録（毎年1月1日1:00 JST）
 */
const scheduledHolidays = onSchedule(
    {
      schedule: "0 1 1 1 *",
      region: "asia-northeast1",
      timeZone: "Asia/Tokyo",
      memory: "512MiB",
      timeoutSeconds: 300,
    },
    async (event) => {
      initializeDependencies();

      const now = new Date();
      const currentYear = now.getFullYear();
      const nextYear = currentYear + 1;

      logger.info("Starting holiday generation for two years", {
        currentYear,
        nextYear,
      });

      try {
        await generateHolidaysForTwoYears();
        logger.success("Holiday generation completed for two years", {
          currentYear,
          nextYear,
        });
      } catch (error) {
        logger.error("Holiday generation failed", error, {
          currentYear,
          nextYear,
        });
        throw error;
      }
    },
);

module.exports = {
  scheduledDiaryGeneration,
  scheduledHolidays,
};
