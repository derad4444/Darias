// src/utils/errorHandler.js

const {Logger} = require("./logger");

/**
 * カスタムエラークラス
 */
class AppError extends Error {
  constructor(message, statusCode = 500, code = "UNKNOWN_ERROR") {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * エラーハンドリングユーティリティ
 */
class ErrorHandler {
  constructor(context) {
    this.logger = new Logger(context);
  }

  /**
   * エラーをログに記録し、適切なレスポンスを生成
   */
  handleError(error, functionName = "Unknown") {
    const errorInfo = {
      functionName,
      errorType: error.constructor.name,
      isOperational: error.isOperational || false,
    };

    if (error instanceof AppError) {
      this.logger.error(
          `Operational error in ${functionName}`, error, errorInfo,
      );
      return {
        success: false,
        error: {
          code: error.code,
          message: error.message,
          statusCode: error.statusCode,
        },
      };
    } else {
      this.logger.error(
          `Unexpected error in ${functionName}`, error, errorInfo,
      );
      return {
        success: false,
        error: {
          code: "INTERNAL_ERROR",
          message: "An unexpected error occurred",
          statusCode: 500,
        },
      };
    }
  }

  /**
   * 非同期関数をラップしてエラーハンドリングを追加
   */
  wrapAsync(fn, functionName) {
    return async (...args) => {
      const startTime = Date.now();
      this.logger.functionStart(functionName, {argsCount: args.length});

      try {
        const result = await fn(...args);
        const duration = Date.now() - startTime;
        this.logger.functionEnd(functionName, duration, {success: true});
        return result;
      } catch (error) {
        const duration = Date.now() - startTime;
        this.logger.error(
            `Function failed: ${functionName}`, error, {duration});
        throw error;
      }
    };
  }

  /**
   * Firebase Functions用のエラーレスポンス生成
   */
  createFirebaseResponse(error, functionName) {
    const errorResponse = this.handleError(error, functionName);

    if (error instanceof AppError) {
      return {
        data: errorResponse,
        status: error.statusCode,
      };
    } else {
      return {
        data: errorResponse,
        status: 500,
      };
    }
  }
}

/**
 * よく使用されるエラータイプのファクトリー関数
 */
const ErrorTypes = {
  ValidationError: (message) =>
    new AppError(message, 400, "VALIDATION_ERROR"),
  NotFoundError: (message) =>
    new AppError(message, 404, "NOT_FOUND"),
  AuthenticationError: (message) =>
    new AppError(message, 401, "AUTHENTICATION_ERROR"),
  AuthorizationError: (message) =>
    new AppError(message, 403, "AUTHORIZATION_ERROR"),
  ExternalServiceError: (message) =>
    new AppError(message, 502, "EXTERNAL_SERVICE_ERROR"),
  RateLimitError: (message) =>
    new AppError(message, 429, "RATE_LIMIT_ERROR"),
  TimeoutError: (message) =>
    new AppError(message, 504, "TIMEOUT_ERROR"),
};

module.exports = {
  AppError,
  ErrorHandler,
  ErrorTypes,
};
