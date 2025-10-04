// Rate limiting and fallback service for OpenAI API calls
const {Logger} = require("../utils/logger");
const {MODEL_FALLBACK_CHAIN} = require("../config/modelTiers");

const logger = new Logger("RateLimitService");

class RateLimitService {
  /**
   * レート制限と自動フォールバック付きでOpenAI APIを呼び出し
   * @param {Object} openaiClient - OpenAI クライアント
   * @param {string} primaryModel - 第一選択モデル
   * @param {Object} apiParams - API パラメータ
   * @param {Object} options - オプション設定
   * @return {Promise<Object>} - API レスポンス
   */
  static async callWithFallback(openaiClient, primaryModel, apiParams, options = {}) {
    const {
      maxRetries = 3,
      retryDelay = 1000,
      enableFallback = true,
      userId = "unknown"
    } = options;

    let currentModel = primaryModel;
    let lastError = null;

    // プライマリモデルとフォールバックモデルの配列を作成
    const modelChain = [currentModel];
    if (enableFallback && MODEL_FALLBACK_CHAIN[currentModel]) {
      modelChain.push(...MODEL_FALLBACK_CHAIN[currentModel]);
    }

    // 各モデルを順番に試行
    for (const modelToTry of modelChain) {
      logger.info("Attempting API call", {
        userId,
        model: modelToTry,
        isPrimary: modelToTry === primaryModel
      });

      for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          // APIパラメータにモデルを設定
          const paramsWithModel = {
            ...apiParams,
            model: modelToTry
          };

          // OpenAI API 呼び出し
          const response = await openaiClient.chat.completions.create(paramsWithModel);

          // 成功ログ
          logger.info("API call successful", {
            userId,
            model: modelToTry,
            attempt,
            tokens: response.usage?.total_tokens,
            fallbackUsed: modelToTry !== primaryModel
          });

          return {
            response,
            modelUsed: modelToTry,
            attemptsUsed: attempt,
            fallbackUsed: modelToTry !== primaryModel
          };

        } catch (error) {
          lastError = error;

          // エラータイプによる処理分岐
          const errorHandling = this.handleApiError(error, attempt, maxRetries);

          logger.warn("API call failed", {
            userId,
            model: modelToTry,
            attempt,
            error: error.message,
            errorType: errorHandling.type,
            shouldRetry: errorHandling.shouldRetry,
            shouldFallback: errorHandling.shouldFallback
          });

          // リトライ不要なエラーの場合は即座にフォールバック
          if (!errorHandling.shouldRetry) {
            break;
          }

          // 最後の試行でない場合は待機
          if (attempt < maxRetries) {
            await this.sleep(retryDelay * Math.pow(2, attempt - 1)); // 指数バックオフ
          }
        }
      }

      // このモデルでの全試行が失敗した場合、次のモデルを試行
      logger.warn("All retries failed for model", {
        userId,
        model: modelToTry,
        maxRetries
      });
    }

    // すべてのモデルで失敗した場合
    logger.error("All models and retries failed", {
      userId,
      primaryModel,
      triedModels: modelChain,
      lastError: lastError?.message
    });

    throw new Error(`API call failed for all models. Last error: ${lastError?.message}`);
  }

  /**
   * OpenAI APIエラーを分析して適切な処理を決定
   * @param {Error} error - APIエラー
   * @param {number} currentAttempt - 現在の試行回数
   * @param {number} maxRetries - 最大リトライ回数
   * @return {Object} - エラー処理情報
   */
  static handleApiError(error, currentAttempt, maxRetries) {
    const errorMessage = error.message?.toLowerCase() || "";
    const errorCode = error.code;
    const httpStatus = error.status;

    // レート制限エラー
    if (errorCode === "rate_limit_exceeded" || httpStatus === 429) {
      return {
        type: "rate_limit",
        shouldRetry: currentAttempt < maxRetries,
        shouldFallback: currentAttempt >= maxRetries,
        retryDelay: 60000 // 1分待機
      };
    }

    // クォータ不足エラー
    if (errorCode === "insufficient_quota" || errorMessage.includes("quota")) {
      return {
        type: "quota_exceeded",
        shouldRetry: false,
        shouldFallback: true
      };
    }

    // コンテキスト長エラー
    if (errorCode === "context_length_exceeded" || errorMessage.includes("maximum context length")) {
      return {
        type: "context_too_long",
        shouldRetry: false,
        shouldFallback: true
      };
    }

    // モデル利用不可エラー
    if (errorMessage.includes("model") && errorMessage.includes("not found")) {
      return {
        type: "model_not_found",
        shouldRetry: false,
        shouldFallback: true
      };
    }

    // サーバーエラー (5xx)
    if (httpStatus >= 500) {
      return {
        type: "server_error",
        shouldRetry: currentAttempt < maxRetries,
        shouldFallback: currentAttempt >= maxRetries,
        retryDelay: 5000 // 5秒待機
      };
    }

    // ネットワークエラー
    if (errorMessage.includes("network") || errorMessage.includes("timeout")) {
      return {
        type: "network_error",
        shouldRetry: currentAttempt < maxRetries,
        shouldFallback: false,
        retryDelay: 2000 // 2秒待機
      };
    }

    // その他のエラー（認証エラーなど）
    return {
      type: "other",
      shouldRetry: false,
      shouldFallback: true
    };
  }

  /**
   * レート制限状況を監視・管理
   * @param {string} model - モデル名
   * @return {Promise<Object>} - レート制限情報
   */
  static async checkRateLimitStatus(model) {
    try {
      // 実際の実装では Redis や Firestore でレート制限状況を管理
      // ここでは簡単な実装例

      const now = Date.now();
      const rateLimitKey = `rate_limit_${model}`;

      // 仮想的なレート制限チェック
      // 実際には OpenAI のレスポンスヘッダーや過去のエラー履歴を基に判定

      return {
        model,
        isLimited: false,
        resetTime: null,
        remainingRequests: 1000,
        windowStart: now,
        windowEnd: now + 60000 // 1分後
      };

    } catch (error) {
      logger.error("Failed to check rate limit status", {
        model,
        error: error.message
      });

      return {
        model,
        isLimited: false,
        error: error.message
      };
    }
  }

  /**
   * 指定時間待機
   * @param {number} ms - 待機時間（ミリ秒）
   * @return {Promise<void>}
   */
  static sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 緊急時フォールバック応答生成
   * @param {string} taskType - タスクタイプ
   * @param {Object} context - コンテキスト情報
   * @return {Object} - フォールバック応答
   */
  static generateEmergencyResponse(taskType, context = {}) {
    const emergencyResponses = {
      characterReply: {
        reply: "申し訳ございません。一時的にサービスが混雑しています。しばらくしてからもう一度お試しください。",
        emotion: "",
        voiceUrl: ""
      },

      big5Analysis: {
        career_analysis: "現在分析中です。しばらくお待ちください。",
        romance_analysis: "現在分析中です。しばらくお待ちください。",
        stress_analysis: "現在分析中です。しばらくお待ちください。",
        learning_analysis: "現在分析中です。しばらくお待ちください。",
        decision_analysis: "現在分析中です。しばらくお待ちください。"
      },

      diary: {
        content: "今日は忙しい一日でした。明日はもっと良い日になりそうです。",
        summary_tags: ["日常", "忙しい", "希望"]
      },

      scheduleExtract: {
        hasSchedule: false,
        message: "申し訳ございません。現在スケジュール解析が一時的に利用できません。"
      }
    };

    const response = emergencyResponses[taskType] || {
      message: "一時的なエラーが発生しました。しばらくしてからお試しください。"
    };

    logger.warn("Emergency response generated", {
      taskType,
      context
    });

    return {
      ...response,
      _emergency: true,
      _timestamp: new Date().toISOString()
    };
  }
}

module.exports = { RateLimitService };