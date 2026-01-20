// src/clients/openai.js

const OpenAI = require("openai");
const {Logger} = require("../utils/logger");

const logger = new Logger("OpenAI");

/**
 * 共有OpenAIクライアント
 * モジュールレベルで初期化してインスタンス作成コストを削減
 */
let openaiClient = null;

/**
 * OpenAIクライアントを取得（シングルトンパターン）
 * @param {string} apiKey - OpenAI API Key
 * @return {OpenAI} OpenAI client instance
 */
function getOpenAIClient(apiKey) {
  if (!apiKey) {
    throw new Error("OpenAI API Key is required");
  }

  // 既存のクライアントが同じAPIキーの場合は再利用
  if (openaiClient && openaiClient.apiKey === apiKey) {
    return openaiClient;
  }

  // 新しいクライアントを作成
  logger.debug("Creating new OpenAI client");
  openaiClient = new OpenAI({
    apiKey,
    // タイムアウト設定
    timeout: 60000, // 60秒
    // リトライ設定
    maxRetries: 3,
  });

  // デバッグ用にAPIキーをクライアントに保存（最初の4文字のみ）
  openaiClient.apiKey = apiKey;

  return openaiClient;
}

/**
 * OpenAI APIのレスポンスをラップしてエラーハンドリングを統一
 * @param {Function} apiCall - OpenAI API呼び出し関数
 * @param {...any} args - API呼び出しの引数
 * @return {Promise} API結果
 */
async function safeOpenAICall(apiCall, ...args) {
  try {
    const startTime = Date.now();
    const result = await apiCall(...args);
    const duration = Date.now() - startTime;

    logger.debug("OpenAI API call completed", {
      duration,
      model: args[0]?.model,
      tokens: result.usage?.total_tokens,
    });

    return result;
  } catch (error) {
    logger.error("OpenAI API call failed", {
      error: error.message,
      type: error.type,
      code: error.code,
    });

    // エラーの種類に応じて適切な処理
    if (error.type === "insufficient_quota") {
      throw new Error("OpenAI API quota exceeded");
    } else if (error.code === "rate_limit_exceeded") {
      throw new Error("OpenAI API rate limit exceeded");
    } else if (error.code === "context_length_exceeded") {
      throw new Error("Input text too long for OpenAI model");
    }

    throw error;
  }
}

module.exports = {
  getOpenAIClient,
  safeOpenAICall,
};
