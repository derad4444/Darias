# Cloud Functions - Optimized Structure

このプロジェクトは Firebase Cloud Functions を使用したキャラクターアプリのバックエンドサービスです。

## 📁 プロジェクト構造

```
functions/
├── src/                          # ソースコード
│   ├── config/                   # 設定管理
│   │   └── index.js             # 環境変数・アプリケーション設定
│   ├── functions/               # Firebase Functions
│   │   ├── characterReply.js    # キャラクター返答生成
│   │   ├── scheduleExtractor.js # スケジュール抽出
│   │   ├── voiceGenerator.js    # 音声生成
│   │   └── scheduledTasks.js    # スケジュールタスク
│   ├── services/                # ビジネスロジック（将来的な拡張用）
│   ├── utils/                   # ユーティリティ
│   │   ├── logger.js           # 統一ログ出力
│   │   ├── errorHandler.js     # エラーハンドリング
│   │   ├── validation.js       # バリデーション
│   │   └── security.js         # セキュリティ機能
│   ├── types/                   # 型定義（JSDoc）
│   │   └── index.js            # 型定義
│   └── index.js                # 新しいメインエントリーポイント
├── const/                       # 既存の実装（段階的移行中）
├── keys/                        # サービスアカウントキー
├── test/                        # テストファイル
├── index.js                     # Firebase Functions エントリーポイント
├── package.json                 # 依存関係
└── README.md                    # このファイル
```

## 🚀 主要な改善点

### 1. **構造化されたアーキテクチャ**
- 機能別フォルダ分割
- 責任の分離
- モジュール化による再利用性向上

### 2. **統一されたエラーハンドリング**
```javascript
const { ErrorHandler, ErrorTypes } = require('./utils/errorHandler');

// カスタムエラータイプ
throw ErrorTypes.ValidationError('Invalid input');
throw ErrorTypes.ExternalServiceError('API service unavailable');
```

### 3. **構造化ログ出力**
```javascript
const { Logger } = require('./utils/logger');
const logger = new Logger('FunctionName');

logger.info('Process started', { userId, requestId });
logger.error('Process failed', error, { context: 'additional data' });
```

### 4. **バリデーション強化**
```javascript
const { Validator } = require('./utils/validation');

// 型安全なバリデーション
Validator.validateCharacterId(characterId);
Validator.validateMessage(userMessage);
```

### 5. **セキュリティ対策**
```javascript
const { Security } = require('./utils/security');

// レート制限
Security.checkRateLimit(userId);
// 入力サニタイゼーション
const cleaned = Security.sanitizeInput(userInput);
```

## 📋 利用可能な関数

### HTTP Functions
- `generateCharacterReply` - キャラクターの返答生成
- `extractSchedule` - テキストからスケジュール抽出  
- `createVoice` - テキストから音声生成
- `generateBig5AnalysisCallable` - Big5性格解析生成（Firestore キャッシュあり）
- `generateCharacterAttributesCallable` - キャラクター属性生成

### Scheduled Functions
- `generateDiary` - 日記自動生成（毎日23:50）
- `generateCharacterMaster` - キャラクター画像生成マスター（毎日2:00）
- `generateCharacterWorker` - キャラクター画像生成ワーカー
- `scheduledCharacterDetails` - キャラクター詳細生成（毎日0:00）
- `scheduledHolidays` - 祝日登録（毎年1月1日）

## 🔧 開発・デプロイ

### ローカル開発
```bash
npm run serve
```

### デプロイ
```bash
npm run deploy
```

### ログ確認
```bash
npm run logs
```

## 🧪 テスト

```bash
npm test
```

## 🤖 AI モデル設定

### モデル選択方針（2026-04-04 更新）

| 機能 | 無料ユーザー | 有料ユーザー |
|---|---|---|
| **Big5性格解析** | gpt-4o-2024-11-20 | gpt-4o-2024-11-20 |
| キャラクター属性生成 | gpt-4o-mini | gpt-4o-2024-11-20 |
| キャラクター返答 | gpt-4o-mini | gpt-4o-2024-11-20 |
| 日記生成 | gpt-4o-mini | gpt-4o-2024-11-20 |
| スケジュール抽出 | gpt-4o-mini | gpt-4o-2024-11-20 |
| 感情判定 | gpt-4o-mini | gpt-4o-2024-11-20 |

> Big5性格解析のみ全ユーザーが最高精度モデルを使用。結果は Firestore (`Big5Analysis` コレクション) に `personalityKey` (例: `O3_C4_E2_A5_N1_male`) でキャッシュされるため、同一スコアの再生成は行われない（最大 6,250 通り）。

### Temperature 設定

| 機能 | Temperature | 備考 |
|---|---|---|
| Big5性格解析 | **1.0** | `response_format: json_object` で JSON 崩れを防止 |
| キャラクター属性生成 | 0.7 | `response_format: json_object` 使用 |
| キャラクター返答 | 0.7 | - |
| 日記生成 | 0.7 | - |
| スケジュール抽出 | 0 | 確定的出力が必要なため |
| 感情判定 | 0.3 | - |

### Big5 プロンプト形式

Big5 スコアは**数値と自然言語説明を両方**送信する形式を採用（2026-04-04 更新）。

**詳細形式**（Big5Analysis, CharacterAttributes）:
```
- 開放性(Openness): 3/5（新しさと安定のバランスを取る）
- 誠実性(Conscientiousness): 4/5（計画的でルーティンや目標達成を大切にする）
- 外向性(Extraversion): 2/5（一人の静かな時間を大切にする）
- 協調性(Agreeableness): 5/5（非常に共感力が高く他者への配慮を最優先にする）
- 神経症傾向(Neuroticism): 1/5（非常に感情が安定していてストレスに強い）
```

**コンパクト形式**（diary, activityDiary, characterDetails）:
```
O3(バランス型)C4(計画的)E2(内向的)A5(共感型)N1(超安定)
```

フォーマット関数は `src/prompts/templates.js` で一元管理：
- `formatBig5WithTraits(scores)` - 詳細形式
- `formatBig5ShortWithTraits(scores)` - コンパクト形式

## 📝 設定

環境変数とシークレットは `src/config/index.js` で管理されています：

- `OPENAI_API_KEY` - OpenAI API キー

## 🔒 セキュリティ

- レート制限実装
- 入力バリデーション・サニタイゼーション
- 構造化ログによる監視
- 機密情報のマスキング

## 📈 監視・ログ

すべての関数で統一されたログ形式を使用：

```json
{
  "level": "INFO",
  "context": "CharacterReply", 
  "message": "Function started",
  "timestamp": "2025-01-19T...",
  "data": { "userId": "...", "characterId": "..." }
}
```

## 🔄 段階的移行

現在は既存の `const/` フォルダの実装を使用しつつ、新しい構造でラップしています。将来的には完全に新しい実装に移行予定です。