// health.js - Cloud Run ヘルスチェック用エンドポイント
const {onRequest} = require("firebase-functions/v2/https");

/**
 * Cloud Run用ヘルスチェック関数
 * 完全にスタンドアロンで依存関係なし
 */
exports.health = onRequest(
    {
      region: "asia-northeast1",
      memory: "128MiB",
      timeoutSeconds: 60,
      minInstances: 0,
      maxInstances: 1,
    },
    (req, res) => {
      // 同期処理で最速応答
      res.status(200).json({
        status: "ok",
        timestamp: Date.now(),
        service: "firebase-functions-v2",
        container: "healthy",
      });
    },
);
