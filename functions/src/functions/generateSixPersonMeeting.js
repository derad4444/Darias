// src/functions/generateSixPersonMeeting.js

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore} = require("../utils/firebaseInit");
const {getOpenAIClient, safeOpenAICall} = require("../clients/openai");
const {OPENAI_API_KEY} = require("../config/config");
const {Logger} = require("../utils/logger");
const {
  generateSixPersonalities,
  calculateSimilarity,
  detectConcernCategory,
  generatePersonalityKey,
} = require("../utils/sixPersonMeeting");
const {
  generateConversationFromTemplate,
  createMeetingPrompt,
} = require("../prompts/sixPersonMeetingTemplates");

const db = getFirestore();
const logger = new Logger("SixPersonMeeting");

/**
 * 6人会議を生成またはキャッシュから取得する
 * キャッシュ優先のアーキテクチャ
 */
exports.generateOrReuseMeeting = onCall(
    {
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 300,
      secrets: ["OPENAI_API_KEY"],
    },
    async (request) => {
      const startTime = Date.now();
      const {userId, characterId, concern, concernCategory} = request.data;

      try {
        // 1. 認証チェック
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "認証が必要です");
        }

        if (request.auth.uid !== userId) {
          throw new HttpsError("permission-denied", "権限がありません");
        }

        logger.info("Meeting generation started", {userId, characterId});

        // 2. プレミアムチェック
        const isPremium = await checkPremiumStatus(userId);
        const usageCount = await getMeetingUsageCount(userId, characterId);

        if (!isPremium && usageCount >= 1) {
          throw new HttpsError(
              "resource-exhausted",
              "無料ユーザーは1回のみ利用可能です。プレミアムにアップグレードしてください。",
          );
        }

        // 3. キャラクターのBIG5とpersonalityKeyを取得
        const characterData = await getCharacterData(userId, characterId);
        if (!characterData) {
          throw new HttpsError("not-found", "キャラクターデータが見つかりません");
        }

        const {big5, gender, personalityKey} = characterData;

        // 4. カテゴリの自動検出（指定がない場合）
        const category = concernCategory || detectConcernCategory(concern);

        // 5. 【CRITICAL】キャッシュ検索
        logger.info("Searching cache", {personalityKey, category});
        const cacheResult = await searchMeetingCache(personalityKey, category);

        let sharedMeetingId;
        let conversation;
        let statsData;
        let cacheHit = false;

        if (cacheResult) {
          // ✅ キャッシュヒット - 既存データを再利用
          logger.info("✅ Cache HIT! Reusing existing meeting", {
            sharedMeetingId: cacheResult.id,
            usageCount: cacheResult.usageCount,
          });

          sharedMeetingId = cacheResult.id;
          conversation = cacheResult.conversation;
          statsData = cacheResult.statsData;
          cacheHit = true;

          // usageCountをインクリメント
          await db.collection("shared_meetings").doc(sharedMeetingId).update({
            usageCount: cacheResult.usageCount + 1,
            lastUsedAt: new Date(),
          });
        } else {
          // ❌ キャッシュミス - 新規生成
          logger.info("❌ Cache MISS. Generating new meeting...");

          // 6人のキャラクター生成
          const personalities = generateSixPersonalities(big5, gender);

          // 類似性格の統計データ取得
          statsData = await calculateStatsFromAnalysis(personalityKey, big5);

          // 会話生成（テンプレート or AI）
          conversation = await generateConversation(
              concern,
              category,
              personalities,
              statsData,
              isPremium,
          );

          // shared_meetingsに保存（キャッシュ化）
          const sharedMeetingRef = await db.collection("shared_meetings").add({
            personalityKey,
            concernCategory: category,
            conversation,
            statsData,
            usageCount: 1,
            ratings: {
              avgRating: 0,
              totalRatings: 0,
              ratingSum: 0,
            },
            createdAt: new Date(),
            lastUsedAt: new Date(),
          });

          sharedMeetingId = sharedMeetingRef.id;
          cacheHit = false;

          logger.info("New meeting created and cached", {sharedMeetingId});
        }

        // 6. ユーザーの meeting_history に参照を保存
        await db
            .collection("users")
            .doc(userId)
            .collection("characters")
            .doc(characterId)
            .collection("meeting_history")
            .add({
              sharedMeetingId,
              userConcern: concern,
              concernCategory: category,
              userBIG5: big5,
              cacheHit,
              createdAt: new Date(),
            });

        const duration = Date.now() - startTime;
        logger.info("Meeting generation completed", {
          duration,
          cacheHit,
          sharedMeetingId,
        });

        // 7. レスポンス
        return {
          success: true,
          meetingId: sharedMeetingId,
          conversation,
          statsData,
          cacheHit,
          usageCount: usageCount + 1,
          duration,
        };
      } catch (error) {
        logger.error("Meeting generation failed", {error: error.message});
        throw error;
      }
    },
);

/**
 * プレミアムステータスをチェック
 * @param {string} userId - ユーザーID
 * @return {Promise<boolean>} - プレミアムかどうか
 */
async function checkPremiumStatus(userId) {
  try {
    // 新しいサブスクリプション構造をチェック
    const subscriptionDoc = await db
        .collection("users")
        .doc(userId)
        .collection("subscription")
        .doc("current")
        .get();

    if (!subscriptionDoc.exists) {
      logger.info("No subscription document found for user", {userId});
      return false;
    }

    const subscriptionData = subscriptionDoc.data();
    const status = subscriptionData.status;
    const plan = subscriptionData.plan;

    logger.info("Checking premium status", {
      userId,
      status,
      plan,
      hasEndDate: !!subscriptionData.end_date,
    });

    // statusがactiveまたはplanがpremiumの場合
    if (status === "active" || plan === "premium") {
      // 有効期限をチェック
      if (subscriptionData.end_date) {
        const endDate = subscriptionData.end_date.toDate();
        const isValid = new Date() < endDate;
        logger.info("Premium subscription with end date", {
          userId,
          endDate,
          isValid,
        });
        return isValid;
      }

      // end_dateがnullの場合は無期限premium
      logger.info("Premium subscription without end date (lifetime)", {userId});
      return true;
    }

    logger.info("User is not premium", {userId, status, plan});
    return false;
  } catch (error) {
    logger.error("Premium check failed", {error: error.message});
    return false;
  }
}

/**
 * 会議の利用回数を取得
 * @param {string} userId - ユーザーID
 * @param {string} characterId - キャラクターID
 * @return {Promise<number>} - 利用回数
 */
async function getMeetingUsageCount(userId, characterId) {
  try {
    const historySnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("characters")
        .doc(characterId)
        .collection("meeting_history")
        .count()
        .get();

    return historySnapshot.data().count;
  } catch (error) {
    logger.error("Usage count check failed", {error: error.message});
    return 0;
  }
}

/**
 * キャラクターデータを取得
 * @param {string} userId - ユーザーID
 * @param {string} characterId - キャラクターID
 * @return {Promise<Object>} - {big5, gender, personalityKey}
 */
async function getCharacterData(userId, characterId) {
  try {
    const detailDoc = await db
        .collection("users")
        .doc(userId)
        .collection("characters")
        .doc(characterId)
        .collection("details")
        .doc("current")
        .get();

    if (!detailDoc.exists) {
      return null;
    }

    const data = detailDoc.data();
    return {
      big5: data.confirmedBig5Scores,
      gender: data.gender,
      personalityKey: data.personalityKey,
    };
  } catch (error) {
    logger.error("Failed to get character data", {error: error.message});
    return null;
  }
}

/**
 * キャッシュから会議を検索
 * @param {string} personalityKey - 性格キー
 * @param {string} category - カテゴリ
 * @return {Promise<Object|null>} - キャッシュデータ or null
 */
async function searchMeetingCache(personalityKey, category) {
  try {
    const cacheQuery = await db
        .collection("shared_meetings")
        .where("personalityKey", "==", personalityKey)
        .where("concernCategory", "==", category)
        .orderBy("usageCount", "desc")
        .limit(1)
        .get();

    if (cacheQuery.empty) {
      return null;
    }

    const doc = cacheQuery.docs[0];
    return {
      id: doc.id,
      ...doc.data(),
    };
  } catch (error) {
    logger.error("Cache search failed", {error: error.message});
    return null;
  }
}

/**
 * Big5Analysisから統計データを計算
 * @param {string} personalityKey - ユーザーのpersonalityKey
 * @param {Object} userBig5 - ユーザーのBIG5スコア
 * @return {Promise<Object>} - 統計データ
 */
async function calculateStatsFromAnalysis(personalityKey, userBig5) {
  try {
    // PersonalityStatsMetadataから全体統計を取得
    const statsDoc = await db
        .collection("PersonalityStatsMetadata")
        .doc("summary")
        .get();

    if (!statsDoc.exists) {
      return {
        similarCount: 0,
        totalUsers: 0,
        avgAge: 30,
        percentile: 50,
      };
    }

    const statsData = statsDoc.data();
    const totalUsers = statsData.total_completed_users || 0;
    const personalityCounts = statsData.personality_counts || {};

    // 同じpersonalityKeyを持つユーザー数
    const exactMatchCount = personalityCounts[personalityKey] || 0;

    // 類似性格の計算（簡易版：各スコア±1の範囲）
    let similarCount = exactMatchCount;

    // 年齢は固定値（実際のデータがない場合）
    const avgAge = 30;

    // パーセンタイル計算（簡易版）
    const percentile = totalUsers > 0 ?
      Math.round((exactMatchCount / totalUsers) * 100) :
      50;

    return {
      similarCount,
      totalUsers,
      avgAge,
      percentile,
      personalityKey,
    };
  } catch (error) {
    logger.error("Stats calculation failed", {error: error.message});
    return {
      similarCount: 0,
      totalUsers: 0,
      avgAge: 30,
      percentile: 50,
    };
  }
}

/**
 * 会話を生成（テンプレート or AI）
 * @param {string} concern - ユーザーの悩み
 * @param {string} category - カテゴリ
 * @param {Array<Object>} personalities - 6人のキャラクター
 * @param {Object} statsData - 統計データ
 * @param {boolean} isPremium - プレミアムユーザーかどうか
 * @return {Promise<Object>} - 会話データ
 */
async function generateConversation(
    concern,
    category,
    personalities,
    statsData,
    isPremium,
) {
  try {
    // 80%の確率でテンプレート使用、20%でAI生成
    const useTemplate = Math.random() < 0.8;

    if (useTemplate) {
      logger.info("Using template for conversation");
      return generateConversationFromTemplate(category, personalities);
    } else {
      logger.info("Using AI for conversation generation");
      return await generateConversationWithAI(
          concern,
          category,
          personalities,
          statsData,
      );
    }
  } catch (error) {
    logger.error("Conversation generation failed, falling back to template", {
      error: error.message,
    });
    // エラー時はテンプレートにフォールバック
    return generateConversationFromTemplate(category, personalities);
  }
}

/**
 * AIで会話を生成
 * @param {string} concern - ユーザーの悩み
 * @param {string} category - カテゴリ
 * @param {Array<Object>} personalities - 6人のキャラクター
 * @param {Object} statsData - 統計データ
 * @return {Promise<Object>} - 会話データ
 */
async function generateConversationWithAI(
    concern,
    category,
    personalities,
    statsData,
) {
  const apiKey = OPENAI_API_KEY.value().trim();
  if (!apiKey) {
    throw new Error("OpenAI API key not configured");
  }

  const openai = getOpenAIClient(apiKey);
  const prompt = createMeetingPrompt(concern, category, personalities, statsData);

  const completion = await safeOpenAICall(
      openai.chat.completions.create.bind(openai.chat.completions),
      {
        model: "gpt-4o-mini",
        messages: [{role: "user", content: prompt}],
        temperature: 0.8,
        max_tokens: 2000,
      },
  );

  let content = completion.choices[0].message.content.trim();

  // マークダウン記法除去
  if (content.startsWith("```json")) {
    content = content.replace(/^```json\s*/, "").replace(/```$/, "").trim();
  } else if (content.startsWith("```")) {
    content = content.replace(/^```\s*/, "").replace(/```$/, "").trim();
  }

  // JSON解析
  const conversation = JSON.parse(content);

  return conversation;
}
