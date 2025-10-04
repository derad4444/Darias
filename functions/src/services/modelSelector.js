// AI Model selection service based on user subscription tier
const {MODEL_TIERS, MODEL_FALLBACK_CHAIN, MODEL_COSTS} = require("../config/modelTiers");
const {SubscriptionService} = require("./subscriptionService");
const {Logger} = require("../utils/logger");

const logger = new Logger("ModelSelector");

class ModelSelector {
  /**
   * ユーザーのTierに基づいて最適なモデルを選択
   * @param {string} userId - ユーザーID
   * @param {string} taskType - タスク種別 (characterReply, big5Analysis, etc.)
   * @param {Object} options - 追加オプション
   * @return {Promise<Object>} - 選択されたモデル情報
   */
  static async selectModel(userId, taskType, options = {}) {
    try {
      // ユーザーのTier情報を取得
      const userInfo = await SubscriptionService.getUserTier(userId);

      // 使用制限チェック
      const limitCheck = SubscriptionService.checkUsageLimit(userInfo, "chat");
      if (!limitCheck.allowed) {
        throw new Error(`Usage limit exceeded: ${limitCheck.reason}`);
      }

      // Tierに基づいてモデルを選択
      const allowedModels = userInfo.limits.allowedModels;
      const primaryModel = allowedModels[taskType];

      if (!primaryModel) {
        throw new Error(`No model defined for task: ${taskType} in tier: ${userInfo.tier}`);
      }

      // モデル可用性チェック（オプション）
      const selectedModel = await this.validateModelAvailability(
        primaryModel,
        taskType,
        userInfo.tier,
        options
      );

      // コストとパフォーマンス情報を付加
      const modelInfo = {
        model: selectedModel,
        tier: userInfo.tier,
        taskType,
        estimatedCost: this.estimateCost(selectedModel, options.estimatedTokens || 1000),
        rateLimits: userInfo.limits.rateLimits,
        features: userInfo.features,
        metadata: {
          userId,
          selectedAt: new Date().toISOString(),
          fallbackUsed: selectedModel !== primaryModel
        }
      };

      logger.info("Model selected", {
        userId,
        tier: userInfo.tier,
        taskType,
        model: selectedModel,
        primaryModel,
        fallbackUsed: selectedModel !== primaryModel
      });

      return modelInfo;

    } catch (error) {
      logger.error("Model selection failed", {
        userId,
        taskType,
        error: error.message
      });

      // エラー時は無料Tierの最低モデルを返す
      return this.getFallbackModel(taskType);
    }
  }

  /**
   * モデルの可用性を検証し、必要に応じてフォールバックモデルを返す
   * @param {string} primaryModel - 第一選択モデル
   * @param {string} taskType - タスク種別
   * @param {string} tier - ユーザーTier
   * @param {Object} options - 追加オプション
   * @return {Promise<string>} - 利用可能なモデル名
   */
  static async validateModelAvailability(primaryModel, taskType, tier, options) {
    // プライマリモデルをまず試す
    if (await this.isModelAvailable(primaryModel)) {
      return primaryModel;
    }

    // フォールバックチェーンを確認
    const fallbackModels = MODEL_FALLBACK_CHAIN[primaryModel] || [];

    for (const fallbackModel of fallbackModels) {
      // Tierでそのフォールバックモデルが許可されているかチェック
      const tierModels = Object.values(MODEL_TIERS[tier].allowedModels);

      if (tierModels.includes(fallbackModel) && await this.isModelAvailable(fallbackModel)) {
        logger.warn("Using fallback model", {
          primary: primaryModel,
          fallback: fallbackModel,
          taskType,
          tier
        });
        return fallbackModel;
      }
    }

    // すべて失敗した場合は最低限モデル
    logger.error("All models unavailable, using emergency fallback", {
      primaryModel,
      taskType,
      tier
    });

    return "gpt-3.5-turbo"; // 緊急時フォールバック
  }

  /**
   * モデルの可用性をチェック（実際のAPI呼び出しは行わない）
   * @param {string} modelName - チェックするモデル名
   * @return {Promise<boolean>} - 利用可能かどうか
   */
  static async isModelAvailable(modelName) {
    // 実際の実装では、OpenAI APIの状態やレート制限をチェック
    // ここでは簡単な実装として、既知のモデルかどうかのみチェック
    const knownModels = ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"];
    return knownModels.includes(modelName);
  }

  /**
   * 緊急時フォールバックモデルを取得
   * @param {string} taskType - タスク種別
   * @return {Object} - フォールバックモデル情報
   */
  static getFallbackModel(taskType) {
    return {
      model: "gpt-3.5-turbo",
      tier: "free",
      taskType,
      estimatedCost: this.estimateCost("gpt-3.5-turbo", 1000),
      rateLimits: MODEL_TIERS.free.rateLimits,
      features: MODEL_TIERS.free.features,
      metadata: {
        emergencyFallback: true,
        selectedAt: new Date().toISOString()
      }
    };
  }

  /**
   * 推定コストを計算
   * @param {string} modelName - モデル名
   * @param {number} estimatedTokens - 推定トークン数
   * @return {Object} - コスト情報
   */
  static estimateCost(modelName, estimatedTokens) {
    const costs = MODEL_COSTS[modelName];
    if (!costs) {
      return { estimated_usd: 0, warning: "Unknown model cost" };
    }

    // 入力トークンと出力トークンを推定（入力:出力 = 2:1 と仮定）
    const inputTokens = Math.ceil(estimatedTokens * 0.7);
    const outputTokens = Math.ceil(estimatedTokens * 0.3);

    const inputCost = (inputTokens / 1000) * costs.input;
    const outputCost = (outputTokens / 1000) * costs.output;
    const totalCost = inputCost + outputCost;

    return {
      estimated_usd: totalCost,
      breakdown: {
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        input_cost_usd: inputCost,
        output_cost_usd: outputCost
      }
    };
  }

  /**
   * Tierアップグレード推奨チェック
   * @param {string} userId - ユーザーID
   * @param {string} requestedFeature - リクエストされた機能
   * @return {Promise<Object>} - アップグレード情報
   */
  static async checkUpgradeRecommendation(userId, requestedFeature) {
    const userInfo = await SubscriptionService.getUserTier(userId);

    if (userInfo.tier === "premium") {
      return { recommendUpgrade: false };
    }

    // 機能制限チェック
    const limitCheck = SubscriptionService.checkUsageLimit(userInfo, requestedFeature);

    if (!limitCheck.allowed) {
      return {
        recommendUpgrade: true,
        reason: limitCheck.reason,
        currentTier: userInfo.tier,
        recommendedTier: "premium",
        benefits: [
          "無制限チャット",
          "高品質AI応答 (GPT-4o)",
          "音声生成機能",
          "高度な性格分析",
          "広告非表示"
        ]
      };
    }

    return { recommendUpgrade: false };
  }
}

module.exports = { ModelSelector };