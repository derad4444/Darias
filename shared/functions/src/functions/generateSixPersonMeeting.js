// src/functions/generateSixPersonMeeting.js

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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
  createMeetingPrompt,
} = require("../prompts/sixPersonMeetingTemplates");

const db = getFirestore();
const logger = new Logger("SixPersonMeeting");

/**
 * 6人会議を生成またはキャッシュから取得する
 *
 * アーキテクチャ:
 * 1. ユーザーの閲覧履歴を取得
 * 2. 閲覧済みを除外してキャッシュ検索
 * 3. キャッシュヒット → 再利用（コスト削減）
 * 4. キャッシュミス → AI生成（100% AI、約0.2円/回）
 * 5. 同じユーザーには異なる会議を提供
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

        const {big5, gender, personalityKey, sixPersonalities} = characterData;

        // 4. カテゴリの自動検出（指定がない場合）
        const category = concernCategory || detectConcernCategory(concern);

        // 5. 過去の閲覧履歴を取得（同じ会議を見せないため）
        const viewedMeetings = await getViewedMeetings(userId, characterId);
        logger.info("Retrieved viewing history", {
          viewedCount: viewedMeetings.length,
        });

        // 6. 【CRITICAL】キャッシュ検索（性格タイプのみ、カテゴリ非依存）
        logger.info("Searching cache (category-independent)", {
          personalityKey,
          detectedCategory: category, // 記録用のみ
        });
        const cacheResult = await searchMeetingCache(
            personalityKey,
            viewedMeetings,
        );

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

          // 6人のキャラクター生成（保存済みがあればそれを使用、なければ計算）
          const personalities = sixPersonalities ||
            generateSixPersonalities(big5, gender);

          if (sixPersonalities) {
            logger.info("✅ Using pre-calculated six personalities");
          } else {
            logger.info("⚠️ No pre-calculated personalities, generating on-the-fly");
          }

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

        // 7. ユーザーの meeting_history に参照を保存
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

        // 8. レスポンス
        const response = {
          success: true,
          meetingId: sharedMeetingId,
          conversation,
          statsData,
          cacheHit,
          usageCount: usageCount + 1,
          duration,
        };

        // デバッグ: レスポンスの構造を確認
        logger.info("Response structure", {
          hasConversation: !!response.conversation,
          roundsCount: response.conversation?.rounds?.length,
          firstRoundMessages: response.conversation?.rounds?.[0]?.messages?.length,
          statsDataKeys: Object.keys(response.statsData || {}),
        });

        // デバッグ: 実際のJSONをログ出力（最初の100文字のみ）
        const jsonString = JSON.stringify(response);
        logger.info("Response JSON (first 500 chars)", {
          json: jsonString.substring(0, 500),
          totalLength: jsonString.length,
        });

        return response;
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
 * @return {Promise<Object>} - {big5, gender, personalityKey, sixPersonalities}
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
      sixPersonalities: data.sixPersonalities || null, // 保存済みがあれば取得
    };
  } catch (error) {
    logger.error("Failed to get character data", {error: error.message});
    return null;
  }
}

/**
 * ユーザーの過去の閲覧履歴を取得
 * @param {string} userId - ユーザーID
 * @param {string} characterId - キャラクターID
 * @return {Promise<Array<string>>} - 閲覧済みsharedMeetingIdの配列
 */
async function getViewedMeetings(userId, characterId) {
  try {
    const historySnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("characters")
        .doc(characterId)
        .collection("meeting_history")
        .get();

    const viewedIds = historySnapshot.docs.map((doc) => doc.data().sharedMeetingId);
    logger.info("Retrieved viewed meetings", {
      userId,
      characterId,
      viewedCount: viewedIds.length,
    });

    return viewedIds;
  } catch (error) {
    logger.error("Failed to get viewed meetings", {error: error.message});
    return [];
  }
}

/**
 * キャッシュから会議を検索（閲覧履歴を除外）
 * カテゴリ非依存: 性格タイプのみでマッチング
 * @param {string} personalityKey - 性格キー
 * @param {Array<string>} excludeIds - 除外するsharedMeetingIdの配列
 * @return {Promise<Object|null>} - キャッシュデータ or null
 */
async function searchMeetingCache(personalityKey, excludeIds = []) {
  try {
    const cacheQuery = await db
        .collection("shared_meetings")
        .where("personalityKey", "==", personalityKey)
        .orderBy("usageCount", "desc")
        .get();

    if (cacheQuery.empty) {
      return null;
    }

    // 除外リストに含まれていない最初のドキュメントを返す
    for (const doc of cacheQuery.docs) {
      if (!excludeIds.includes(doc.id)) {
        logger.info("Cache hit (category-independent)", {
          meetingId: doc.id,
          excludedCount: excludeIds.length,
          cachedCategory: doc.data().concernCategory, // 記録用
        });
        return {
          id: doc.id,
          ...doc.data(),
        };
      }
    }

    // すべて除外リストに含まれていた場合
    logger.info("All cached meetings were excluded", {
      totalCached: cacheQuery.docs.length,
      excludedCount: excludeIds.length,
    });
    return null;
  } catch (error) {
    logger.error("Cache search failed", {
      error: error.message,
      errorCode: error.code,
      errorDetails: error.details || error.toString(),
    });
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
        personalityKey,
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
      personalityKey,
    };
  }
}

/**
 * 会話を生成（100% AI生成）
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
  logger.info("Generating conversation with AI (100% AI mode)");
  return await generateConversationWithAI(
      concern,
      category,
      personalities,
      statsData,
  );
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

  // JSON解析（エラーハンドリング強化）
  try {
    const conversation = JSON.parse(content);
    return conversation;
  } catch (parseError) {
    logger.error("Failed to parse AI response as JSON", {
      error: parseError.message,
      contentPreview: content.substring(0, 500),
      contentLength: content.length,
    });
    throw new Error(`AI returned invalid JSON: ${parseError.message}`);
  }
}

/**
 * 既存ユーザーのsixPersonalitiesフィールドをバックフィル
 * 毎日深夜3時に自動実行（JST）
 * generateCharacterReplyで生成されなかったユーザーを拾う保険処理
 */
exports.backfillSixPersonalities = onSchedule(
    {
      schedule: "0 3 * * *", // 毎日午前3時 JST
      timeZone: "Asia/Tokyo",
      region: "asia-northeast1",
      timeoutSeconds: 540, // 9分
      memory: "512MiB",
    },
    async (event) => {
      const startTime = Date.now();
      logger.info("Backfill started (scheduled)");

      try {
        // collection groupクエリで全ユーザーのdetailsを検索
        const detailsQuery = await db
            .collectionGroup("details")
            .where("analysis_level", "==", 100)
            .get();

        logger.info(`Found ${detailsQuery.size} users with analysis_level=100`);

        let processedCount = 0;
        let skippedCount = 0;
        let errorCount = 0;

        // バッチ処理（500件ごとにコミット）
        const batchSize = 500;
        let batch = db.batch();
        let batchCount = 0;

        for (const doc of detailsQuery.docs) {
          try {
            const data = doc.data();

            // すでにsixPersonalitiesが存在する場合はスキップ
            if (data.sixPersonalities) {
              skippedCount++;
              continue;
            }

            // confirmedBig5Scoresが存在しない場合もスキップ
            if (!data.confirmedBig5Scores) {
              logger.warn("No confirmedBig5Scores found", {docPath: doc.ref.path});
              skippedCount++;
              continue;
            }

            // 6人の性格を生成
            const sixPersonalities = generateSixPersonalities(
                data.confirmedBig5Scores,
                data.gender || "male",
            );

            // バッチに追加
            batch.update(doc.ref, {
              sixPersonalities: sixPersonalities,
              updated_at: new Date(),
            });

            batchCount++;
            processedCount++;

            // バッチサイズに達したらコミット
            if (batchCount >= batchSize) {
              await batch.commit();
              logger.info(`Committed batch of ${batchCount} updates`);
              batch = db.batch();
              batchCount = 0;
            }
          } catch (error) {
            logger.error("Error processing document", {
              docPath: doc.ref.path,
              error: error.message,
            });
            errorCount++;
          }
        }

        // 残りのバッチをコミット
        if (batchCount > 0) {
          await batch.commit();
          logger.info(`Committed final batch of ${batchCount} updates`);
        }

        const duration = Date.now() - startTime;
        const result = {
          success: true,
          totalDocuments: detailsQuery.size,
          processedCount,
          skippedCount,
          errorCount,
          durationMs: duration,
        };

        logger.info("Backfill completed (scheduled)", result);
      } catch (error) {
        logger.error("Backfill failed", {error: error.message});
        throw error;
      }
    },
);
