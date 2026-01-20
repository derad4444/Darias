// Model tier configuration for subscription-based access
// Defines which AI models are available for different user tiers

const MODEL_TIERS = {
  // 無料ユーザー設定
  free: {
    maxDailyChats: -1,                    // 無制限（広告視聴で継続可能）
    allowedModels: {
      characterReply: "gpt-3.5-turbo",    // 基本会話
      emotionDetect: "gpt-3.5-turbo",     // 感情判定
      scheduleExtract: "gpt-3.5-turbo",   // スケジュール抽出
      diary: "gpt-3.5-turbo",             // 日記生成
      big5Analysis: "gpt-4o",             // Big5分析（詳細レベル）
      characterDetails: "gpt-4o"          // キャラ詳細（詳細レベル）
    },
    features: {
      highQualityAnalysis: true,          // 高品質分析有効（詳細レベル）
      advancedPersonality: true,          // 高度な性格分析有効
      voiceGeneration: false,             // 音声生成無効
      customCharacterCreation: true       // カスタムキャラ作成有効
    },
    rateLimits: {
      requestsPerMinute: 5,               // 分間リクエスト制限
      tokensPerRequest: 1000              // リクエスト当たりトークン制限
    }
  },

  // 有料ユーザー設定
  premium: {
    maxDailyChats: -1,                    // 無制限（-1）
    allowedModels: {
      characterReply: "gpt-4o",           // 高品質会話
      emotionDetect: "gpt-4o-mini",       // 高精度感情判定
      scheduleExtract: "gpt-4o-mini",     // 高精度スケジュール抽出
      diary: "gpt-4o",                    // 高品質日記生成
      big5Analysis: "gpt-4o",             // 詳細Big5分析
      characterDetails: "gpt-4o"          // 詳細キャラ設定
    },
    features: {
      highQualityAnalysis: true,          // 高品質分析有効
      advancedPersonality: true,          // 高度な性格分析有効
      voiceGeneration: true,              // 音声生成有効
      customCharacterCreation: true       // カスタムキャラ作成有効
    },
    rateLimits: {
      requestsPerMinute: 30,              // 高いレート制限
      tokensPerRequest: 4000              // 高いトークン制限
    }
  }
};

// モデル選択の優先順位とフォールバック
const MODEL_FALLBACK_CHAIN = {
  "gpt-4o": ["gpt-4o-mini", "gpt-3.5-turbo"],
  "gpt-4o-mini": ["gpt-3.5-turbo"],
  "gpt-3.5-turbo": [] // フォールバックなし
};

// コスト設定（1000トークンあたりのコスト、USD）
const MODEL_COSTS = {
  "gpt-4o": { input: 0.005, output: 0.015 },
  "gpt-4o-mini": { input: 0.00015, output: 0.0006 },
  "gpt-3.5-turbo": { input: 0.0005, output: 0.0015 }
};

// 機能制限設定
const FEATURE_LIMITS = {
  free: {
    big5Questions: 100,                   // 性格解析は全100問対応
    characterDetailFields: -1,            // キャラ詳細も全項目生成対応
    diaryHistoryDays: -1,                 // 日記履歴無期限保存
    voiceGenerationDaily: 0,              // 音声生成制限（無効）
    advancedAnalysisDepth: true,          // 高度な分析深度（有効）詳細レベルで統一
    adFrequency: 5,                       // 5回チャット毎に動画広告表示
    adRewardChats: 5,                     // 広告視聴で5回分追加
    showBig5Scores: false                 // Big5スコア非表示
  },
  premium: {
    big5Questions: 100,                   // 性格解析は全100問
    characterDetailFields: -1,            // キャラ詳細全項目対応
    diaryHistoryDays: -1,                 // 日記履歴無期限保存
    voiceGenerationDaily: 50,             // 音声生成（1日50回まで）
    advancedAnalysisDepth: true,          // 高度な分析深度（有効）
    adFrequency: 0,                       // 広告表示なし
    adRewardChats: 0,                     // 広告なし
    showBig5Scores: false                 // Big5スコア非表示（統一）
  }
};

module.exports = {
  MODEL_TIERS,
  MODEL_FALLBACK_CHAIN,
  MODEL_COSTS,
  FEATURE_LIMITS
};