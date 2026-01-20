// Usage tracking middleware for API calls and subscription management
const {SubscriptionService} = require("../services/subscriptionService");
const {ModelSelector} = require("../services/modelSelector");
const {Logger} = require("../utils/logger");

const logger = new Logger("UsageTrackingMiddleware");

class UsageTrackingMiddleware {
  /**
   * Firebase Functions用のミドルウェア
   * 各OpenAI API呼び出し前に使用制限をチェック
   * @param {string} taskType - タスクタイプ
   * @return {Function} - ミドルウェア関数
   */
  static forFunction(taskType) {
    return async (request, context) => {
      const startTime = Date.now();
      const {data} = request;
      const userId = data.userId;

      if (!userId) {
        throw new Error("userId is required for usage tracking");
      }

      try {
        logger.info("Usage tracking started", {
          userId,
          taskType,
          functionName: context.function?.name || "unknown"
        });

        // ユーザー情報とモデル選択
        const modelInfo = await ModelSelector.selectModel(userId, taskType, {
          estimatedTokens: data.estimatedTokens || 1000
        });

        // 使用量を事前チェック
        const userInfo = await SubscriptionService.getUserTier(userId);
        const limitCheck = SubscriptionService.checkUsageLimit(userInfo, "chat");

        if (!limitCheck.allowed) {
          // 制限に達している場合の処理
          const upgradeInfo = await ModelSelector.checkUpgradeRecommendation(userId, "chat");

          throw new Error(JSON.stringify({
            type: "usage_limit_exceeded",
            reason: limitCheck.reason,
            current: limitCheck.current,
            limit: limitCheck.limit,
            upgrade_recommendation: upgradeInfo
          }));
        }

        // リクエストデータにモデル情報を注入
        request.data = {
          ...data,
          _modelInfo: modelInfo,
          _userInfo: userInfo,
          _trackingContext: {
            startTime,
            taskType,
            userId
          }
        };

        logger.debug("Request enhanced with tracking info", {
          userId,
          tier: userInfo.tier,
          model: modelInfo.model,
          taskType
        });

        return request;

      } catch (error) {
        logger.error("Usage tracking failed", {
          userId,
          taskType,
          error: error.message
        });
        throw error;
      }
    };
  }

  /**
   * API呼び出し後の使用量更新
   * @param {Object} request - リクエストオブジェクト
   * @param {Object} result - API呼び出し結果
   * @param {Object} usage - OpenAI使用量情報
   * @return {Promise<void>}
   */
  static async postProcessUsage(request, result, usage = {}) {
    const {data} = request;
    const trackingContext = data._trackingContext;

    if (!trackingContext) {
      logger.warn("No tracking context found in request");
      return;
    }

    const {userId, taskType, startTime} = trackingContext;
    const duration = Date.now() - startTime;

    try {
      // チャット使用回数を増加
      await SubscriptionService.incrementChatUsage(userId);

      // 使用量ログ記録
      await this.logUsage({
        userId,
        taskType,
        model: data._modelInfo?.model,
        tier: data._userInfo?.tier,
        duration,
        tokens: usage.total_tokens || 0,
        cost_usd: data._modelInfo?.estimatedCost?.estimated_usd || 0,
        success: !!result,
        timestamp: new Date()
      });

      logger.info("Usage tracking completed", {
        userId,
        taskType,
        duration,
        tokens: usage.total_tokens,
        success: !!result
      });

    } catch (error) {
      logger.error("Post-process usage tracking failed", {
        userId,
        taskType,
        error: error.message
      });
      // 使用量追跡の失敗は致命的ではないため、エラーを投げない
    }
  }

  /**
   * 使用量ログをFirestoreに記録
   * @param {Object} usageData - 使用量データ
   * @return {Promise<void>}
   */
  static async logUsage(usageData) {
    try {
      const {getFirestore, admin} = require("../utils/firebaseInit");
      const db = getFirestore();

      // 日次集計用のドキュメントID
      const today = new Date().toISOString().split('T')[0];
      const logId = `${usageData.userId}_${today}_${Date.now()}`;

      await db.collection("usage_logs").doc(logId).set({
        ...usageData,
        created_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // 日次サマリーも更新
      await this.updateDailySummary(usageData);

    } catch (error) {
      logger.error("Failed to log usage", { error: error.message });
    }
  }

  /**
   * 日次使用量サマリーを更新
   * @param {Object} usageData - 使用量データ
   * @return {Promise<void>}
   */
  static async updateDailySummary(usageData) {
    try {
      const {getFirestore, admin} = require("../utils/firebaseInit");
      const db = getFirestore();

      const today = new Date().toISOString().split('T')[0];
      const summaryId = `${usageData.userId}_${today}`;

      await db.collection("daily_usage_summary").doc(summaryId).set({
        user_id: usageData.userId,
        date: today,
        tier: usageData.tier,
        total_requests: admin.firestore.FieldValue.increment(1),
        total_tokens: admin.firestore.FieldValue.increment(usageData.tokens || 0),
        total_cost_usd: admin.firestore.FieldValue.increment(usageData.cost_usd || 0),
        success_count: admin.firestore.FieldValue.increment(usageData.success ? 1 : 0),
        error_count: admin.firestore.FieldValue.increment(usageData.success ? 0 : 1),
        last_updated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

    } catch (error) {
      logger.error("Failed to update daily summary", { error: error.message });
    }
  }

  /**
   * レート制限チェック
   * @param {string} userId - ユーザーID
   * @param {Object} rateLimits - レート制限設定
   * @return {Promise<boolean>} - 制限内かどうか
   */
  static async checkRateLimit(userId, rateLimits) {
    try {
      const {getFirestore} = require("../utils/firebaseInit");
      const db = getFirestore();

      const now = new Date();
      const oneMinuteAgo = new Date(now.getTime() - 60 * 1000);

      // 過去1分間のリクエスト数をカウント
      const recentRequests = await db.collection("usage_logs")
        .where("userId", "==", userId)
        .where("timestamp", ">=", oneMinuteAgo)
        .where("success", "==", true)
        .get();

      const currentRequestCount = recentRequests.size;

      if (currentRequestCount >= rateLimits.requestsPerMinute) {
        logger.warn("Rate limit exceeded", {
          userId,
          currentRequests: currentRequestCount,
          limit: rateLimits.requestsPerMinute
        });
        return false;
      }

      return true;

    } catch (error) {
      logger.error("Rate limit check failed", { userId, error: error.message });
      // エラー時は制限なしとして扱う
      return true;
    }
  }

  /**
   * 使用統計取得（管理者用）
   * @param {string} startDate - 開始日 (YYYY-MM-DD)
   * @param {string} endDate - 終了日 (YYYY-MM-DD)
   * @return {Promise<Object>} - 使用統計
   */
  static async getUsageStatistics(startDate, endDate) {
    try {
      const {getFirestore} = require("../utils/firebaseInit");
      const db = getFirestore();

      const summaries = await db.collection("daily_usage_summary")
        .where("date", ">=", startDate)
        .where("date", "<=", endDate)
        .get();

      let totalStats = {
        total_users: new Set(),
        total_requests: 0,
        total_tokens: 0,
        total_cost_usd: 0,
        tier_breakdown: { free: 0, premium: 0 },
        daily_breakdown: {}
      };

      summaries.forEach(doc => {
        const data = doc.data();
        totalStats.total_users.add(data.user_id);
        totalStats.total_requests += data.total_requests || 0;
        totalStats.total_tokens += data.total_tokens || 0;
        totalStats.total_cost_usd += data.total_cost_usd || 0;
        totalStats.tier_breakdown[data.tier] = (totalStats.tier_breakdown[data.tier] || 0) + 1;

        if (!totalStats.daily_breakdown[data.date]) {
          totalStats.daily_breakdown[data.date] = {
            requests: 0,
            tokens: 0,
            cost_usd: 0,
            users: new Set()
          };
        }

        totalStats.daily_breakdown[data.date].requests += data.total_requests || 0;
        totalStats.daily_breakdown[data.date].tokens += data.total_tokens || 0;
        totalStats.daily_breakdown[data.date].cost_usd += data.total_cost_usd || 0;
        totalStats.daily_breakdown[data.date].users.add(data.user_id);
      });

      // Set を配列に変換
      totalStats.total_users = totalStats.total_users.size;
      Object.keys(totalStats.daily_breakdown).forEach(date => {
        totalStats.daily_breakdown[date].unique_users =
          totalStats.daily_breakdown[date].users.size;
        delete totalStats.daily_breakdown[date].users;
      });

      return totalStats;

    } catch (error) {
      logger.error("Failed to get usage statistics", { error: error.message });
      throw error;
    }
  }
}

module.exports = { UsageTrackingMiddleware };