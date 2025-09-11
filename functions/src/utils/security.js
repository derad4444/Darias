// src/utils/security.js

const admin = require("firebase-admin");
const {ErrorTypes} = require("./errorHandler");
const {Logger} = require("./logger");

const logger = new Logger("Security");

/**
 * セキュリティユーティリティ
 */
class Security {
  /**
   * 分散レート制限チェック（Firestore使用）
   * 本番環境対応版
   */
  static async checkRateLimit(userId, limit = 60, windowMs = 60000) {
    const now = Date.now();
    const windowStart = now - windowMs;
    const db = admin.firestore();

    try {
      // Firestoreでレート制限をチェック（トランザクション使用）
      const result = await db.runTransaction(async (transaction) => {
        const rateLimitRef = db.collection("rateLimit").doc(userId);
        const doc = await transaction.get(rateLimitRef);

        const data = doc.exists ? doc.data() : {requests: [], lastCleanup: now};

        // 古いリクエストを削除
        const validRequests = data.requests
            .filter((timestamp) => timestamp > windowStart);

        if (validRequests.length >= limit) {
          throw ErrorTypes.RateLimitError(
              "Rate limit exceeded. Try again later.");
        }

        // 新しいリクエストを追加
        validRequests.push(now);

        // ドキュメントを更新
        transaction.set(rateLimitRef, {
          requests: validRequests,
          lastCleanup: now,
        });

        return validRequests.length;
      });

      logger.debug("Rate limit check passed", {
        userId,
        currentRequests: result,
        limit,
        windowMs,
      });
    } catch (error) {
      if (error.code === "rate-limit-exceeded") {
        logger.warn("Rate limit exceeded", {
          userId,
          limit,
          window: windowMs,
        });
        throw error;
      }

      // Firestoreエラーの場合はフォールバック（インメモリ）
      logger.warn(
          "Firestore rate limit failed, using fallback",
          {error: error.message});
      return this.checkRateLimitFallback(userId, limit, windowMs);
    }
  }

  /**
   * フォールバック用インメモリレート制限
   */
  static rateLimit = new Map();

  static checkRateLimitFallback(userId, limit = 60, windowMs = 60000) {
    const now = Date.now();
    const key = `${userId}_${Math.floor(now / windowMs)}`;

    const current = this.rateLimit.get(key) || 0;

    if (current >= limit) {
      throw ErrorTypes.RateLimitError(`Rate limit exceeded. Try again later.`);
    }

    this.rateLimit.set(key, current + 1);

    // 古いエントリをクリーンアップ（メモリリーク防止）
    if (this.rateLimit.size > 1000) {
      const cutoff = now - windowMs * 2;
      for (const [k] of this.rateLimit) {
        const timestamp = parseInt(k.split("_")[1]) * windowMs;
        if (timestamp < cutoff) {
          this.rateLimit.delete(k);
        }
      }
    }
  }

  /**
   * 入力のサニタイゼーション
   */
  static sanitizeInput(input) {
    if (typeof input !== "string") {
      return input;
    }

    // HTMLタグの除去
    const sanitized = input
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
        .replace(/<[^>]*>/g, "")
        .trim();

    return sanitized;
  }

  /**
   * SQLインジェクション対策（Firebase使用時は基本不要だが念のため）
   */
  static validateNoSQLInjection(input) {
    if (typeof input !== "string") {
      return input;
    }

    const suspiciousPatterns = [
      /(\$where|\$regex|\$ne|\$gt|\$lt|\$in|\$nin)/i,
      /(javascript:|eval\(|function\()/i,
    ];

    for (const pattern of suspiciousPatterns) {
      if (pattern.test(input)) {
        logger.warn(
            "Suspicious input detected",
            {input: input.substring(0, 100)});
        throw ErrorTypes.ValidationError("Invalid input detected");
      }
    }

    return input;
  }

  /**
   * ユーザー認証の確認
   */
  static validateAuthentication(req) {
    // onCall関数の場合、auth情報が自動的に付与される
    if (req.auth && req.auth.uid) {
      return req.auth.uid;
    }

    // onRequest関数の場合の認証チェック
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      throw ErrorTypes.AuthenticationError("Authentication required");
    }

    // 実際の実装では、Firebase Admin SDKでトークンを検証
    // ここでは簡略化
    return null;
  }

  /**
   * CORS設定
   */
  static setCORSHeaders(
      res, allowedOrigins = ["https://your-app-domain.com"]) {
    const origin = res.req?.headers?.origin;

    if (allowedOrigins.includes(origin) ||
        process.env.NODE_ENV === "development") {
      res.set("Access-Control-Allow-Origin", origin || "*");
    }

    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.set("Access-Control-Max-Age", "3600");
  }

  /**
   * 機密情報のマスキング
   */
  static maskSensitiveData(data) {
    if (typeof data !== "object" || data === null) {
      return data;
    }

    const sensitiveFields = [
      "password", "token", "secret", "key", "apiKey"];
    const masked = {...data};

    for (const field of sensitiveFields) {
      if (masked[field]) {
        const value = masked[field].toString();
        masked[field] = value.substring(0, 4) +
            "*".repeat(Math.max(0, value.length - 4));
      }
    }

    return masked;
  }

  /**
   * リクエストサイズの制限
   */
  static validateRequestSize(req, maxSizeBytes = 1024 * 1024) { // 1MB
    const contentLength = req.headers["content-length"];

    if (contentLength && parseInt(contentLength) > maxSizeBytes) {
      throw ErrorTypes.ValidationError(
          `Request too large. Maximum size: ${maxSizeBytes} bytes`);
    }
  }
}

module.exports = {Security};
