# API仕様（Cloud Functions）

> **最終更新**: 2026-07-20

---

## 🔧 実際のファイル構成

```
shared/functions/
├── src/functions/generateSixPersonMeeting.js  ← メイン関数・全ロジック
├── src/utils/sixPersonMeeting.js              ← 6人性格生成ユーティリティ
└── src/prompts/sixPersonMeetingTemplates.js   ← 会議プロンプトテンプレート
```

---

## 📡 1. generateOrReuseMeeting（メイン関数）

会議はリクエストごとに、そのユーザーの悩み（concern）に沿って毎回新規にAI生成される。

### エンドポイント

```javascript
exports.generateOrReuseMeeting = onCall(
  {
    region: "asia-northeast1",
    memory: "1GiB",
    timeoutSeconds: 300,
    enforceAppCheck: true,
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
  meetingId: string,    // 生成した shared_meetings のID
  conversation: Conversation,
  statsData: StatsData,
  cacheHit: boolean,    // 常に false（毎回新規生成のため）
  usageCount: number,   // 生成した会議の利用回数（保存時は 1）
  duration: number,     // 処理時間(ms)
}
```

### 処理フロー

```
1. 認証チェック (request.auth / uid 一致確認)
2. プレミアムステータス確認（subscription/current ドキュメント）
3. 利用制限チェック
   - 無料ユーザー: meeting_history の件数 >= 1 → エラー（生涯1回）
   - プレミアムユーザー: 無制限
4. キャラクターデータ取得（details/current: big5, gender, personalityKey, sixPersonalities）
5. カテゴリ判定（concernCategory が未指定の場合 gpt-4o-mini で AI判定）
6. 会議を新規生成（gpt-4o-2024-11-20）
   - 統計データ計算（PersonalityStatsMetadata から決定論的に算出）
   - 悩み（concern）とカテゴリをプロンプトに含めて会話生成
7. shared_meetings に生成結果を保存（.add）
8. meeting_history にユーザー別履歴を保存
9. プレミアムユーザーの月間カウントをインクリメント
10. レスポンス返却（cacheHit: false）
```

**設計方針:**
- 会議は毎回その悩みに沿って新規生成される。過去に生成した共有会議の読み出し・再利用は行わない。
- `cacheHit` は常に `false` を返す（レスポンス互換のために残しているフィールド）。

---

## 🤖 2. detectConcernCategoryWithAI（カテゴリ自動判定）

`concernCategory` が未指定の場合のみ呼ばれる。

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
    temperature: 0,
  });
  const result = completion.choices[0].message.content.trim().toLowerCase();
  return VALID_CATEGORIES.includes(result) ? result : "other";
}
```

**特徴:**
- temperature=0 で安定した判定
- カテゴリIDのみを出力させることで出力トークンを最小化
- エラー時は "other" にフォールバック
- カテゴリは生成プロンプトのカテゴリ別結論指示に使われ、shared_meetings にも記録される

---

## 💬 3. 会議生成（AI 100%生成）

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
      response_format: { type: "json_object" },  // JSON強制
    },
  );

  const content = completion.choices[0].message.content.trim();
  return JSON.parse(content);
}
```

**特徴:**
- ユーザーの悩み（concern）をプロンプトに直接埋め込み、毎回その悩みに沿った会話を生成する
- `response_format: { type: "json_object" }` でJSON出力を強制（AI がテキストで返すバグ防止）
- systemプロンプトでJSON専用アシスタントとして定義
- マークダウン記法（```json）除去ロジックも実装済み

---

## 🗄️ 4. shared_meetings への保存

生成した会議は `shared_meetings` コレクションに保存される。保存は履歴・分析・評価のために残っているが、後続リクエストでの再利用（読み出し）は行われない。

```javascript
const sharedMeetingRef = await db.collection("shared_meetings").add({
  personalityKey,
  concernCategory: category,
  conversation,
  statsData,
  usageCount: 1,
  ratings: { avgRating: 0, totalRatings: 0, ratingSum: 0 },
  createdAt: new Date(),
  lastUsedAt: new Date(),
});
```

**重要な設計:**
- 会議はリクエストごとに新規生成し、そのまま新しいドキュメントとして保存する
- 既存ドキュメントの検索・再利用は行わない
- `usageCount` は保存時に 1 で固定（インクリメントされない）

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

### プレミアムユーザー（無制限）

```javascript
// users/{userId}.usage_tracking で月間カウントを記録（制限ではなく記録用）
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

各リクエストで以下の書き込みが行われる。

```
shared_meetings/{id}（add）
├── personalityKey: "O3_C3_E3_A4_N3_男性"
├── concernCategory: "career"
├── conversation: { rounds, conclusion }
├── statsData: { similarCount, totalUsers, ... }
├── usageCount: 1
├── ratings: { avgRating: 0, totalRatings: 0, ratingSum: 0 }
├── createdAt: Timestamp
└── lastUsedAt: Timestamp

users/{userId}/characters/{characterId}/meeting_history/{id}（add）
├── sharedMeetingId: "..."（上で生成したドキュメントID）
├── userConcern: "転職どうしよう"
├── concernCategory: "career"
├── userBIG5: { openness: 3, ... }
├── cacheHit: false
└── createdAt: Timestamp
```

---

## 📈 7. 生成状況の測定

Cloud Functions ログから確認可能:

```javascript
logger.info("Meeting generation completed", {
  duration,
  cacheHit,       // 常に false
  sharedMeetingId,
});
```

---

## 📝 まとめ

### 実装済み機能

```
✅ 毎回その悩み（concern）に沿って新規AI生成
✅ gpt-4o-2024-11-20 で会議生成
✅ gpt-4o-mini でカテゴリ自動判定
✅ response_format: json_object でJSON強制出力
✅ 生成結果は shared_meetings に保存（履歴・分析用、再利用はしない）
✅ meeting_history にユーザー別履歴を保存
✅ 無料ユーザー: 生涯1回制限
✅ プレミアムユーザー: 無制限
✅ 毎日3時のバックフィルスケジューラ（sixPersonalities補完）
```
