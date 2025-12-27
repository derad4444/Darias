# API設計（Cloud Functions）

## 🔧 Cloud Functions一覧

```
functions/src/
├── sixPersonMeeting/
│   ├── generateMeeting.ts          ← メイン関数
│   ├── searchDatabase.ts           ← データベース検索
│   ├── calculateStats.ts           ← 統計計算
│   ├── generateConversation.ts     ← 会話生成
│   └── templates/
│       ├── careerChange.ts         ← カテゴリ別テンプレート
│       ├── romance.ts
│       └── ...
```

---

## 📡 1. generateMeeting（メイン関数）

### エンドポイント
```typescript
exports.generateMeeting = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    // ...
  });
```

### リクエスト
```typescript
interface GenerateMeetingRequest {
  userId: string;
  characterId: string;
  concern: string;
  concernCategory?: string;  // 'career', 'romance', etc
  userBIG5: {
    openness: number;
    conscientiousness: number;
    extraversion: number;
    agreeableness: number;
    neuroticism: number;
  };
}
```

### レスポンス
```typescript
interface GenerateMeetingResponse {
  meetingId: string;
  conversation: {
    generationType: 'template' | 'ai_generated';
    rounds: Round[];
    conclusion: Conclusion;
  };
  statsData: StatsData;
  createdAt: Timestamp;
}
```

### 実装

```typescript
import { OpenAI } from 'openai';
import * as admin from 'firebase-admin';

const openai = new OpenAI({
  apiKey: functions.config().openai.key
});

export const generateMeeting = functions
  .region('asia-northeast1')
  .https.onCall(async (data: GenerateMeetingRequest, context) => {

    // 1. 認証チェック
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'ユーザー認証が必要です'
      );
    }

    // 2. プレミアムチェック
    const isPremium = await checkPremiumStatus(data.userId);
    if (!isPremium) {
      const usageCount = await getMeetingUsageCount(data.userId);
      if (usageCount >= 1) {
        throw new functions.https.HttpsError(
          'permission-denied',
          '無料プランは1回のみです。プレミアムにアップグレードしてください。'
        );
      }
    }

    // 3. データベース検索（6人分）
    const searchResults = await searchForAllVariants(
      data.userBIG5,
      data.concernCategory || 'general'
    );

    // 4. 統計計算
    const statsData = calculateStats(
      searchResults,
      data.concernCategory || 'general'
    );

    // 5. 会話生成（テンプレート or AI）
    const conversation = await generateConversation({
      concern: data.concern,
      concernCategory: data.concernCategory,
      userBIG5: data.userBIG5,
      statsData: statsData
    });

    // 6. Firestoreに保存
    const meetingRef = await admin.firestore()
      .collection('users').doc(data.userId)
      .collection('six_person_meetings')
      .add({
        userId: data.userId,
        characterId: data.characterId,
        concern: {
          text: data.concern,
          category: data.concernCategory || 'general',
          detectedAt: admin.firestore.FieldValue.serverTimestamp()
        },
        userBIG5: data.userBIG5,
        conversation: conversation,
        statsData: statsData,
        isPremium: isPremium,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

    return {
      meetingId: meetingRef.id,
      conversation: conversation,
      statsData: statsData,
      createdAt: new Date()
    };
  });

// ヘルパー関数
async function checkPremiumStatus(userId: string): Promise<boolean> {
  const userDoc = await admin.firestore()
    .collection('users').doc(userId).get();
  return userDoc.data()?.isPremium === true;
}

async function getMeetingUsageCount(userId: string): Promise<number> {
  const snapshot = await admin.firestore()
    .collection('users').doc(userId)
    .collection('six_person_meetings')
    .count()
    .get();
  return snapshot.data().count;
}
```

---

## 🔍 2. searchForAllVariants（データベース検索）

6人の性格それぞれでデータベースを検索

```typescript
async function searchForAllVariants(
  userBIG5: Big5Scores,
  concernCategory: string
): Promise<Map<PersonalityVariant, PersonalityDatabaseEntry[]>> {

  const results = new Map();
  const variants: PersonalityVariant[] = [
    'original', 'opposite', 'ideal', 'shadow', 'child', 'wise'
  ];

  // 並列検索で高速化
  await Promise.all(
    variants.map(async (variant) => {
      const transformedBIG5 = transformBIG5(userBIG5, variant);
      const entries = await searchDatabase(transformedBIG5, concernCategory);
      results.set(variant, entries);
    })
  );

  return results;
}

function transformBIG5(
  original: Big5Scores,
  variant: PersonalityVariant
): Big5Scores {
  switch (variant) {
    case 'original':
      return original;

    case 'opposite':
      return {
        openness: 6 - original.openness,
        conscientiousness: 6 - original.conscientiousness,
        extraversion: 6 - original.extraversion,
        agreeableness: 6 - original.agreeableness,
        neuroticism: 6 - original.neuroticism
      };

    case 'ideal':
      return {
        openness: Math.max(original.openness, 4),
        conscientiousness: Math.max(original.conscientiousness, 4),
        extraversion: optimizeToMiddle(original.extraversion, 3.5),
        agreeableness: Math.max(original.agreeableness, 4),
        neuroticism: Math.max(original.neuroticism, 4)
      };

    case 'shadow':
      return {
        openness: Math.min(original.openness + 1.5, 5),
        conscientiousness: Math.max(original.conscientiousness - 2, 1),
        extraversion: Math.min(original.extraversion + 1.5, 5),
        agreeableness: Math.max(original.agreeableness - 2.5, 1),
        neuroticism: Math.max(original.neuroticism - 1.5, 1)
      };

    case 'child':
      return {
        openness: 5,
        conscientiousness: 1,
        extraversion: Math.max(original.extraversion + 1, 4),
        agreeableness: 3,
        neuroticism: 2
      };

    case 'wise':
      return {
        openness: Math.max(original.openness - 1, 2),
        conscientiousness: Math.min(original.conscientiousness + 0.5, 5),
        extraversion: Math.max(original.extraversion - 1, 2),
        agreeableness: Math.min(original.agreeableness + 1, 5),
        neuroticism: Math.min(original.neuroticism + 1.5, 5)
      };

    default:
      return original;
  }
}

// 極端な値を中央寄りに調整する関数（1-5スケール用）
function optimizeToMiddle(value: number, target: number): number {
  if (value < target) {
    return Math.min(value + 1, target);
  } else if (value > target) {
    return Math.max(value - 1, target);
  }
  return value;
}

async function searchDatabase(
  big5: Big5Scores,
  concernCategory: string,
  limit: number = 200
): Promise<PersonalityDatabaseEntry[]> {

  // Firestoreクエリ（粗い検索、1-5スケール）
  const snapshot = await admin.firestore()
    .collection('personality_database')
    .where('big5Profile.conscientiousness', '>=', big5.conscientiousness - 1)
    .where('big5Profile.conscientiousness', '<=', big5.conscientiousness + 1)
    .limit(500)
    .get();

  // クライアントサイドで詳細フィルタリング
  const entries = snapshot.docs
    .map(doc => doc.data() as PersonalityDatabaseEntry)
    .filter(entry => {
      const similarity = calculateSimilarity(big5, entry.big5Profile);
      return similarity >= 0.85;
    })
    .slice(0, limit);

  return entries;
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

## 📊 3. calculateStats（統計計算）

```typescript
function calculateStats(
  searchResults: Map<PersonalityVariant, PersonalityDatabaseEntry[]>,
  concernCategory: string
): StatsData {

  // 'original'（今の自分）のデータを使用
  const originalEntries = searchResults.get('original') || [];

  // データソースのカウント
  const aiGenerated = originalEntries.filter(
    e => e.dataSource === 'ai_generated'
  ).length;
  const realUsers = originalEntries.filter(
    e => e.dataSource === 'real_user'
  ).length;

  // イベント別の集計
  const eventType = concernCategoryToEventType(concernCategory);
  const relevantEvents = originalEntries.flatMap(entry =>
    entry.lifeEvents.filter(event => event.eventType === eventType)
  );

  // 決断別にグループ化
  const grouped = groupBy(relevantEvents, event => event.decision || 'unknown');

  const results: Record<string, StatsResult> = {};

  for (const [decision, events] of Object.entries(grouped)) {
    const satisfied = events.filter(e => e.satisfaction >= 7).length;
    const regretted = events.filter(e => e.satisfaction <= 4).length;
    const neutral = events.length - satisfied - regretted;

    results[decision] = {
      total: events.length,
      satisfied,
      regretted,
      neutral,
      satisfactionRate: events.length > 0 ? satisfied / events.length : 0
    };
  }

  // 成功パターンの抽出
  const successPatterns = extractSuccessPatterns(relevantEvents);

  return {
    sampleSize: originalEntries.length,
    similarityThreshold: 0.85,
    dataSource: {
      aiGenerated,
      realUsers
    },
    results,
    successPatterns
  };
}

function extractSuccessPatterns(events: LifeEvent[]): SuccessPattern[] {
  // 成功した人（満足度7以上）の共通点を抽出
  const successfulEvents = events.filter(e => e.satisfaction >= 7);

  // 説明文からパターンを抽出（簡易版）
  const patterns: Record<string, number> = {};

  successfulEvents.forEach(event => {
    if (event.description.includes('3ヶ月') || event.description.includes('準備')) {
      patterns['準備期間3ヶ月以上'] = (patterns['準備期間3ヶ月以上'] || 0) + 1;
    }
    if (event.description.includes('5社') || event.description.includes('面接')) {
      patterns['面接5社以上'] = (patterns['面接5社以上'] || 0) + 1;
    }
    // ... 他のパターン
  });

  return Object.entries(patterns)
    .map(([pattern, count]) => ({
      pattern,
      successRate: count / successfulEvents.length
    }))
    .filter(p => p.successRate >= 0.5)  // 50%以上のパターンのみ
    .sort((a, b) => b.successRate - a.successRate)
    .slice(0, 5);  // トップ5
}
```

---

## 💬 4. generateConversation（会話生成）

### テンプレート vs AI生成の判定

```typescript
async function generateConversation(params: {
  concern: string;
  concernCategory?: string;
  userBIG5: Big5Scores;
  statsData: StatsData;
}): Promise<Conversation> {

  // 80%はテンプレート、20%はAI生成
  const useTemplate = Math.random() < 0.8;

  if (useTemplate) {
    return generateFromTemplate(params);
  } else {
    return generateWithAI(params);
  }
}
```

### テンプレート生成

```typescript
function generateFromTemplate(params: {
  concern: string;
  concernCategory?: string;
  userBIG5: Big5Scores;
  statsData: StatsData;
}): Conversation {

  // カテゴリに応じたテンプレート取得
  const template = getTemplate(params.concernCategory || 'general');

  // 変数を置き換え
  const rounds = template.rounds.map(roundTemplate => ({
    roundNumber: roundTemplate.roundNumber,
    messages: roundTemplate.messages.map(msgTemplate => ({
      speaker: msgTemplate.speaker,
      text: replacePlaceholders(msgTemplate.template, {
        sampleSize: params.statsData.sampleSize,
        satisfactionRate: params.statsData.results['changed_job']?.satisfactionRate || 0.66,
        // ... 他の変数
      }),
      emotion: msgTemplate.emotion
    }))
  }));

  // 結論は常にAIで生成（カスタマイズのため）
  const conclusion = generateConclusionWithAI(params);

  return {
    generationType: 'template',
    rounds,
    conclusion
  };
}

function replacePlaceholders(
  template: string,
  variables: Record<string, any>
): string {
  let result = template;
  for (const [key, value] of Object.entries(variables)) {
    result = result.replace(`{${key}}`, String(value));
  }
  return result;
}
```

### AI生成（結論部分）

```typescript
async function generateConclusionWithAI(params: {
  concern: string;
  userBIG5: Big5Scores;
  statsData: StatsData;
}): Promise<Conclusion> {

  const prompt = `
あなたは6人の異なる性格を持つアドバイザーです。
以下の情報を基に、最終的な結論を生成してください。

【ユーザーの悩み】
${params.concern}

【ユーザーの性格】
- 開放性: ${params.userBIG5.openness}
- 誠実性: ${params.userBIG5.conscientiousness}
- 外向性: ${params.userBIG5.extraversion}
- 協調性: ${params.userBIG5.agreeableness}
- 情緒安定性: ${params.userBIG5.neuroticism}

【統計データ】
サンプル数: ${params.statsData.sampleSize}人
${formatStatsForPrompt(params.statsData)}

【指示】
1. 結論サマリー（100文字程度）
2. 具体的な推奨アクション（3つ）
3. 6人の投票結果（どのキャラクターがどちらを推奨するか）

JSON形式で出力：
{
  "summary": "...",
  "recommendations": ["...", "...", "..."],
  "votes": {
    "should_do": ["opposite", "child"],
    "should_consider": ["original", "ideal", "wise"],
    "should_not_do": ["shadow"]
  }
}
`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: '6人会議の結論を生成します' },
      { role: 'user', content: prompt }
    ],
    max_tokens: 500,
    temperature: 0.7,
    response_format: { type: 'json_object' }
  });

  const result = JSON.parse(response.choices[0].message.content || '{}');

  return {
    summary: result.summary,
    recommendations: result.recommendations,
    votes: result.votes
  };
}
```

### 完全AI生成（20%のケース）

```typescript
async function generateWithAI(params: {
  concern: string;
  concernCategory?: string;
  userBIG5: Big5Scores;
  statsData: StatsData;
}): Promise<Conversation> {

  const prompt = `
あなたは6人の異なる性格を演じ分けます。

【6人の設定】
1. 今の自分（慎重派） - ${JSON.stringify(params.userBIG5)}
2. 真逆の自分（冒険家） - 全特性反転
3. 理想の自分（バランス型）
4. 本音の自分（率直）
5. 子供の自分（純粋）
6. 未来の自分（70歳・達観）

【悩み】
${params.concern}

【データ】
${JSON.stringify(params.statsData, null, 2)}

【指示】
3ラウンドの会話を生成してください。
各発言は30-50文字。性格の違いを明確に。

JSON形式：
{
  "rounds": [
    {
      "roundNumber": 1,
      "messages": [
        {"speaker": "original", "text": "...", "emotion": "😟"},
        ...
      ]
    }
  ],
  "conclusion": {
    "summary": "...",
    "recommendations": [...],
    "votes": {...}
  }
}
`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: '6人会議を生成します' },
      { role: 'user', content: prompt }
    ],
    max_tokens: 2000,
    temperature: 0.8,
    response_format: { type: 'json_object' }
  });

  const result = JSON.parse(response.choices[0].message.content || '{}');

  return {
    generationType: 'ai_generated',
    rounds: result.rounds,
    conclusion: result.conclusion
  };
}
```

---

## 📝 5. テンプレート定義

```typescript
// templates/careerChange.ts

export const careerChangeTemplate: ConversationTemplate = {
  category: 'career',
  subcategory: 'career_change',

  rounds: [
    {
      roundNumber: 1,
      messages: [
        {
          speaker: 'original',
          template: '転職は大きな決断だから、慎重に考えた方がいい。データを見ると、君と似た性格の{sampleSize}人のうち...',
          emotion: '😟',
          variables: ['sampleSize']
        },
        {
          speaker: 'opposite',
          template: 'えー！慎重すぎない？人生一度きりだよ！今すぐ転職活動始めよう！',
          emotion: '😄',
          variables: []
        },
        {
          speaker: 'wise',
          template: '二人とも落ち着きなさい。私が70年生きて学んだのは、「焦って決めたことは後悔する」ということだよ。',
          emotion: '😌',
          variables: []
        },
        {
          speaker: 'ideal',
          template: '客観的に見ましょう。統計データと感情、両方大事です。',
          emotion: '🤔',
          variables: []
        },
        {
          speaker: 'child',
          template: 'ねえねえ、どっちがワクワクする？楽しい方がいいよ！',
          emotion: '😊',
          variables: []
        },
        {
          speaker: 'shadow',
          template: '正直に言うと、今の会社から逃げたいだけじゃない？それって転職の理由になる？',
          emotion: '😐',
          variables: []
        }
      ]
    },
    {
      roundNumber: 2,
      messages: [
        {
          speaker: 'opposite',
          template: '慎重すぎるとチャンス逃すよ？データばっか見てないでさ',
          emotion: '😤',
          variables: []
        },
        {
          speaker: 'original',
          template: 'でもリスクもあるでしょ。統計では準備3ヶ月で成功率{successRate}%だよ',
          emotion: '📊',
          variables: ['successRate']
        },
        // ... 続く
      ]
    }
  ]
};
```

---

## 🔐 セキュリティ

### レート制限

```typescript
// Cloud Functionsのレート制限
export const generateMeeting = functions
  .runWith({
    // 同時実行数制限
    maxInstances: 10
  })
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    // ユーザーごとのレート制限チェック
    const userId = context.auth?.uid;
    if (userId) {
      const rateLimitOk = await checkRateLimit(userId, 10, 60); // 1分間に10回まで
      if (!rateLimitOk) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'リクエストが多すぎます。しばらくお待ちください。'
        );
      }
    }
    // ...
  });
```

### 入力検証

```typescript
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

  // BIG5の範囲チェック
  const big5 = data.userBIG5;
  for (const [key, value] of Object.entries(big5)) {
    if (value < 0 || value > 100) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `BIG5の値が不正です: ${key}`
      );
    }
  }
}
```

---

次のステップ: コスト試算 (`06_cost-estimation.md`)
