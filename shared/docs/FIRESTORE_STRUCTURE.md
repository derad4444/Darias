# Firestore Database Structure

このドキュメントは、Characterアプリで使用されているFirestoreデータベースの完全なコレクション構造を示しています。

**生成日**: 2026-01-10
**総ユーザー数**: 16
**トップレベルコレクション数**: 6

---

## 📊 トップレベルコレクション

### 1. `Big5Analysis` - BIG5性格解析データ

**用途**: BIG5性格診断の解析結果を保存（共有・キャッシュ用）

**ドキュメントID形式**: `O{openness}_C{conscientiousness}_E{extraversion}_A{agreeableness}_N{neuroticism}_{gender}`
**例**: `O3_C2_E1_A2_N5_男性`

**フィールド構造**:
```
├─ personality_key: string
├─ gender: string
├─ last_updated: timestamp
├─ big5_scores: map
│  ├─ openness: number (1-5)
│  ├─ conscientiousness: number (1-5)
│  ├─ extraversion: number (1-5)
│  ├─ agreeableness: number (1-5)
│  └─ neuroticism: number (1-5)
├─ analysis_20: map (20問完了時の基本分析)
│  ├─ career: map { personality_type, key_points[3], detailed_text }
│  ├─ romance: map { personality_type, key_points[3], detailed_text }
│  └─ stress: map { personality_type, key_points[3], detailed_text }
├─ analysis_50: map (50問完了時の詳細分析)
│  ├─ career: map
│  ├─ romance: map
│  ├─ stress: map
│  ├─ learning: map
│  └─ decision: map
└─ analysis_100: map (100問完了時の総合分析)
   ├─ career: map
   ├─ romance: map
   ├─ stress: map
   ├─ learning: map
   └─ decision: map
```

**アクセス権限**: 認証済みユーザーは読み取り可、書き込みは不可（Cloud Functionのみ）

---

### 2. `PersonalityStatsMetadata` - 性格統計メタデータ

**用途**: 性格タイプの統計情報を集計

**ドキュメントID**: `summary`（固定）

**フィールド構造**:
```
├─ total_completed_users: number
├─ unique_personality_types: number
├─ gender_distribution: map
│  └─ male: number
└─ personality_counts: map
   ├─ O3_C3_E3_A3_N3_男性: number
   ├─ O3_C3_E3_A3_N3_女性: number
   └─ ... (各性格タイプごとのカウント)
```

**アクセス権限**: 全ユーザー読み取り可、書き込みは不可

---

### 3. `ad_analytics` - 広告分析データ

**用途**: 広告表示・クリックのトラッキング

**フィールド構造**:
```
├─ timestamp: timestamp
├─ type: string (例: "interstitial_shown", "rewarded_earned")
├─ screen: string (広告表示場所)
└─ user_tier: string (例: "free", "premium")
```

**アクセス権限**: 認証済みユーザーは作成可、読み取り・更新・削除は不可

---

### 4. `contacts` - お問い合わせデータ

**用途**: ユーザーからのお問い合わせを保存

**ドキュメントID**: UUID（クライアント生成）

**フィールド構造**:
```
├─ userId: string
├─ userName: string
├─ userEmail: string
├─ category: string
├─ categoryDisplay: string
├─ subject: string
├─ message: string
├─ deviceInfo: map
│  ├─ appVersion: string
│  ├─ deviceModel: string
│  ├─ deviceName: string
│  └─ iosVersion: string
├─ createdAt: timestamp
├─ status: string
├─ userEmailSent: boolean
├─ adminEmailSent: boolean
├─ userEmailId: string
├─ adminEmailId: string
└─ emailSentAt: timestamp
```

**アクセス権限**: 認証済みユーザーは作成可、読み取り・更新・削除は不可（Cloud Functionとコンソールのみ）

---

### 5. `holidays` - 祝日データ

**用途**: 日本の祝日情報を保存

**ドキュメントID**: `YYYY-MM-DD`形式

**フィールド構造**:
```
├─ id: string
├─ name: string (祝日名)
└─ dateString: string (YYYY-MM-DD)
```

**アクセス権限**: 全ユーザー読み取り可、書き込みは不可（管理者のみ）

---

### 6. `shared_meetings` - 共有会議データ

**用途**: 6人会議の共有・再利用データ

**フィールド構造**:
```
├─ personalityKey: string
├─ concernCategory: string
├─ createdAt: timestamp
├─ lastUsedAt: timestamp
├─ usageCount: number
├─ conversation: map
│  ├─ rounds: array[3] of map
│  └─ conclusion: map
│     ├─ summary: string
│     ├─ recommendations: array[3]
│     └─ nextSteps: array[3]
├─ ratings: map
│  ├─ totalRatings: number
│  ├─ ratingSum: number
│  └─ avgRating: number
└─ statsData: map
   ├─ personalityKey: string
   ├─ similarCount: number
   ├─ totalUsers: number
   ├─ percentile: number
   └─ avgAge: number
```

**アクセス権限**: 認証済みユーザーは読み取り可、書き込みは不可（Cloud Functionのみ）

---

## 👥 `users` コレクション

**用途**: ユーザー情報とサブコレクション

**ドキュメントID**: Firebase Auth UID

**フィールド構造**:
```
├─ name: string
├─ email: string
├─ character_id: string
├─ created_at: timestamp
├─ updated_at: timestamp
├─ emailSent: boolean
├─ emailMessageId: string
├─ emailSentAt: timestamp
└─ usage_tracking: map
   ├─ chat_count_today: number
   └─ last_chat_date: string
```

**アクセス権限**: ユーザー自身のデータのみ読み書き可

---

### サブコレクション: `users/{userId}/characters`

**用途**: ユーザーのキャラクター情報

**ドキュメントID**: キャラクターID

**想定フィールド構造** (firestore.rulesとコードから推測):
```
<現時点では実データなし>
```

**アクセス権限**: ユーザー自身のみアクセス可

#### サブコレクション: `users/{userId}/characters/{characterId}/details`

**ドキュメントID**: `current` (固定)

**想定フィールド構造**:
```
├─ gender: string
├─ dream: string (optional)
├─ personalityKey: string
├─ confirmedBig5Scores: map
│  ├─ openness: number
│  ├─ conscientiousness: number
│  ├─ extraversion: number
│  ├─ agreeableness: number
│  └─ neuroticism: number
├─ sixPersonalities: array (6人会議用の事前計算された性格データ)
├─ analysis_level: number (0, 20, 50, 100)
├─ points: number
├─ created_at: timestamp
└─ updated_at: timestamp
```

#### サブコレクション: `users/{userId}/characters/{characterId}/big5Progress`

**ドキュメントID**: `current` (固定)

**想定フィールド構造**:
```
├─ currentQuestion: map
│  ├─ id: string (例: "E1", "A5")
│  ├─ question: string
│  ├─ trait: string (extraversion, agreeableness, etc.)
│  └─ direction: string ("positive" or "negative")
├─ answeredQuestions: array of map
│  ├─ questionId: string
│  ├─ question: string
│  ├─ trait: string
│  ├─ direction: string
│  ├─ value: number (1-5)
│  └─ answeredAt: timestamp
├─ currentScores: map (暫定スコア)
│  ├─ openness: number
│  ├─ conscientiousness: number
│  ├─ extraversion: number
│  ├─ agreeableness: number
│  └─ neuroticism: number
├─ stage: number (1, 2, or 3)
├─ completed: boolean
├─ completedAt: timestamp (optional)
├─ finalScores: map (optional、完了時のみ)
├─ lastAskedAt: timestamp
└─ updated_at: timestamp
```

**BIG5質問の段階**:
- 段階1: 1-20問（基本分析）各特性4問ずつ
- 段階2: 21-50問（詳細分析）各特性10問ずつ
- 段階3: 51-100問（総合分析）各特性20問ずつ

#### サブコレクション: `users/{userId}/characters/{characterId}/posts`

**用途**: チャット履歴の保存

**想定フィールド構造**:
```
├─ content: string (ユーザーのメッセージ)
├─ analysis_result: string (キャラクターの返答)
└─ timestamp: timestamp
```

#### サブコレクション: `users/{userId}/characters/{characterId}/generationStatus`

**ドキュメントID**: `current` (固定)

**想定フィールド構造**:
```
├─ status: string (例: "processing", "completed", "error")
├─ stage: string (キャラクター生成ステージ)
├─ message: string (optional)
└─ updated_at: timestamp
```

---

### サブコレクション: `users/{userId}/schedules`

**用途**: ユーザーの予定管理

**フィールド構造**:
```
├─ id: string
├─ title: string
├─ startDate: timestamp
├─ endDate: timestamp
├─ isAllDay: boolean
├─ location: string
├─ memo: string
├─ tag: string
├─ repeatOption: string
└─ created_at: timestamp
```

**アクセス権限**: ユーザー自身のみアクセス可

**インデックス**:
- `recurringGroupId` (ASC) + `startDate` (ASC)
- `startDate` (ASC) + `endDate` (ASC)

---

### サブコレクション: `users/{userId}/todos`

**用途**: Todoリスト

**フィールド構造**:
```
├─ title: string
├─ description: string
├─ isCompleted: boolean
├─ priority: string
├─ tag: string
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

**アクセス権限**: ユーザー自身のみアクセス可

**インデックス**:
- `isCompleted` (ASC) + `createdAt` (DESC)

---

### サブコレクション: `users/{userId}/memos`

**用途**: メモ機能

**フィールド構造**:
```
├─ title: string
├─ content: string
├─ isPinned: boolean
├─ tag: string
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

**アクセス権限**: ユーザー自身のみアクセス可

**インデックス**:
- `isPinned` (DESC) + `updatedAt` (DESC)

---

### サブコレクション: `users/{userId}/subscription`

**ドキュメントID**: `current` (固定)

**用途**: サブスクリプション情報

**フィールド構造**:
```
├─ status: string (例: "active", "expired")
├─ plan: string
├─ payment_method: string
├─ auto_renewal: boolean
├─ end_date: timestamp or null
└─ updated_at: timestamp
```

**アクセス権限**: ユーザー自身のみアクセス可

---

## 📝 重要な注意事項

### BIG5診断の均等配分ロジック

1. **質問選択アルゴリズム** (`functions/const/big5Questions.js:748-783`):
   - 各特性（外向性、協調性、誠実性、神経症傾向、開放性）の回答済み数をカウント
   - 最も回答数の少ない特性から優先的に出題
   - 同じ特性内ではランダムに質問を選択

2. **20問完了時の内訳**:
   - 外向性: 4問
   - 協調性: 4問
   - 誠実性: 4問
   - 神経症傾向: 4問
   - 開放性: 4問
   - **合計: 20問（各特性均等）**

3. **50問、100問も同様に均等配分**:
   - 50問: 各特性10問ずつ
   - 100問: 各特性20問ずつ

### データフロー

```
ユーザー回答
    ↓
Cloud Function (generateCharacterReply)
    ↓
big5Progress/current に回答を記録
    ↓
getNextQuestion() で次の質問を取得（均等配分）
    ↓
20問/50問/100問完了時
    ↓
段階的キャラクター詳細生成
    ↓
Big5Analysis コレクションにキャッシュ
```

---

## 🔒 セキュリティルール要約

- **個人データ**: `users/{userId}` 配下は本人のみアクセス可
- **共有データ**: `Big5Analysis`, `shared_meetings`, `holidays`, `system` は読み取り専用
- **分析データ**: Cloud Functionのみが書き込み可
- **お問い合わせ**: 作成のみ可、読み取りは不可

---

## 📊 現在のデータ状況

- **総ユーザー数**: 16
- **charactersデータ**: 現時点では実データなし
- **Big5Analysis**: 8種類の性格タイプのデータあり
- **shared_meetings**: サンプルデータあり

---

## 🛠️ 調査に使用したスクリプト

以下のスクリプトがfunctionsディレクトリに作成されています：

1. `listCollections.js` - 基本的なコレクション構造取得
2. `listCollectionsDetailed.js` - 詳細なコレクション構造取得
3. `listCollectionsFull.js` - 完全なコレクション構造取得
4. `findCharactersData.js` - charactersデータを持つユーザーを探索

実行方法:
```bash
cd functions
node listCollectionsFull.js
```

---

**作成日**: 2026-01-10
**作成者**: Claude Code
