# Cloud Functions 設計書

> DARIAS バックエンドの Cloud Functions 一覧と構成

**最終更新日**: 2026-03-07
**ランタイム**: Node.js 20
**関数数**: 16

---

## 目次

1. [アーキテクチャ概要](#アーキテクチャ概要)
2. [関数一覧（詳細）](#関数一覧詳細)
3. [ファイル構成](#ファイル構成)
4. [依存パッケージ](#依存パッケージ)
5. [環境変数・シークレット](#環境変数シークレット)
6. [設計パターン](#設計パターン)

---

## アーキテクチャ概要

```
クライアント (iOS / Flutter / Web)
        │
        ▼
┌──────────────────────────────────────────────┐
│           Cloud Functions (Node.js 20)        │
│                                               │
│  ┌─────────────┐  ┌────────────────────────┐ │
│  │ onCall (7)   │  │ onSchedule (5)         │ │
│  │ クライアント  │  │ 定期バッチ処理          │ │
│  │ から直接呼出  │  │ (日次/月次/年次)        │ │
│  └──────┬──────┘  └───────────┬────────────┘ │
│         │                      │              │
│  ┌──────┴──────┐  ┌──────────┴────────────┐ │
│  │ onRequest(2)│  │ onDocumentCreated (2)  │ │
│  │ HTTP直接    │  │ Firestore書込トリガー   │ │
│  └──────┬──────┘  └───────────┬────────────┘ │
│         │                      │              │
└─────────┼──────────────────────┼──────────────┘
          │                      │
          ▼                      ▼
┌──────────────────────────────────────────────┐
│  Firebase / 外部サービス                       │
│  ┌──────────┐ ┌────────┐ ┌────────────────┐ │
│  │ Firestore │ │Storage │ │ OpenAI API     │ │
│  └──────────┘ └────────┘ └────────────────┘ │
│  ┌──────────┐ ┌────────┐ ┌────────────────┐ │
│  │  Auth    │ │ Gmail  │ │ Apple/Google   │ │
│  │         │ │ SMTP   │ │ Store API      │ │
│  └──────────┘ └────────┘ └────────────────┘ │
│  ┌──────────────────────────────────────┐    │
│  │ Google Cloud Text-to-Speech API      │    │
│  └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

---

## 関数一覧（詳細）

### HTTP Callable (`onCall`) - 7 関数

クライアントから Firebase SDK 経由で呼び出す。認証コンテキスト付き。

#### 1. `generateCharacterReply`
- **ソース**: `const/generateCharacterReply.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: OpenAI でキャラクター応答を生成（感情検出付き）
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **その他**: `minInstances: 0`, `enforceAppCheck: false`

#### 2. `extractSchedule`
- **ソース**: `const/extractSchedule.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: ユーザーメッセージから予定情報を OpenAI で抽出
- **リソース**: memory `512MiB` / timeout `120秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **その他**: `minInstances: 0`, `enforceAppCheck: false`

#### 3. `generateVoice`
- **ソース**: `const/generateVoice.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: テキストを Google Cloud TTS で音声化し Storage に保存
- **リソース**: memory `512MiB` / timeout `180秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし
- **その他**: `minInstances: 0`

#### 4. `generateBig5Analysis` (エクスポート名: `generateBig5AnalysisCallable`)
- **ソース**: `const/generateBig5Analysis.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: BIG5 性格診断スコアから解析データを生成・キャッシュ
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`

#### 5. `validateAppStoreReceipt`
- **ソース**: `validateReceipt.js`
- **API バージョン**: **v1** (`firebase-functions` — `functions.https.onCall`)
- **概要**: Apple App Store レシート検証 → サブスクリプション更新
- **リソース**: 未指定（v1 デフォルト: memory 256MiB / timeout 60秒）
- **リージョン**: 未指定（v1 デフォルト: us-central1）
- **secrets**: なし（`process.env.APPLE_SHARED_SECRET` または `functions.config().apple.shared_secret` を実行時に参照）

#### 6. `validateGooglePlayReceipt`
- **ソース**: `validateReceipt.js`
- **API バージョン**: **v1** (`firebase-functions` — `functions.https.onCall`)
- **概要**: Google Play レシート検証 → サブスクリプション更新
- **リソース**: 未指定（v1 デフォルト）
- **リージョン**: 未指定（v1 デフォルト）
- **secrets**: なし（`process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY`、`process.env.GOOGLE_PLAY_PACKAGE_NAME` を実行時に参照）

#### 7. `generateOrReuseMeeting`
- **ソース**: `src/functions/generateSixPersonMeeting.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: 6人会議の AI 会話を生成（キャッシュ再利用あり）
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`

---

### Scheduled Tasks (`onSchedule`) - 5 関数

Cloud Scheduler による定期実行バッチ。

#### 8. `scheduledHolidays`
- **ソース**: `src/functions/scheduledTasks.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 当年＋翌年の日本の祝日を Firestore に登録
- **スケジュール**: `0 1 1 1 *` (毎年1月1日 01:00 JST)
- **リソース**: memory `512MiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

#### 9. `scheduledDiaryGeneration`
- **ソース**: `src/functions/scheduledTasks.js` → `const/generateDiary.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 全ユーザーの当日アクティビティを集約し、アクティビティ型日記を自動生成（並列5件ずつ）
- **スケジュール**: `50 23 * * *` (毎日 23:50 JST)
- **リソース**: memory `1GiB` / timeout `540秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **収集データ**: スケジュール / チャット / 完了Todo / 作成Todo / メモ / 性格診断セッション / 6人会議
- **出力形式**: `diary_type: "activity"`, `facts: string[]`, `ai_comment: string` を Firestore に保存
- **モデル選択**: premium ユーザー → `gpt-4o-2024-11-20` / free ユーザー → `gpt-4o-mini`（`response_format: json_object` 指定）

#### 10. `generateMonthlyReview`
- **ソース**: `src/functions/generateMonthlyReview.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 前月のスケジュールからキャラ別月次レビューを生成
- **スケジュール**: `0 9 1 * *` (毎月1日 09:00 JST)
- **リソース**: memory `1GiB` / timeout `540秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

#### 11. `checkSubscriptionStatus`
- **ソース**: `validateReceipt.js`
- **API バージョン**: **v1** (`firebase-functions` — `functions.scheduler.onSchedule`)
- **概要**: 期限切れサブスクリプションを検出し free に更新
- **スケジュール**: `0 0 * * *` (毎日 00:00 JST)
- **リソース**: 未指定（v1 デフォルト）
- **リージョン**: 未指定（v1 デフォルト）
- **secrets**: なし

#### 12. `backfillSixPersonalities`
- **ソース**: `src/functions/generateSixPersonMeeting.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 6性格バリアントが未生成のユーザーを補完
- **スケジュール**: `0 3 * * *` (毎日 03:00 JST)
- **リソース**: memory `512MiB` / timeout `540秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

---

### Firestore Triggers (`onDocumentCreated`) - 2 関数

Firestore ドキュメント作成時に自動実行。

#### 13. `sendRegistrationEmail`
- **ソース**: `src/functions/sendRegistrationEmail.js`
- **API バージョン**: v2 (`firebase-functions/v2/firestore`)
- **トリガーパス**: `users/{userId}`
- **概要**: 新規ユーザー作成時に Welcome メールを送信
- **リソース**: 未指定（v2 デフォルト）
- **リージョン**: 未指定（v2 デフォルト）
- **secrets**: `GMAIL_USER`, `GMAIL_APP_PASSWORD`（オブジェクト参照）

#### 14. `sendContactEmail`
- **ソース**: `sendContactEmail.js`
- **API バージョン**: v2 (`firebase-functions/v2/firestore`)
- **トリガーパス**: `contacts/{contactId}`
- **概要**: 問い合わせ作成時に管理者＋ユーザーへメール送信
- **リソース**: 未指定（v2 デフォルト）
- **リージョン**: 未指定（v2 デフォルト）
- **secrets**: `GMAIL_USER`, `GMAIL_APP_PASSWORD`（オブジェクト参照）

---

### HTTP Endpoints (`onRequest`) - 2 関数

REST API として直接アクセス可能。

#### 15. `generateMonthlyReviewHttp`
- **ソース**: `src/functions/generateMonthlyReview.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: 月次レビューのテスト・手動実行用 HTTP エンドポイント
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

#### 16. `health`
- **ソース**: `health.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: ヘルスチェック（Cloud Run モニタリング用）
- **リソース**: memory `128MiB` / timeout `60秒`
- **リージョン**: `asia-northeast1`
- **その他**: `minInstances: 0`, `maxInstances: 1`

---

## ファイル構成

```
shared/functions/
├── index.js                          # エントリーポイント（遅延ロード）
├── package.json                      # 依存関係定義
├── .env                              # 環境変数（ローカル/デプロイ用）
│
├── health.js                         # ヘルスチェック
├── validateReceipt.js                # サブスクリプション検証 (Apple/Google/日次チェック) ※v1 API
├── sendContactEmail.js               # 問い合わせメール送信
│
├── const/                            # AI・音声系の callable 関数
│   ├── generateCharacterReply.js     # キャラクター返信生成
│   ├── extractSchedule.js            # 予定抽出
│   ├── generateVoice.js              # 音声合成
│   ├── generateBig5Analysis.js       # BIG5 解析
│   ├── generateDiary.js              # アクティビティ型日記生成（scheduledDiaryGeneration から呼出）
│   └── big5Questions.js              # BIG5 質問定義・スコア計算
│
└── src/
    ├── config/
    │   └── config.js                 # defineSecret 定義（OPENAI_API_KEY, GMAIL_USER, GMAIL_APP_PASSWORD）
    ├── clients/
    │   └── openai.js                 # OpenAI クライアント初期化・安全呼出ラッパー
    ├── prompts/
    │   └── templates.js              # OpenAI プロンプトテンプレート（diary / activityDiary / characterReply / big5Analysis 等）
    ├── functions/                     # スケジュール系・複合関数
    │   ├── scheduledTasks.js          # 祝日登録 + 日記自動生成
    │   ├── generateMonthlyReview.js   # 月次レビュー
    │   ├── generateSixPersonMeeting.js # 6人会議
    │   └── sendRegistrationEmail.js   # 登録メール
    └── utils/
        └── logger.js                  # ログヘルパー
```

---

## 依存パッケージ

`package.json` の `dependencies` から抽出:

| パッケージ | バージョン | 用途 |
|-----------|----------|------|
| `firebase-functions` | ^6.0.1 | Cloud Functions ランタイム (v1/v2 両方使用) |
| `firebase-admin` | ^12.6.0 | Firestore / Auth / Storage 管理 |
| `firebase-tools` | ^14.5.1 | Firebase CLI（デプロイ用） |
| `openai` | ^4.97.0 | OpenAI API（チャット・解析・会議生成） |
| `axios` | ^1.9.0 | HTTP クライアント（Apple レシート検証） |
| `googleapis` | ^171.4.0 | Google Play Developer API（レシート検証） |
| `@google-cloud/text-to-speech` | ^6.1.0 | 音声合成 |
| `@google-cloud/tasks` | ^6.1.0 | Cloud Tasks |
| `nodemailer` | ^7.0.6 | メール送信（Gmail SMTP） |
| `p-limit` | ^3.1.0 | 並列処理の同時実行制限 |
| `dotenv` | ^16.4.5 | `.env` ファイル読み込み |

---

## 環境変数・シークレット

### Firebase Functions v2 Secrets (`defineSecret`)

`src/config/config.js` で定義。v2 関数の `secrets` オプションで参照。

| 変数名 | 用途 | 使用関数 |
|--------|------|---------|
| `OPENAI_API_KEY` | OpenAI API 認証 | generateCharacterReply, extractSchedule, generateBig5Analysis, generateOrReuseMeeting, scheduledDiaryGeneration |
| `GMAIL_USER` | Gmail 送信元アドレス | sendRegistrationEmail, sendContactEmail |
| `GMAIL_APP_PASSWORD` | Gmail アプリパスワード | sendRegistrationEmail, sendContactEmail |

### 環境変数 (`process.env` / `.env`)

v1 関数や `require` 時に参照。`dotenv` で `.env` ファイルから読み込み。

| 変数名 | 用途 | 使用関数 |
|--------|------|---------|
| `APPLE_SHARED_SECRET` | App Store レシート検証の共有シークレット。`functions.config().apple.shared_secret` でもフォールバック | validateAppStoreReceipt |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` | Google Play Developer API サービスアカウント JSON 文字列 | validateGooglePlayReceipt |
| `GOOGLE_PLAY_PACKAGE_NAME` | Android アプリのパッケージ名 | validateGooglePlayReceipt |
| `GCLOUD_PROJECT` / `GCP_PROJECT` | GCP プロジェクト ID | generateVoice |
| `FIREBASE_STORAGE_BUCKET` | Cloud Storage バケット名 | generateVoice |

---

## 設計パターン

### 遅延ロード (Lazy Loading)

`index.js` で `Object.defineProperty` の getter を使い、関数が初めて呼ばれた時のみモジュールを読み込む。コールドスタート時間を短縮。

```js
Object.defineProperty(exports, "functionName", {
  get: () => require("./path").functionName,
  enumerable: true,
});
```

### v1 / v2 混在

- 大部分の関数は **v2 API** (`firebase-functions/v2/`) を使用
- `validateReceipt.js` の3関数（validateAppStoreReceipt, validateGooglePlayReceipt, checkSubscriptionStatus）のみ **v1 API** (`firebase-functions`) を使用
- v1 関数はリージョン・メモリ・タイムアウトが未指定のためデフォルト値（us-central1, 256MiB, 60秒）が適用される

### キャッシュ再利用

`generateOrReuseMeeting` は同じ性格タイプ＋類似の悩みに対してキャッシュされた会議結果を返す。OpenAI API コスト削減が目的。

### 並列処理制御

`p-limit` を使い、バッチ処理（日記生成など）の同時実行数を最大5に制限。Firestore の書き込みレート制限と OpenAI のレートリミットに配慮。

### サブスクリプション管理

プレミアム判定の唯一のソースは Firestore `users/{userId}/subscription/current`。

- **iOS**: StoreKit → PurchaseManager → Firestore 直接書き込み + Cloud Functions レシート検証
- **Android**: Google Play → Flutter purchase_service → `validateGooglePlayReceipt` Cloud Function
- **Web**: (将来) Stripe → Webhook → Cloud Function
- **日次バッチ**: `checkSubscriptionStatus` が期限切れを自動検出

ユーザードキュメント `users/{userId}.subscriptionStatus` にも `"premium"` / `"free"` を同期（Cloud Functions の `updateUserSubscription` と iOS `PurchaseManager` が書き込み）。

---

*最終更新: 2026-03-07*
