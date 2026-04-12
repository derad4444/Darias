# Cloud Functions 設計書

> DARIAS バックエンドの Cloud Functions 一覧と構成

**最終更新日**: 2026-03-07
**ランタイム**: Node.js 20
**関数数**: 17

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
│  │ onCall (8)   │  │ onSchedule (5)         │ │
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

### HTTP Callable (`onCall`) - 8 関数

クライアントから Firebase SDK 経由で呼び出す。認証コンテキスト付き。

#### 1. `generateCharacterReply`
- **ソース**: `const/generateCharacterReply.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: チャットメッセージを受け取り、内容に応じて複数の処理を振り分けてAI返答を生成する
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **その他**: `minInstances: 0`, `enforceAppCheck: false`

**入力パラメータ:**

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `characterId` | `string` | キャラクターID |
| `userMessage` | `string` | ユーザーのメッセージ（100文字まで処理） |
| `userId` | `string` | Firebase Auth UID |
| `isPremium` | `boolean` | プレミアムユーザーフラグ |
| `chatHistory` | `array<{userMessage, aiResponse}>` | 直近2件の会話履歴 |
| `meetingContext` | `string` (optional) | 直近30日以内の会議結論（`"相談:xxx / 結論:yyy"` 形式）。チャットの文脈として使用 [Case 4] |

**返却値:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `reply` | `string` | AI返答テキスト。BIG5回答中（次の質問あり）は空文字。100問完了時は完了メッセージ |
| `isBig5Question` | `boolean` | BIG5回答モード中かどうか |
| `voiceUrl` | `string` | 常に `""`（音声はユーザーがスピーカーボタンを押した際に `generateVoice` で別途生成） |
| `questionId` / `questionText` / `progress` | `string` | BIG5質問モード時のみ。`questionText` は質問文のみ（選択肢テキストは含まない） |
| `big5Completed` / `newScores` | - | 100問完了時のみ |
| `emotion` | `string` | BIG5回答中は常に `""`。通常チャットのみ感情値を返す |

**処理の振り分けロジック（優先順）:**

1. **無意味な入力検出** → フォールバック返答を返す（3文字未満・記号のみ・繰り返し文字等）
2. **予定照会** (`今日/明日の予定`) → `users/{uid}/schedules` を照会して返答
3. **BIG5診断トリガー** (`性格診断して` / `性格解析して`) → 次の質問を `questionText` フィールドで返し `big5Progress` を更新
4. **BIG5回答** (1-5の数字 かつ `currentQuestion` が存在) → 回答を記録し段階完了処理、次の質問を返す（OpenAI呼び出しなし）
5. **通常チャット** → OpenAI でキャラクター返答を生成し `posts` コレクションに保存

> **Flutter側の振り分け（Cloud Function呼び出し前）:**
> - アプリ操作ワード（予定・タスク・メモ等）を含む「使い方」系の質問 → `answerAppQuestion` へ
> - メモ/タスク/スケジュールキーワードを含む → ローカル抽出してFirestoreに保存
> - それ以外 → `generateCharacterReply` の通常チャット（5）へ

**モデル選択:**
- Premium ユーザー: `gpt-4o-2024-11-20`
- Free ユーザー: `gpt-4o-mini`

**副作用（Firestore書き込み）:**
- `posts/{docId}` へチャット履歴を保存（通常チャット時のみ）
- `big5Progress/current` を更新（BIG5回答・トリガー時）
- `details/current` の `confirmedBig5Scores`, `analysis_level`, `sixPersonalities` を更新（100問完了時）
- `PersonalityStatsMetadata` を更新（100問完了時・バックグラウンド）

#### 2. `answerAppQuestion`
- **ソース**: `const/answerAppQuestion.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: アプリの使い方に関する質問、またはユーザー自身のデータ（予定・タスク・メモ）に関する質問に回答する
- **リソース**: memory `256MiB` / timeout `60秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **その他**: `minInstances: 0`, `enforceAppCheck: false`

**入力パラメータ:**

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `userId` | `string` | Firebase Auth UID |
| `userMessage` | `string` | ユーザーのメッセージ |
| `dataTypes` | `array<string>` | Firestoreから取得するデータ種別（`"schedules"` / `"todos"` / `"memos"`） |

**返却値:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `reply` | `string` | 回答テキスト（100文字以内） |

**処理内容:**
1. `dataTypes` に指定されたコレクションから必要なデータを Firestore より取得
   - `schedules`: 前後30日の予定（最大20件）
   - `todos`: 未完了タスク（最大20件）
   - `memos`: 最新メモ（最大10件）
2. アプリガイド + 取得データをシステムプロンプトに組み込んで `gpt-4o-mini` で回答生成
3. Firestore への書き込みは行わない（読み取り専用）

**モデル:** `gpt-4o-mini`（固定。質問応答はプレミアム/フリー問わず同一モデル）

---

#### 3. `extractSchedule`
- **ソース**: `const/extractSchedule.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: ユーザーメッセージから予定情報を OpenAI で抽出（**複数件対応**。2026-04-04 変更）
- **リソース**: memory `512MiB` / timeout `120秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **その他**: `minInstances: 0`, `enforceAppCheck: false`
- **モデル**: `gpt-4o-2024-11-20` / temperature `0`（確定的出力）
- **返却形式**: `{ schedules: ScheduleData[] }`（空配列 = 予定なし）
  ```json
  {
    "schedules": [
      { "title": "FA定例", "isAllDay": false, "startDate": Timestamp, "endDate": Timestamp,
        "location": "小会議①(窓有り)", "tag": "", "memo": "", "repeatOption": "none",
        "remindValue": 0, "remindUnit": "none" },
      { "title": "各社定例", ... }
    ]
  }
  ```

#### 4. `generateVoice`
- **ソース**: `const/generateVoice.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: テキストを Google Cloud TTS で音声化し Storage に保存
- **リソース**: memory `512MiB` / timeout `180秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし
- **その他**: `minInstances: 0`

#### 5. `generateBig5Analysis` (エクスポート名: `generateBig5AnalysisCallable`)
- **ソース**: `const/generateBig5Analysis.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: BIG5 性格診断スコアから解析データを生成・キャッシュ
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **モデル**: `gpt-4o-2024-11-20`（無料・有料ユーザー共通。2026-04-04 変更）
- **temperature**: `1.0`（`response_format: json_object` で JSON 崩れを防止。2026-04-04 変更）
- **キャッシュ**: `personalityKey`（例: `O3_C4_E2_A5_N1_male`）で Firestore にキャッシュ。最大 6,250 通り（5^5 × 性別2）
- **生成レベル**: 3 レベルを並列生成（20問・50問・100問）
  - 20問: career / romance / stress（3カテゴリ、200-300文字）
  - 50問: 上記 + learning / decision（5カテゴリ、300-400文字）
  - 100問: 同上（400-500文字）
- **Big5プロンプト形式**: 数値＋自然言語説明の詳細形式（2026-04-04 変更）
  ```
  - 開放性(Openness): 3/5（新しさと安定のバランスを取る）
  - 誠実性(Conscientiousness): 4/5（計画的でルーティンや目標達成を大切にする）
  ...
  ```

#### 6. `validateAppStoreReceipt`
- **ソース**: `validateReceipt.js`
- **API バージョン**: **v1** (`firebase-functions` — `functions.https.onCall`)
- **概要**: Apple App Store レシート検証 → サブスクリプション更新
- **リソース**: 未指定（v1 デフォルト: memory 256MiB / timeout 60秒）
- **リージョン**: 未指定（v1 デフォルト: us-central1）
- **secrets**: なし（`process.env.APPLE_SHARED_SECRET` または `functions.config().apple.shared_secret` を実行時に参照）

#### 7. `validateGooglePlayReceipt`
- **ソース**: `validateReceipt.js`
- **API バージョン**: **v1** (`firebase-functions` — `functions.https.onCall`)
- **概要**: Google Play レシート検証 → サブスクリプション更新
- **リソース**: 未指定（v1 デフォルト）
- **リージョン**: 未指定（v1 デフォルト）
- **secrets**: なし（`process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY`、`process.env.GOOGLE_PLAY_PACKAGE_NAME` を実行時に参照）

#### 8. `generateOrReuseMeeting`
- **ソース**: `src/functions/generateSixPersonMeeting.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: 6人会議の AI 会話を生成（キャッシュ再利用あり）
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **利用制限**: 無料ユーザー生涯1回 / プレミアムユーザー月30回（`usage_tracking` で管理）
- **モデル**: 会議生成 `gpt-4o-2024-11-20`、カテゴリ判定 `gpt-4o-mini`
- **キャッシュ**: `personalityKey` のみでマッチング（カテゴリ非依存）、閲覧済み除外

---

### Scheduled Tasks (`onSchedule`) - 5 関数

Cloud Scheduler による定期実行バッチ。

#### 9. `scheduledHolidays`
- **ソース**: `src/functions/scheduledTasks.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 当年＋翌年の日本の祝日を Firestore に登録
- **スケジュール**: `0 1 1 1 *` (毎年1月1日 01:00 JST)
- **リソース**: memory `512MiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

#### 10. `scheduledDiaryGeneration`
- **ソース**: `src/functions/scheduledTasks.js` → `const/generateDiary.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 全ユーザーの当日アクティビティを集約し、アクティビティ型日記を自動生成（並列5件ずつ）
- **スケジュール**: `50 23 * * *` (毎日 23:50 JST)
- **リソース**: memory `1GiB` / timeout `540秒`
- **リージョン**: `asia-northeast1`
- **secrets**: `OPENAI_API_KEY`
- **収集データ**: 当日スケジュール / 翌日スケジュール（明日への言及用、上位3件）/ チャット / 完了Todo / 作成Todo / メモ / 性格診断セッション / 6人会議
- **キャラクター個性活用**: `details/current` から `favorite_word`(口癖) / `word_tendency`(話し方) / `dream`(夢) / `strength`(強み) を取得してプロンプトに反映
- **BIG5スコア形式**: 数値のまま渡すのではなく `buildPersonalityTraits()` で自然言語テキストに変換してプロンプトに渡す
- **出力形式**: `diary_type: "activity"`, `facts: string[]`, `ai_comment: string`（250〜350文字）を Firestore に保存
- **モデル選択**: premium ユーザー → `gpt-4o-2024-11-20` / free ユーザー → `gpt-4o-mini`（`response_format: json_object` 指定）

#### 11. `generateMonthlyReview`
- **ソース**: `src/functions/generateMonthlyReview.js`
- **API バージョン**: v2 (`firebase-functions/v2/scheduler`)
- **概要**: 前月のスケジュールからキャラ別月次レビューを生成
- **スケジュール**: `0 9 1 * *` (毎月1日 09:00 JST)
- **リソース**: memory `1GiB` / timeout `540秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

#### 12. `checkSubscriptionStatus`
- **ソース**: `validateReceipt.js`
- **API バージョン**: **v1** (`firebase-functions` — `functions.scheduler.onSchedule`)
- **概要**: 期限切れサブスクリプションを検出し free に更新
- **スケジュール**: `0 0 * * *` (毎日 00:00 JST)
- **リソース**: 未指定（v1 デフォルト）
- **リージョン**: 未指定（v1 デフォルト）
- **secrets**: なし

#### 13. `backfillSixPersonalities`
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

#### 14. `sendRegistrationEmail`
- **ソース**: `src/functions/sendRegistrationEmail.js`
- **API バージョン**: v2 (`firebase-functions/v2/firestore`)
- **トリガーパス**: `users/{userId}`
- **概要**: 新規ユーザー作成時に Welcome メールを送信
- **リソース**: 未指定（v2 デフォルト）
- **リージョン**: 未指定（v2 デフォルト）
- **secrets**: `GMAIL_USER`, `GMAIL_APP_PASSWORD`（オブジェクト参照）

#### 15. `sendContactEmail`
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

#### 16. `generateMonthlyReviewHttp`
- **ソース**: `src/functions/generateMonthlyReview.js`
- **API バージョン**: v2 (`firebase-functions/v2/https`)
- **概要**: 月次レビューのテスト・手動実行用 HTTP エンドポイント
- **リソース**: memory `1GiB` / timeout `300秒`
- **リージョン**: `asia-northeast1`
- **secrets**: なし

#### 17. `health`
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
    │                                 # Big5フォーマット関数: buildPersonalityTraits（自然言語形式。diary・characterReply で使用）/ formatBig5ShortWithTraits（コンパクト形式）
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

*最終更新: 2026-04-12*
