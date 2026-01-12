# Firestore Database Schema (完全版)

> このドキュメントはFirestoreデータベースの完全なコレクション構造とフィールド定義を示しています。
> 現在データが存在しないコレクションについては、コードから推測したスキーマを含みます。

**生成日時**: 2026-01-10
**総ユーザー数**: 16
**トップレベルコレクション**: 6

---

## 目次

1. [Big5Analysis](#big5analysis) - BIG5性格解析データ
2. [PersonalityStatsMetadata](#personalitystatsmetadata) - 性格統計メタデータ
3. [ad_analytics](#ad_analytics) - 広告分析データ
4. [contacts](#contacts) - お問い合わせデータ
5. [holidays](#holidays) - 祝日データ
6. [shared_meetings](#shared_meetings) - 共有会議データ
7. [users](#users) - ユーザーデータ

---

## `Big5Analysis`

**用途**: BIG5性格診断の解析結果を保存（共有・キャッシュ用）
**ドキュメントID**: `O{openness}_C{conscientiousness}_E{extraversion}_A{agreeableness}_N{neuroticism}_{gender}`

**フィールド:**

- **personality_key**: `string` - 性格タイプのキー
- **gender**: `string` - 性別（"男性", "女性", "neutral"）
- **last_updated**: `timestamp` - 最終更新日時
- **big5_scores**: `map` - BIG5スコア
  - **openness**: `number` (1-5) - 開放性
  - **conscientiousness**: `number` (1-5) - 誠実性
  - **extraversion**: `number` (1-5) - 外向性
  - **agreeableness**: `number` (1-5) - 協調性
  - **neuroticism**: `number` (1-5) - 神経症傾向
- **analysis_20**: `map` - 20問完了時の基本分析
  - **career**: `map` - キャリア分析
    - **personality_type**: `string` - 性格タイプ名
    - **key_points**: `array<string>` - 要点（3項目）
    - **detailed_text**: `string` - 詳細テキスト
  - **romance**: `map` - 恋愛分析
    - **personality_type**: `string`
    - **key_points**: `array<string>`
    - **detailed_text**: `string`
  - **stress**: `map` - ストレス分析
    - **personality_type**: `string`
    - **key_points**: `array<string>`
    - **detailed_text**: `string`
- **analysis_50**: `map` - 50問完了時の詳細分析
  - **career**: `map` - キャリア分析
  - **romance**: `map` - 恋愛分析
  - **stress**: `map` - ストレス分析
  - **learning**: `map` - 学習分析
  - **decision**: `map` - 意思決定分析
- **analysis_100**: `map` - 100問完了時の総合分析
  - **career**: `map` - キャリア分析
  - **romance**: `map` - 恋愛分析
  - **stress**: `map` - ストレス分析
  - **learning**: `map` - 学習分析
  - **decision**: `map` - 意思決定分析

**アクセス権限**: 認証済みユーザーは読み取り可、書き込みは不可（Cloud Functionのみ）

---

## `PersonalityStatsMetadata`

**用途**: 性格タイプの統計情報を集計
**ドキュメントID**: `summary` (固定)

**フィールド:**

- **total_completed_users**: `number` - 100問完了したユーザー数
- **unique_personality_types**: `number` - ユニークな性格タイプ数
- **gender_distribution**: `map` - 性別分布
  - **male**: `number` - 男性ユーザー数
  - **female**: `number` - 女性ユーザー数（推測）
- **personality_counts**: `map` - 各性格タイプの人数
  - **{personalityKey}**: `number` - 各性格タイプのユーザー数

**アクセス権限**: 全ユーザー読み取り可、書き込みは不可

---

## `ad_analytics`

**用途**: 広告表示・クリックのトラッキング

**フィールド:**

- **timestamp**: `timestamp` - イベント発生日時
- **type**: `string` - イベントタイプ（例: "banner_impression", "interstitial_shown"）
- **screen**: `string` - 広告表示場所（例: "home", "settings"）
- **user_tier**: `string` - ユーザー階層（"free", "premium"）

**アクセス権限**: 認証済みユーザーは作成可、読み取り・更新・削除は不可

---

## `contacts`

**用途**: ユーザーからのお問い合わせを保存
**ドキュメントID**: UUID（クライアント生成）

**フィールド:**

- **userId**: `string` - ユーザーID
- **userName**: `string` - ユーザー名
- **userEmail**: `string` - ユーザーメールアドレス
- **category**: `string` - カテゴリ（"bug", "feature", "other"など）
- **categoryDisplay**: `string` - カテゴリ表示名
- **subject**: `string` - 件名
- **message**: `string` - メッセージ本文
- **deviceInfo**: `map` - デバイス情報
  - **appVersion**: `string` - アプリバージョン
  - **deviceModel**: `string` - デバイスモデル
  - **deviceName**: `string` - デバイス名
  - **iosVersion**: `string` - iOSバージョン
- **createdAt**: `timestamp` - 作成日時
- **status**: `string` - ステータス（"sent", "processing", "resolved"など）
- **userEmailSent**: `boolean` - ユーザーへの確認メール送信済みフラグ
- **adminEmailSent**: `boolean` - 管理者への通知メール送信済みフラグ
- **userEmailId**: `string` - ユーザー宛メールID
- **adminEmailId**: `string` - 管理者宛メールID
- **emailSentAt**: `timestamp` - メール送信日時

**アクセス権限**: 認証済みユーザーは作成可、読み取り・更新・削除は不可

---

## `holidays`

**用途**: 日本の祝日情報を保存
**ドキュメントID**: `YYYY-MM-DD` 形式

**フィールド:**

- **id**: `string` - 祝日ID（YYYY-MM-DD）
- **name**: `string` - 祝日名（例: "元日", "成人の日"）
- **dateString**: `string` - 日付文字列（YYYY-MM-DD）

**アクセス権限**: 全ユーザー読み取り可、書き込みは不可（管理者のみ）

---

## `shared_meetings`

**用途**: 6人会議の共有・再利用データ

**フィールド:**

- **personalityKey**: `string` - 性格タイプキー
- **concernCategory**: `string` - 悩みカテゴリ
- **createdAt**: `timestamp` - 作成日時
- **lastUsedAt**: `timestamp` - 最終利用日時
- **usageCount**: `number` - 利用回数
- **conversation**: `map` - 会議の会話内容
  - **rounds**: `array<map>` - ラウンドごとの会話
    - **roundNumber**: `number` - ラウンド番号
    - **messages**: `array<map>` - メッセージリスト
      - **characterId**: `string` - キャラクターID
      - **characterName**: `string` - キャラクター名
      - **text**: `string` - メッセージテキスト
      - **timestamp**: `string` - タイムスタンプ
  - **conclusion**: `map` - 結論
    - **summary**: `string` - サマリー
    - **recommendations**: `array<string>` - 推奨事項（3項目）
    - **nextSteps**: `array<string>` - 次のステップ（3項目）
- **ratings**: `map` - 評価情報
  - **totalRatings**: `number` - 評価総数
  - **ratingSum**: `number` - 評価合計値
  - **avgRating**: `number` - 平均評価
- **statsData**: `map` - 統計データ
  - **personalityKey**: `string` - 性格タイプキー
  - **similarCount**: `number` - 類似ユーザー数
  - **totalUsers**: `number` - 総ユーザー数
  - **percentile**: `number` - パーセンタイル
  - **avgAge**: `number` - 平均年齢

**アクセス権限**: 認証済みユーザーは読み取り可、書き込みは不可

---

## `users`

**用途**: ユーザー情報とサブコレクション
**ドキュメントID**: Firebase Auth UID

**フィールド:**

- **name**: `string` - ユーザー名
- **email**: `string` - メールアドレス
- **character_id**: `string` - キャラクターID
- **created_at**: `timestamp` - アカウント作成日時
- **updated_at**: `timestamp` - 最終更新日時
- **emailSent**: `boolean` - 登録確認メール送信済みフラグ
- **emailMessageId**: `string` - 送信メールID
- **emailSentAt**: `timestamp` - メール送信日時
- **usage_tracking**: `map` - 利用状況追跡
  - **chat_count_today**: `number` - 今日のチャット回数
  - **last_chat_date**: `string` - 最終チャット日（YYYY-MM-DD）

**アクセス権限**: ユーザー自身のデータのみ読み書き可

---

### `users/{userId}/characters`

**用途**: ユーザーのキャラクター情報
**ドキュメントID**: キャラクターID（UUID）

**フィールド**:

キャラクターメタデータは親ドキュメントではなく、すべてサブコレクションに保存されています。

**サブコレクション:**

#### `users/{userId}/characters/{characterId}/details`

**ドキュメントID**: `current` (固定)

**用途**: キャラクターの詳細情報と性格分析結果

**フィールド:**

- **created_at**: `timestamp` - 作成日時
- **updated_at**: `timestamp` - 更新日時
- **gender**: `string` - 性別（"male", "female", "neutral"）
- **personalityKey**: `string` - 性格タイプキー（例: "O3_C3_E3_A4_N3_男性"）
- **analysis_level**: `number` - 分析レベル（20, 50, 100）
- **points**: `number` - ポイント数
- **confirmedBig5Scores**: `map` - 確定BIG5スコア
  - **openness**: `number` (1-5) - 開放性
  - **conscientiousness**: `number` (1-5) - 誠実性
  - **extraversion**: `number` (1-5) - 外向性
  - **agreeableness**: `number` (1-5) - 協調性
  - **neuroticism**: `number` (1-5) - 神経症傾向
- **strength**: `string` - 性格の強み
- **weakness**: `string` - 性格の弱み
- **aptitude**: `string` - 適性
- **hobby**: `string` - 趣味
- **skill**: `string` - スキル
- **dream**: `string` - 夢・目標
- **favorite_place**: `string` - お気に入りの場所
- **favorite_color**: `string` - 好きな色
- **favorite_word**: `string` - 好きな言葉
- **favorite_entertainment_genre**: `string` - 好きなエンターテイメントジャンル
- **word_tendency**: `string` - 言葉の傾向
- **sixPersonalities**: `map` - 6人会議用の事前計算された性格データ（optional）
  - 構造は性格タイプにより異なる

#### `users/{userId}/characters/{characterId}/big5Progress`

**ドキュメントID**: `current` (固定)

**用途**: BIG5性格診断の進捗状況を追跡

**フィールド:**

- **currentQuestion**: `null` | `map` - 現在の質問（完了時はnull）
  - **id**: `string` - 質問ID（例: "E1", "A5"）
  - **question**: `string` - 質問文
  - **trait**: `string` - 特性（extraversion, agreeableness, conscientiousness, neuroticism, openness）
  - **direction**: `string` - 方向性（"positive", "negative"）
- **answeredQuestions**: `array<map>` - 回答済み質問リスト（最大100問）
  - **questionId**: `string` - 質問ID
  - **question**: `string` - 質問文
  - **trait**: `string` - 特性（extraversion, agreeableness, conscientiousness, neuroticism, openness）
  - **direction**: `string` - 方向性（"positive", "negative"）
  - **value**: `number` - 回答値（1-5）
  - **answeredAt**: `timestamp` - 回答日時
- **completed**: `boolean` - 完了フラグ（100問完了時にtrue）
- **completedAt**: `timestamp` - 完了日時（完了時のみ）
- **finalScores**: `map` - 最終BIG5スコア（完了時のみ）
  - **openness**: `number` (1-5) - 開放性
  - **conscientiousness**: `number` (1-5) - 誠実性
  - **extraversion**: `number` (1-5) - 外向性
  - **agreeableness**: `number` (1-5) - 協調性
  - **neuroticism**: `number` (1-5) - 神経症傾向
- **lastAskedAt**: `timestamp` - 最終質問日時

**BIG5質問の段階:**
- 段階1: 1-20問（基本分析）各特性4問ずつ
- 段階2: 21-50問（詳細分析）各特性10問ずつ
- 段階3: 51-100問（総合分析）各特性20問ずつ

#### `users/{userId}/characters/{characterId}/posts`

**用途**: チャット履歴の保存
**ドキュメントID**: 自動生成

**フィールド:**

- **content**: `string` - ユーザーのメッセージ
- **analysis_result**: `string` - キャラクターの返答（AI生成）
- **timestamp**: `timestamp` - 投稿日時

#### `users/{userId}/characters/{characterId}/generationStatus`

**ドキュメントID**: `current` (固定)

**用途**: キャラクター生成状態の追跡

**フィールド:**

現在実データなし。このサブコレクションは将来の機能のために予約されている可能性があります。

**推測されるフィールド:**

- **status**: `string` - ステータス（"processing", "completed", "error"）
- **stage**: `string` - 生成ステージ
- **message**: `string` - メッセージ（optional）
- **updated_at**: `timestamp` - 更新日時

---

### `users/{userId}/schedules`

**用途**: ユーザーの予定管理

**フィールド:**

- **id**: `string` - 予定ID
- **title**: `string` - タイトル
- **startDate**: `timestamp` - 開始日時
- **endDate**: `timestamp` - 終了日時
- **isAllDay**: `boolean` - 終日フラグ
- **location**: `string` - 場所
- **memo**: `string` - メモ
- **tag**: `string` - タグ
- **repeatOption**: `string` - 繰り返しオプション
- **created_at**: `timestamp` - 作成日時

**インデックス:**
- `recurringGroupId` (ASC) + `startDate` (ASC)
- `startDate` (ASC) + `endDate` (ASC)

---

### `users/{userId}/todos`

**用途**: Todoリスト

**フィールド:**

- **title**: `string` - タイトル
- **description**: `string` - 説明
- **isCompleted**: `boolean` - 完了フラグ
- **priority**: `string` - 優先度（"高", "中", "低"）
- **tag**: `string` - タグ
- **createdAt**: `timestamp` - 作成日時
- **updatedAt**: `timestamp` - 更新日時

**インデックス:**
- `isCompleted` (ASC) + `createdAt` (DESC)

---

### `users/{userId}/memos`

**用途**: メモ機能

**フィールド:**

- **title**: `string` - タイトル
- **content**: `string` - 内容
- **isPinned**: `boolean` - ピン留めフラグ
- **tag**: `string` - タグ
- **createdAt**: `timestamp` - 作成日時
- **updatedAt**: `timestamp` - 更新日時

**インデックス:**
- `isPinned` (DESC) + `updatedAt` (DESC)

---

### `users/{userId}/subscription`

**ドキュメントID**: `current` (固定)

**用途**: サブスクリプション情報

**フィールド:**

- **status**: `string` - ステータス（"active", "expired", "free"）
- **plan**: `string` - プラン名（"free", "premium"）
- **payment_method**: `string` - 支払い方法（"app_store"など）
- **auto_renewal**: `boolean` - 自動更新フラグ
- **end_date**: `timestamp | null` - 終了日
- **updated_at**: `timestamp` - 更新日時

---

## データフロー

```
ユーザー登録
    ↓
users コレクションに作成
    ↓
性格診断開始（「性格診断して」）
    ↓
big5Progress/current に進捗記録
    ↓
20問完了 → Big5Analysis に基本分析を保存
    ↓
50問完了 → Big5Analysis に詳細分析を保存
    ↓
100問完了 → Big5Analysis に総合分析を保存
         → PersonalityStatsMetadata を更新
         → sixPersonalities を事前計算
```

---

## セキュリティルール要約

- **個人データ**: `users/{userId}` 配下は本人のみアクセス可
- **共有データ**: `Big5Analysis`, `shared_meetings`, `holidays` は読み取り専用
- **分析データ**: Cloud Functionのみが書き込み可
- **お問い合わせ**: 作成のみ可、読み取りは不可
- **広告分析**: 作成のみ可、読み取りは不可

---

## 調査に使用したスクリプト

以下のスクリプトが `functions/` ディレクトリに作成されています：

1. `exportSchema.js` - スキーマ構造の出力（推奨）
2. `exportFullStructure.js` - 値も含む完全な構造出力
3. `listCollectionsFull.js` - コレクション一覧取得
4. `findCharactersData.js` - charactersデータ探索

**実行方法:**
```bash
cd functions
node exportSchema.js
```

---

**作成日**: 2026-01-10
**作成者**: Claude Code
