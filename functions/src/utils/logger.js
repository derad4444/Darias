// src/utils/logger.js

/**
 * 統一されたログ出力ユーティリティ
 */
class Logger {
  constructor(context = "Unknown") {
    this.context = context;
  }

  info(message, data = null) {
    const logEntry = {
      level: "INFO",
      context: this.context,
      message,
      timestamp: new Date().toISOString(),
      ...(data && {data}),
    };
    console.log(JSON.stringify(logEntry));
  }

  error(message, error = null, data = null) {
    const errorInfo = error ? {
      name: error.name,
      message: error.message,
      stack: error.stack,
    } : null;

    const logEntry = {
      level: "ERROR",
      context: this.context,
      message,
      timestamp: new Date().toISOString(),
      ...(errorInfo && {error: errorInfo}),
      ...(data && {data}),
    };
    console.error(JSON.stringify(logEntry));
  }

  warn(message, data = null) {
    const logEntry = {
      level: "WARN",
      context: this.context,
      message,
      timestamp: new Date().toISOString(),
      ...(data && {data}),
    };
    console.warn(JSON.stringify(logEntry));
  }

  debug(message, data = null) {
    if (process.env.NODE_ENV === "development") {
      const logEntry = {
        level: "DEBUG",
        context: this.context,
        message,
        timestamp: new Date().toISOString(),
        ...(data && {data}),
      };
      console.debug(JSON.stringify(logEntry));
    }
  }

  // 成功時の専用メソッド
  success(message, data = null) {
    const logEntry = {
      level: "SUCCESS",
      context: this.context,
      message,
      timestamp: new Date().toISOString(),
      ...(data && {data}),
    };
    console.log(JSON.stringify(logEntry));
  }

  // 関数の開始/終了ログ
  functionStart(functionName, params = null) {
    this.info(`Function started: ${functionName}`, params);
  }

  functionEnd(functionName, duration = null, result = null) {
    const data = {};
    if (duration !== null) data.duration = `${duration}ms`;
    if (result !== null) data.result = result;

    this.success(`Function completed: ${functionName}`, data);
  }
}

module.exports = {Logger};
