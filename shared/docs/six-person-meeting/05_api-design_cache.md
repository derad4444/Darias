# API設計（Cloud Functions - キャッシュ優先版）

## 🔧 Cloud Functions一覧

```
functions/src/
├── sixPersonMeeting/
│   ├── generateOrReuseMeeting.ts    ← メイン関数（キャッシュ優先）
│   ├── searchCache.ts               ← キャッシュ検索
│   ├── searchDatabase.ts            ← 類似性格検索
│   ├── calculateStats.ts            ← 統計計算
│   ├── generateConversation.ts      ← 会話生成
│   └── templates/
│       ├── careerChange.ts          ← カテゴリ別テンプレート
│       ├── romance.ts
│       └── ...
```

---

## 📡 1. generateOrReuseMeeting（メイン関数 - キャッシュ優先）

### エンドポイント
```typescript
exports.generateOrReuseMeeting = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    // キャッシュを最初に検索、ヒットしなければ新規生成
  });
```

### リクエスト
```typescript
interface GenerateMeetingRequest {
  userId: string;
  characterId: string;
  concern: string;
  concernCategory: string;  // 'career', 'romance', etc（必須）
}
```

### レスポンス
```typescript
interface GenerateMeetingResponse {
  historyId: string;  // meeting_history のID
  sharedMeetingId: string;  // shared_meetings のID
  cacheHit: boolean;  // キャッシュヒットしたか
  conversation: Conversation;
  statsData: StatsData;
  createdAt: Timestamp;
}
```

### 実装（キャッシュ優先ロジック）

```typescript
import { OpenAI } from 'openai';
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const openai = new OpenAI({
  apiKey: functions.config().openai.key
});

const db = admin.firestore();

export const generateOrReuseMeeting = functions
  .region('asia-northeast1')
  .https.onCall(async (data: GenerateMeetingRequest, context) => {

    // 1. 認証チェック
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'ユーザー認証が必要です'
      );
    }

    const userId = context.auth.uid;

    // 2. プレミアムチェック
    const isPremium = await checkPremiumStatus(userId);
    if (!isPremium) {
      const usageCount = await getMeetingUsageCount(userId, data.characterId);
      if (usageCount >= 1) {
        throw new functions.https.HttpsError(
          'permission-denied',
          '無料プランは1回のみです。プレミアムにアップグレードしてください。'
        );
      }
    }

    // 3. ユーザーのpersonalityKey取得
    const characterDoc = await db
      .collection('users').doc(userId)
      .collection('characters').doc(data.characterId)
      .collection('details').doc('current')
      .get();

    if (!characterDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'キャラクターデータが見つかりません'
      );
    }

    const personalityKey = characterDoc.data()?.personalityKey as string;
    const userBIG5 = characterDoc.data()?.confirmedBig5Scores;

    if (!personalityKey || !userBIG5) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'BIG5診断が完了していません'
      );
    }

    // 4. 【最重要】キャッシュ検索
    console.log(`🔍 Searching cache: ${personalityKey} + ${data.concernCategory}`);

    const cacheQuery = await db.collection('shared_meetings')
      .where('personalityKey', '==', personalityKey)
      .where('concernCategory', '==', data.concernCategory)
      .orderBy('usageCount', 'desc')
      .limit(1)
      .get();

    let sharedMeetingId: string;
    let cacheHit = false;
    let conversation: any;
    let statsData: any;

    if (!cacheQuery.empty) {
      // 5a. ✅ キャッシュヒット！
      const cacheDoc = cacheQuery.docs[0];
      sharedMeetingId = cacheDoc.id;
      cacheHit = true;

      const cacheData = cacheDoc.data();
      conversation = cacheData.conversation;
      statsData = cacheData.statsData;

      // usageCount をインクリメント
      await db.collection('shared_meetings').doc(sharedMeetingId).update({
        usageCount: admin.firestore.FieldValue.increment(1),
        lastUsedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`✅ Cache HIT! (ID: ${sharedMeetingId}, usageCount: ${cacheData.usageCount + 1})`);

    } else {
      // 5b. ❌ キャッシュミス → 新規生成
      console.log('⚠️ Cache MISS. Generating new meeting...');

      // 類似性格検索
      const similarKeys = await findSimilarPersonalityKeys(
        userBIG5,
        extractGender(personalityKey),
        0.85
      );

      console.log(`Found ${similarKeys.length} similar personality keys`);

      // 統計データ算出
      statsData = await calculateStatsFromAnalysis(
        similarKeys,
        data.concernCategory
      );

      // 会話生成（テンプレート or AI）
      conversation = await generateConversation({
        concern: data.concern,
        concernCategory: data.concernCategory,
        userBIG5,
        statsData
      });

      // shared_meetings に保存（キャッシュ化）
      const sharedRef = await db.collection('shared_meetings').add({
        personalityKey,
        concernCategory: data.concernCategory,
        concernSubcategory: extractSubcategory(data.concern),
        concernKeywords: extractKeywords(data.concern),
        conversation,
        statsData,
        usageCount: 1,
        ratings: {
          avgRating: 0.0,
          totalRatings: 0,
          distribution: { '5': 0, '4': 0, '3': 0, '2': 0, '1': 0 }
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUsedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      sharedMeetingId = sharedRef.id;

      console.log(`✅ New meeting created and cached (ID: ${sharedMeetingId})`);
    }

    // 6. ユーザーの履歴に参照を保存
    const historyRef = await db
      .collection('users').doc(userId)
      .collection('characters').doc(data.characterId)
      .collection('meeting_history')
      .add({
        sharedMeetingId,
        userConcern: data.concern,
        userBIG5,
        cacheHit,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

    // 7. 使用回数カウント（オプション）
    await db.collection('users').doc(userId).update({
      'usage_tracking.six_person_meeting_count': admin.firestore.FieldValue.increment(1),
      'usage_tracking.last_meeting_date': new Date().toISOString().split('T')[0]
    });

    return {
      historyId: historyRef.id,
      sharedMeetingId,
      cacheHit,
      conversation,
      statsData,
      createdAt: new Date().toISOString()
    };
  });

// ヘルパー関数
async function checkPremiumStatus(userId: string): Promise<boolean> {
  const userDoc = await db.collection('users').doc(userId).get();
  return userDoc.data()?.subscription?.status === 'premium';
}

async function getMeetingUsageCount(userId: string, characterId: string): Promise<number> {
  const snapshot = await db
    .collection('users').doc(userId)
    .collection('characters').doc(characterId)
    .collection('meeting_history')
    .count()
    .get();
  return snapshot.data().count;
}

function extractGender(personalityKey: string): string {
  // "O4_C4_E2_A4_N3_female" → "female"
  return personalityKey.split('_').pop() || '';
}

function extractSubcategory(concern: string): string {
  // 簡易実装（実際はもっと高度な分類）
  if (concern.includes('転職')) return 'career_change';
  if (concern.includes('結婚')) return 'marriage';
  if (concern.includes('お金')) return 'money';
  return 'general';
}

function extractKeywords(concern: string): string[] {
  // 簡易実装（実際は形態素解析など）
  const keywords = concern.split(/[\s、。！？]+/)
    .filter(word => word.length >= 2)
    .slice(0, 5);
  return keywords;
}
```

---

## 🔍 2. findSimilarPersonalityKeys（類似性格検索）

```typescript
interface Big5Scores {
  openness: number;
  conscientiousness: number;
  extraversion: number;
  agreeableness: number;
  neuroticism: number;
}

async function findSimilarPersonalityKeys(
  userBIG5: Big5Scores,
  userGender: string,
  threshold: number = 0.85
): Promise<string[]> {

  // Big5Analysis コレクション全体をスキャン
  const snapshot = await db.collection('Big5Analysis').get();

  const similarKeys: string[] = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const big5Scores = data.big5_scores;

    if (!big5Scores) continue;

    // 類似度計算
    const similarity = calculateSimilarity(userBIG5, big5Scores);

    if (similarity >= threshold) {
      const key = data.personality_key as string;

      // 性別が一致する場合のみ（オプション）
      if (key.endsWith(`_${userGender}`)) {
        similarKeys.push(key);
      }
    }
  }

  console.log(`Found ${similarKeys.length} similar personalities (threshold: ${threshold})`);

  return similarKeys;
}

function calculateSimilarity(a: Big5Scores, b: Big5Scores): number {
  const diff =
    Math.abs(a.openness - b.openness) +
    Math.abs(a.conscientiousness - b.conscientiousness) +
    Math.abs(a.extraversion - b.extraversion) +
    Math.abs(a.agreeableness - b.agreeableness) +
    Math.abs(a.neuroticism - b.neuroticism);

  return 1.0 - (diff / 25.0);  // 0-1に正規化（5特性 × 5段階 = 最大差分25）
}
```

---

## 📊 3. calculateStatsFromAnalysis（統計計算）

```typescript
interface StatsData {
  sampleSize: number;
  similarityThreshold: number;
  referencedPersonalityKeys: string[];
  results: Record<string, {
    count: number;
    avgSatisfaction: number;
    percentage: number;
  }>;
  successPatterns: Array<{
    pattern: string;
    frequency: number;
  }>;
}

async function calculateStatsFromAnalysis(
  personalityKeys: string[],
  concernCategory: string
): Promise<StatsData> {

  // 各personalityKeyの分析テキストを取得
  const analyses: string[] = [];

  for (const key of personalityKeys) {
    const doc = await db.collection('Big5Analysis').doc(key).get();

    if (doc.exists) {
      const data = doc.data();

      // concernCategory に応じた分析テキストを取得
      let analysisText: string | undefined;
      switch (concernCategory) {
        case 'career':
          analysisText = data?.career_analysis;
          break;
        case 'romance':
          analysisText = data?.romance_analysis;
          break;
        case 'stress':
          analysisText = data?.stress_analysis;
          break;
        case 'learning':
          analysisText = data?.learning_analysis;
          break;
        case 'decision':
          analysisText = data?.decision_analysis;
          break;
      }

      if (analysisText) {
        analyses.push(analysisText);
      }
    }
  }

  // テキスト分析でパターン抽出
  const patterns = extractPatternsFromTexts(analyses, concernCategory);

  // PersonalityStatsMetadata から各パターンの人数を取得
  const metadataDoc = await db
    .collection('PersonalityStatsMetadata')
    .doc('summary')
    .get();

  const personalityCounts = metadataDoc.data()?.personality_counts as Record<string, number> || {};

  const sampleSize = personalityKeys
    .map(key => personalityCounts[key] || 0)
    .reduce((sum, count) => sum + count, 0);

  return {
    sampleSize,
    similarityThreshold: 0.85,
    referencedPersonalityKeys: personalityKeys,
    results: patterns.results,
    successPatterns: patterns.successPatterns
  };
}

function extractPatternsFromTexts(
  texts: string[],
  concernCategory: string
): {
  results: Record<string, any>;
  successPatterns: Array<{ pattern: string; frequency: number }>;
} {

  // キーワード頻度分析
  const keywords = concernCategory === 'career'
    ? ['転職', 'スキルアップ', '準備', '慎重', '即決']
    : concernCategory === 'romance'
    ? ['結婚', '恋愛', 'パートナー', '自由', '安定']
    : ['挑戦', '安定', '変化', '継続', 'バランス'];

  const keywordCounts: Record<string, number> = {};

  for (const text of texts) {
    for (const keyword of keywords) {
      if (text.includes(keyword)) {
        keywordCounts[keyword] = (keywordCounts[keyword] || 0) + 1;
      }
    }
  }

  // 仮の結果データ（実際はもっと高度な分析が必要）
  const results = {
    positive_action: {
      count: Math.floor(texts.length * 0.6),
      avgSatisfaction: 7.5,
      percentage: 0.6
    },
    stayed: {
      count: Math.floor(texts.length * 0.4),
      avgSatisfaction: 6.8,
      percentage: 0.4
    }
  };

  const successPatterns = Object.entries(keywordCounts)
    .map(([keyword, count]) => ({
      pattern: keyword,
      frequency: count / texts.length
    }))
    .sort((a, b) => b.frequency - a.frequency)
    .slice(0, 5);

  return { results, successPatterns };
}
```

---

## 💬 4. generateConversation（会話生成）

```typescript
async function generateConversation(params: {
  concern: string;
  concernCategory: string;
  userBIG5: Big5Scores;
  statsData: StatsData;
}): Promise<any> {

  // テンプレート選択（80%）vs AI生成（20%）
  const useTemplate = Math.random() < 0.8;

  if (useTemplate) {
    // テンプレート使用
    const template = await selectTemplate(params.concernCategory, params.userBIG5);

    // 変数を置換
    const rounds = template.rounds.map(round => ({
      roundNumber: round.roundNumber,
      messages: round.messages.map(msg => ({
        speaker: msg.speaker,
        text: replaceVariables(msg.template, {
          sampleSize: params.statsData.sampleSize.toString(),
          satisfactionRate: (params.statsData.results.positive_action?.percentage * 100).toFixed(0)
        }),
        emotion: msg.emotion
      }))
    }));

    // 結論のみAI生成
    const conclusion = await generateConclusionWithAI(params);

    return {
      generationType: 'template',
      rounds,
      conclusion
    };

  } else {
    // 完全AI生成
    return await generateFullConversationWithAI(params);
  }
}

function replaceVariables(template: string, variables: Record<string, string>): string {
  let result = template;
  for (const [key, value] of Object.entries(variables)) {
    result = result.replace(`{${key}}`, value);
  }
  return result;
}

async function generateConclusionWithAI(params: {
  concern: string;
  statsData: StatsData;
}): Promise<any> {

  const prompt = `
ユーザーの悩み: ${params.concern}

統計データ:
- サンプル数: ${params.statsData.sampleSize}人
- 結果: ${JSON.stringify(params.statsData.results)}
- 成功パターン: ${params.statsData.successPatterns.map(p => p.pattern).join(', ')}

6人の会話を踏まえて、以下の形式で結論を生成してください:

1. 要約（50文字以内）
2. 具体的な推奨アクション（3つ）
3. 投票結果（6人のうち誰がどの立場か）
`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: '6人会議の結論を生成するアシスタントです。データに基づいた具体的なアドバイスを提供します。'
      },
      { role: 'user', content: prompt }
    ],
    max_tokens: 500,
    temperature: 0.7
  });

  const conclusionText = response.choices[0].message.content || '';

  // 簡易的にパース（実際はもっと構造化された生成が必要）
  return {
    summary: conclusionText.substring(0, 100),
    recommendations: [
      '3ヶ月の準備期間を設ける',
      '最低5社は面接を受ける',
      '転職前にスキルアップ'
    ],
    votes: {
      should_change: ['opposite', 'child'],
      should_consider: ['original', 'ideal', 'wise'],
      should_not_change: ['shadow']
    }
  };
}

async function selectTemplate(
  concernCategory: string,
  userBIG5: Big5Scores
): Promise<any> {

  // テンプレートコレクションから検索
  const templates = await db
    .collection('meeting_templates')
    .where('category', '==', concernCategory)
    .orderBy('priority', 'desc')
    .limit(10)
    .get();

  // BIG5条件に合致するテンプレートを選択
  for (const doc of templates.docs) {
    const template = doc.data();
    const conditions = template.conditions;

    // BIG5範囲チェック
    if (conditions.big5Range) {
      let match = true;
      for (const [trait, range] of Object.entries(conditions.big5Range)) {
        const userValue = userBIG5[trait as keyof Big5Scores];
        if (userValue < range.min || userValue > range.max) {
          match = false;
          break;
        }
      }
      if (match) {
        return template;
      }
    }
  }

  // デフォルトテンプレート
  return templates.docs[0]?.data() || getDefaultTemplate(concernCategory);
}

function getDefaultTemplate(category: string): any {
  // デフォルトテンプレートを返す
  return {
    rounds: [
      {
        roundNumber: 1,
        messages: [
          { speaker: 'original', template: 'データを見ると、{sampleSize}人の類似ケースがあります', emotion: '😟' },
          { speaker: 'opposite', template: '考えすぎ！今すぐ行動しよう！', emotion: '😄' },
          { speaker: 'wise', template: '長期的に考えましょう', emotion: '😌' }
        ]
      }
    ]
  };
}
```

---

## 📈 5. キャッシュ効果の測定

### ログ収集

```typescript
// Cloud Functionsで自動的にログ
console.log({
  event: 'meeting_generation',
  cacheHit,
  personalityKey,
  concernCategory,
  sharedMeetingId,
  usageCount: cacheHit ? cacheData.usageCount + 1 : 1,
  responseTime: Date.now() - startTime
});
```

### BigQuery エクスポート（オプション）

```javascript
// Firebase Console → Logs → BigQuery連携
// 自動でログがBigQueryに送られる

SELECT
  DATE(timestamp) as date,
  COUNTIF(jsonPayload.cacheHit = true) / COUNT(*) as cache_hit_rate,
  AVG(jsonPayload.responseTime) as avg_response_time_ms,
  SUM(CASE WHEN jsonPayload.cacheHit = false THEN 0.12 ELSE 0 END) as total_cost_jpy
FROM
  `project.dataset.cloud_functions_logs`
WHERE
  jsonPayload.event = 'meeting_generation'
GROUP BY
  date
ORDER BY
  date DESC
```

---

## 🔐 6. セキュリティ考慮事項

```typescript
// レート制限
const MAX_REQUESTS_PER_HOUR = 50;

async function checkRateLimit(userId: string): Promise<void> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  const recentRequests = await db
    .collection('users').doc(userId)
    .collection('characters').doc('default')
    .collection('meeting_history')
    .where('createdAt', '>', oneHourAgo)
    .count()
    .get();

  if (recentRequests.data().count >= MAX_REQUESTS_PER_HOUR) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'リクエスト制限に達しました。1時間後に再度お試しください。'
    );
  }
}

// 入力検証
function validateInput(data: GenerateMeetingRequest): void {
  if (!data.concern || data.concern.length < 5) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '悩みは5文字以上で入力してください'
    );
  }

  if (data.concern.length > 500) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '悩みは500文字以内で入力してください'
    );
  }

  const validCategories = ['career', 'romance', 'stress', 'learning', 'decision'];
  if (!validCategories.includes(data.concernCategory)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      '無効なカテゴリです'
    );
  }
}
```

---

## 📝 まとめ

### キャッシュ優先ロジックの利点

```
✅ 1. コスト削減: 80%削減（3ヶ月後）
✅ 2. 高速化: 3-5秒 → 0.5秒
✅ 3. スケーラビリティ: ユーザー増加でヒット率向上
✅ 4. 品質管理: ratings で低評価を自動改善
✅ 5. 運用効率: キャッシュ数は最大890件程度
```

### 実装の優先順位

```
Phase 1（MVP）
✅ キャッシュ検索ロジック
✅ shared_meetings への保存
✅ meeting_history への参照保存
✅ 基本的なテンプレート（30パターン）

Phase 2
✅ キャッシュヒット率の測定
✅ ratings機能
✅ テンプレート拡充（100パターン）

Phase 3
✅ 高度な分析
✅ 自動最適化
✅ プリウォーミング
```

---

次のステップ: 実装ロードマップ (`07_implementation.md`)
