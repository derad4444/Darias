// Subscription validation and user tier management service
const {getFirestore, admin} = require("../utils/firebaseInit");
const {MODEL_TIERS, FEATURE_LIMITS} = require("../config/modelTiers");
const {Logger} = require("../utils/logger");

const db = getFirestore();
const logger = new Logger("SubscriptionService");

class SubscriptionService {
  /**
   * ユーザーのサブスクリプション状態を取得・検証
   * @param {string} userId - ユーザーID
   * @return {Promise<Object>} - ユーザー情報とTier情報
   */
  static async getUserTier(userId) {
    try {
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) {
        throw new Error(`User not found: ${userId}`);
      }

      const userData = userDoc.data();
      const subscription = userData.subscription || {};

      // サブスクリプション状態を検証
      const isValidPremium = await this.validatePremiumSubscription(subscription);
      const currentTier = isValidPremium ? "premium" : "free";

      // 今日の使用量をチェック・更新
      const usageInfo = await this.updateDailyUsage(userId, userData);

      return {
        userId,
        tier: currentTier,
        subscription: {
          status: subscription.status || "free",
          expires_at: subscription.expires_at,
          is_valid: isValidPremium
        },
        usage: usageInfo,
        limits: MODEL_TIERS[currentTier],
        features: FEATURE_LIMITS[currentTier]
      };
    } catch (error) {
      logger.error("Failed to get user tier", { userId, error: error.message });
      // エラー時は無料ユーザーとして扱う
      return {
        userId,
        tier: "free",
        subscription: { status: "free", is_valid: false },
        usage: { chat_count_today: 0, remaining_chats: MODEL_TIERS.free.maxDailyChats },
        limits: MODEL_TIERS.free,
        features: FEATURE_LIMITS.free
      };
    }
  }

  /**
   * プレミアムサブスクリプションの有効性を検証
   * @param {Object} subscription - サブスクリプション情報
   * @return {boolean} - 有効かどうか
   */
  static async validatePremiumSubscription(subscription) {
    if (!subscription || subscription.status !== "premium") {
      return false;
    }

    // 期限チェック
    if (subscription.expires_at) {
      const now = new Date();
      const expiresAt = subscription.expires_at.toDate();

      if (now > expiresAt) {
        logger.info("Premium subscription expired", {
          expires_at: expiresAt,
          current_time: now
        });
        return false;
      }
    }

    return true;
  }

  /**
   * 今日の使用量を更新・取得
   * @param {string} userId - ユーザーID
   * @param {Object} userData - 現在のユーザーデータ
   * @return {Promise<Object>} - 使用量情報
   */
  static async updateDailyUsage(userId, userData) {
    const today = new Date().toLocaleDateString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }).replace(/\//g, '-');

    const usage = userData.usage_tracking || {};
    const lastChatDate = usage.last_chat_date;

    let chatCountToday = usage.chat_count_today || 0;

    // 日付が変わっていればカウンターをリセット
    if (lastChatDate !== today) {
      chatCountToday = 0;

      // 日付更新
      await db.collection("users").doc(userId).update({
        "usage_tracking.chat_count_today": 0,
        "usage_tracking.last_chat_date": today,
        "updated_at": admin.firestore.FieldValue.serverTimestamp()
      });
    }

    return {
      chat_count_today: chatCountToday,
      last_chat_date: today,
      total_chats: usage.total_chats || 0,
      video_ad_counter: usage.video_ad_counter || 0
    };
  }

  /**
   * チャット使用回数を増加
   * @param {string} userId - ユーザーID
   * @return {Promise<Object>} - 更新後の使用量情報
   */
  static async incrementChatUsage(userId) {
    try {
      const userRef = db.collection("users").doc(userId);

      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        const userData = userDoc.data();
        const usage = userData.usage_tracking || {};

        const newChatCount = (usage.chat_count_today || 0) + 1;
        const newTotalChats = (usage.total_chats || 0) + 1;

        transaction.update(userRef, {
          "usage_tracking.chat_count_today": newChatCount,
          "usage_tracking.total_chats": newTotalChats,
          "updated_at": admin.firestore.FieldValue.serverTimestamp()
        });
      });

      logger.debug("Chat usage incremented", { userId });

    } catch (error) {
      logger.error("Failed to increment chat usage", { userId, error: error.message });
      throw error;
    }
  }

  /**
   * 使用制限チェック
   * @param {Object} userInfo - getUserTierから取得したユーザー情報
   * @param {string} feature - チェックする機能名
   * @return {Object} - 制限情報 {allowed: boolean, reason?: string}
   */
  static checkUsageLimit(userInfo, feature = "chat") {
    const { tier, usage, limits } = userInfo;

    switch (feature) {
      case "chat":
        // 無料ユーザーも広告視聴により無制限利用可能
        return { allowed: true };

      case "voice_generation":
        if (!userInfo.features.voiceGeneration) {
          return {
            allowed: false,
            reason: "feature_not_available_in_tier",
            required_tier: "premium"
          };
        }
        return { allowed: true };

      default:
        return { allowed: true };
    }
  }

  /**
   * 広告表示チェック（5回チャット毎に表示）
   * @param {string} userId - ユーザーID
   * @param {Object} userInfo - ユーザー情報
   * @return {Promise<Object>} - 広告表示情報
   */
  static async checkAdDisplay(userId, userInfo) {
    if (userInfo.tier === "premium") {
      return { shouldShowAd: false, reason: "premium_user" };
    }

    const usage = userInfo.usage;
    const totalChatsToday = usage.chat_count_today || 0;
    const adFrequency = userInfo.features.adFrequency || 5;

    // 5回毎に広告表示（5, 10, 15, 20, 25...回目）
    if (totalChatsToday > 0 && totalChatsToday % adFrequency === 0) {
      return {
        shouldShowAd: true,
        chatCount: totalChatsToday,
        adType: "video",
        trigger: "frequency_reached",
        frequency: adFrequency,
        reward: {
          additional_chats: userInfo.features.adRewardChats || 5,
          message: "動画広告を見て5回分のチャットを獲得！"
        }
      };
    }

    return {
      shouldShowAd: false,
      reason: "frequency_not_reached",
      nextAdAt: Math.ceil(totalChatsToday / adFrequency) * adFrequency
    };
  }

  /**
   * 広告視聴完了処理
   * @param {string} userId - ユーザーID
   * @param {number} additionalChats - 追加チャット回数
   * @return {Promise<Object>} - 処理結果
   */
  static async completeAdViewing(userId, additionalChats = 5) {
    try {
      const userRef = db.collection("users").doc(userId);

      await userRef.update({
        "usage_tracking.video_ad_counter": admin.firestore.FieldValue.increment(1),
        "ad_settings.last_video_ad_shown": admin.firestore.FieldValue.serverTimestamp(),
        "updated_at": admin.firestore.FieldValue.serverTimestamp()
      });

      // remaining_chatsを増加（既存フィールド）
      await userRef.update({
        remaining_chats: admin.firestore.FieldValue.increment(additionalChats)
      });

      logger.info("Ad viewing completed, chats added", {
        userId,
        additionalChats
      });

      return {
        success: true,
        additionalChats,
        message: `${additionalChats}回分のチャットが追加されました！`
      };

    } catch (error) {
      logger.error("Failed to complete ad viewing", { userId, error: error.message });
      throw error;
    }
  }
}

module.exports = { SubscriptionService };