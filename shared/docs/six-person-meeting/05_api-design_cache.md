# API設計（Cloud Functions - キャッシュ優先版）

> **最終更新**: 2026-03-13（TypeScript擬似コードから実装済みJSコードに全面更新）

---

## 🔧 実際のファイル構成

```
shared/functions/
├── src/functions/generateSixPersonMeeting.js  ← メイン関数・全ロジック
├── src/utils/sixPersonMeeting.js              ← 6人性格生成ユーティリティ
└── src/prompts/sixPersonMeetingTemplates.js   ← 会議プロンプトテンプレート
```

---

## 📡 1. generateOrReuseMeeting（メイン関数 - キャッシュ優先）

### エンドポイント

```javascript
exports.generateOrReuseMeeting = onCall(
  {
    region: "asia-northeast1",
    memory: "1GiB",
    timeoutSeconds: 300,
  },
  async (request) => { ... }
);
```

### リクエスト

```javascript
// request.data の型
{
  userId: string;         // Firebase Auth UID
  characterId: string;    // キャラクターID
  concern: string;        // ユーザーの悩み
  concernCategory?: string; // 省略時はAIで自動判定
}
```

### レスポンス

```javascript
{
  success: true,
  meetingId: string,    // shared_meetings のID
  conversation: Conversation,
  statsData: StatsData,
  cacheHit: boolean,
  usageCount: number,   // 会議の総利用回数（+1済み）
  duration: number,     // 処理時間(ms)
}
```

### 処理フロー

```
1. 認証チェック (request.auth)
2. プレミアムステータス確認（subscription/current ドキュメント）
3. 利用制限チェック
   - 無料ユーザー: meeting_history の件数 >= 1 → エラー
   - プレミアムユーザー: usage_tracking.meeting_count_this_month >= 30 → エラー
4. キャラクターデータ取得（details/current: big5, gender, personalityKey, sixPersonalities）
5. カテゴリ判定（concernCategory が未指定の場合 gpt-4o-mini で AI判定）
6. 閲覧履歴取得（meeting_history から sharedMeetingId のリスト）
7. キャッシュ検索（personalityKey のみで検索、閲覧済みを除外）
8a. キャッシュヒット → 既存会議データを取得、usageCount をインクリメント
8b. キャッシュミス → AI生成（gpt-4o-2024-11-20）、shared_meetings に保存
9. meeting_history にユーザー別履歴を保存
10. プレミアムユーザーの月間カウントをインクリメント
11. レスポンス返却
```

---

## 🤖 2. detectConcernCategoryWithAI（カテゴリ自動判定）

キャッシュミス時に `concernCategory` が未指定の場合のみ呼ばれる。

```javascript
const VALID_CATEGORIES = [
  "career", "romance", "money", "health",
  "family", "future", "hobby", "study", "moving", "other",
];

async function detectConcernCategoryWithAI(concern, openai) {
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{
      role: "user",
      content: `次の悩みを最も適切なカテゴリ1つに分類してください。\n悩み: "${concern}"\n...`
    }],
    max_tokens: 20,
    temperature: 0,
  });
  const result = completion.choices[0].message.content.trim().toLowerCase();
  return VALID_CATEGORIES.includes(result) ? result : "other";
}
```

**特徴:**
- temperature=0 で安定した判定
- max_tokens=20 でコスト最小化（カテゴリIDのみ出力）
- エラー時は "other" にフォールバック
- カテゴリはキャッシュには影響しない（記録用のみ）

---

## 🗄️ 3. キャッシュ検索ロジック

```javascript
async function searchMeetingCache(personalityKey, excludeIds = []) {
  const cacheQuery = await db
    .collection("shared_meetings")
    .where("personalityKey", "==", personalityKey)
    .orderBy("usageCount", "desc")
    .get();

  // 除外リスト（閲覧済み）に含まれていない最初のドキュメントを返す
  for (const doc of cacheQuery.docs) {
    if (!excludeIds.includes(doc.id)) {
      return { id: doc.id, ...doc.data() };
    }
  }
  return null; // 全部除外済みならnull（新規生成）
}
```

**重要な設計:**
- `personalityKey` **のみ**でキャッシュ検索（カテゴリ非依存）
- 同じ性格タイプなら悩みのカテゴリが異なっても再利用
- 利用回数（`usageCount`）が多い会議を優先
- 閲覧済みIDは除外して毎回新鮮なコンテンツを提供

---

## 💬 4. 会議生成（AI 100%生成）

```javascript
async function generateConversationWithAI(concern, category, personalities, statsData) {
  const openai = getOpenAIClient(apiKey);
  const prompt = createMeetingPrompt(concern, category, personalities, statsData);

  const completion = await safeOpenAICall(
    openai.chat.completions.create.bind(openai.chat.completions),
    {
      model: "gpt-4o-2024-11-20",
      messages: [
        {
          role: "system",
          content: "You are a JSON generator. Always respond with valid JSON only, no explanations or markdown."
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.8,
      max_tokens: 3000,
      response_format: { type: "json_object" },  // JSON強制
    },
  );

  const content = completion.choices[0].message.content.trim();
  return JSON.parse(content);
}
```

**特徴:**
- `response_format: { type: "json_object" }` でJSON出力を強制（AI がテキストで返すバグ防止）
- systemプロンプトでJSON専用アシスタントとして定義
- マークダウン記法（```json）除去ロジックも実装済み

---

## 🔒 5. 利用制限

### 無料ユーザー（生涯1回）

```javascript
// meeting_history の件数で判定
const usageCount = await getMeetingUsageCount(userId, characterId);
if (usageCount >= 1) {
  throw new HttpsError("resource-exhausted", "無料ユーザーは1回のみ...");
}
```

### プレミアムユーザー（月30回）

```javascript
// users/{userId}.usage_tracking で月間カウント管理
async function checkMonthlyMeetingCount(userId) {
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const userDoc = await db.collection("users").doc(userId).get();
  const usageTracking = userDoc.data()?.usage_tracking || {};
  const lastMonth = usageTracking.last_meeting_month || "";
  // 月が変わったらカウントリセット
  const count = lastMonth === currentMonth ? (usageTracking.meeting_count_this_month || 0) : 0;
  return { count, currentMonth };
}

// 利用後にインクリメント
async function incrementMonthlyMeetingCount(userId) {
  const { count, currentMonth } = await checkMonthlyMeetingCount(userId);
  await db.collection("users").doc(userId).update({
    "usage_tracking.meeting_count_this_month": count + 1,
    "usage_tracking.last_meeting_month": currentMonth,
  });
}
```

---

## 📊 6. Firestore 書き込みパターン

### キャッシュミス時（新規生成）

```
shared_meetings/{id}
├── personalityKey: "O3_C3_E3_A4_N3_男性"
├── concernCategory: "career"  // 記録用（キャッシュマッチには使わない）
├── conversation: { rounds, conclusion }
├── statsData: { similarCount, totalUsers, ... }
├── usageCount: 1
├── ratings: { avgRating: 0, totalRatings: 0, ratingSum: 0 }
├── createdAt: Timestamp
└── lastUsedAt: Timestamp

users/{userId}/characters/{characterId}/meeting_history/{id}
├── sharedMeetingId: "..."
├── userConcern: "転職どうしよう"
├── concernCategory: "career"
├── userBIG5: { openness: 3, ... }
├── cacheHit: false
└── createdAt: Timestamp
```

### キャッシュヒット時

```
shared_meetings/{id}（update）
├── usageCount: +1
└── lastUsedAt: Timestamp（更新）

users/{userId}/characters/{characterId}/meeting_history/{id}（add）
└── （上記と同じ、cacheHit: true）
```

---

## 📈 7. キャッシュ効果の測定

Cloud Functions ログから確認可能:

```javascript
logger.info("Meeting generation completed", {
  duration,
  cacheHit,       // true/false
  sharedMeetingId,
});
```

---

## 📝 まとめ

### キャッシュ優先ロジックの利点

```
✅ 1. コスト削減: キャッシュヒットで1.63円→0円
✅ 2. 高速化: AI生成(30-60秒) → キャッシュ返却(数秒)
✅ 3. カテゴリ非依存: 同性格タイプなら悩みに関わらず再利用
✅ 4. 閲覧除外: 同じユーザーに同じ会議を見せない
✅ 5. 品質管理: ratings で評価を追跡
```

### 実装済み機能

```
✅ personalityKey のみでキャッシュ（カテゴリ非依存）
✅ 閲覧済み会議の除外（meeting_history で管理）
✅ gpt-4o-2024-11-20 で会議生成
✅ gpt-4o-mini でカテゴリ自動判定
✅ response_format: json_object でJSON強制出力
✅ 無料ユーザー: 生涯1回制限
✅ プレミアムユーザー: 月30回制限（usage_tracking で管理）
✅ 毎日3時のバックフィルスケジューラ（sixPersonalities補完）
```
