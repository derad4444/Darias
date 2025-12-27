# 実装ロードマップ

## 🎯 実装戦略

### 基本方針

```
MVP → 段階的リリース → フィードバック → 改善
```

**重要な原則:**
- ✅ 小さく始めて、データで検証しながら拡大
- ✅ コストを常にモニタリング
- ✅ ユーザーフィードバックを最優先
- ✅ 実データが集まったらAIデータから移行

---

## 📅 フェーズ1: MVP（最小実装）

### 期間: 1ヶ月

### 目標
```
✅ 6人会議機能の基本動作確認
✅ 初回リリースでユーザー反応を見る
✅ コストが想定通りか確認
```

### 実装内容

#### 1. データ準備（1週目）

**AIで初期データベース生成**
```typescript
// Cloud Functions: generateInitialDatabase
// 1,000人分の性格データ生成

interface PersonalityData {
  anonymousId: string;
  big5: Big5Scores;
  concerns: {
    career: { decision: string; satisfaction: number };
    relationship: { decision: string; satisfaction: number };
    // ... 10カテゴリ
  };
  isAIGenerated: true;  // 重要: AI生成フラグ
}

// GPT-4o-miniで1,000パターン生成
// コスト: 1,000人 × 0.074円 = 74円
```

**テンプレート作成**
```
10カテゴリ × 3パターン = 30テンプレート

- career_transfer_cautious.json
- career_transfer_adventurous.json
- career_transfer_balanced.json
- relationship_marriage_cautious.json
- ...
```

#### 2. バックエンド実装（2週目）

**Cloud Functions**
```typescript
// functions/src/sixPersonMeeting.ts

exports.generateMeeting = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {

    // 1. 認証チェック
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '認証が必要です');
    }

    // 2. プレミアムチェック（無料: 1回のみ）
    const userId = context.auth.uid;
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    const isPremium = userDoc.data()?.isPremium ?? false;
    const meetingCount = await getMeetingCount(userId);

    if (!isPremium && meetingCount >= 1) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'プレミアム会員限定機能です'
      );
    }

    // 3. 6人分の性格生成
    const userBIG5 = data.userBIG5;
    const variants = generateAllVariants(userBIG5);

    // 4. データベース検索（6人分）
    const searchResults = await Promise.all(
      variants.map(v => searchDatabase(v.big5, data.concern.category))
    );

    // 5. 統計計算
    const statsData = calculateStats(searchResults);

    // 6. 会話生成（80%: テンプレート、20%: AI）
    const conversation = await generateConversation({
      concern: data.concern,
      variants,
      statsData,
      useTemplate: Math.random() < 0.8
    });

    // 7. 保存
    const meetingRef = await admin.firestore()
      .collection('users').doc(userId)
      .collection('six_person_meetings')
      .add({
        concern: data.concern,
        conversation,
        statsData,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

    return {
      meetingId: meetingRef.id,
      conversation,
      statsData
    };
  });

async function generateConversation(params) {
  if (params.useTemplate) {
    // テンプレート選択
    const template = selectTemplate(
      params.concern.category,
      params.statsData
    );

    // 結論のみAI生成
    const conclusion = await generateConclusion(params);

    return {
      messages: template.messages,
      conclusion
    };
  } else {
    // 完全AI生成（20%のケース）
    return await generateFullConversation(params);
  }
}
```

**Firestore セキュリティルール**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 性格データベース（読み取り専用）
    match /personality_database/{anonymousId} {
      allow read: if request.auth != null;
      allow write: if false;  // Cloud Functionsのみ
    }

    // 会議履歴（自分のみ）
    match /users/{userId}/six_person_meetings/{meetingId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

#### 3. フロントエンド実装（3週目）

**新規ファイル作成**
```
Character/
├── Views/
│   └── SixPersonMeeting/
│       ├── SixPersonInputView.swift       // 悩み入力
│       ├── SixPersonMeetingView.swift     // 会議表示
│       └── Components/
│           ├── MessageBubbleView.swift    // メッセージ吹き出し
│           ├── CharacterIconView.swift    // キャラアイコン
│           └── StatsCardView.swift        // 統計カード
├── Models/
│   └── SixPersonMeeting.swift             // データモデル
└── Services/
    └── SixPersonMeetingService.swift      // API呼び出し
```

**基本実装例**
```swift
// SixPersonMeetingService.swift
class SixPersonMeetingService: ObservableObject {
    @Published var isLoading = false
    @Published var currentMeeting: SixPersonMeeting?
    @Published var errorMessage: String?

    func generateMeeting(
        concern: String,
        category: ConcernCategory,
        userBIG5: Big5Scores
    ) async {
        isLoading = true
        defer { isLoading = false }

        let callable = Functions.functions(region: "asia-northeast1")
            .httpsCallable("generateMeeting")

        do {
            let result = try await callable.call([
                "concern": concern,
                "category": category.rawValue,
                "userBIG5": userBIG5.toDictionary()
            ])

            if let data = result.data as? [String: Any] {
                currentMeeting = SixPersonMeeting(from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

```swift
// SixPersonMeetingView.swift
struct SixPersonMeetingView: View {
    @StateObject private var service = SixPersonMeetingService()
    @State private var currentMessageIndex = 0
    @State private var showConclusion = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // 悩みカード
                    ConcernCardView(concern: service.currentMeeting?.concern)

                    // 会話メッセージ（順次表示）
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        if index <= currentMessageIndex {
                            MessageBubbleView(message: message)
                                .id(index)
                                .transition(.opacity.combined(with: .move(edge: message.isLeft ? .leading : .trailing)))
                        }
                    }

                    // 結論
                    if showConclusion {
                        ConclusionCardView(conclusion: service.currentMeeting?.conversation.conclusion)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if currentMessageIndex < messages.count - 1 {
                withAnimation {
                    currentMessageIndex += 1
                }
            } else {
                timer.invalidate()
                showConclusion = true
            }
        }
    }
}
```

#### 4. HomeViewへの統合（4週目）

**チャット検出からの提案**
```swift
// CharacterService.swift

func detectConcern(from message: String) -> ConcernCategory? {
    let keywords: [ConcernCategory: [String]] = [
        .career: ["転職", "仕事", "キャリア", "会社"],
        .relationship: ["恋愛", "結婚", "パートナー"],
        .money: ["お金", "貯金", "投資"],
        // ...
    ]

    for (category, words) in keywords {
        if words.contains(where: { message.contains($0) }) {
            return category
        }
    }
    return nil
}

// HomeView.swiftで使用
if let concern = characterService.detectConcern(from: userMessage) {
    // 「6人会議で相談してみますか？」を表示
    Button("💭 6人会議で相談する") {
        showSixPersonInput = true
    }
}
```

**ホーム画面にアイコン追加**
```swift
// HomeView.swift

.navigationBarItems(trailing: HStack {
    // 既存のボタン
    Button(action: { showSettings.toggle() }) {
        Image(systemName: "gearshape")
    }

    // 新規: 6人会議ボタン
    Button(action: { showSixPersonInput.toggle() }) {
        Text("💭")
            .font(.title2)
    }
})
.sheet(isPresented: $showSixPersonInput) {
    SixPersonInputView()
}
```

### テスト（4週目）

```
✅ 単体テスト
  - BIG5変換ロジック
  - データベース検索
  - 統計計算

✅ 統合テスト
  - Cloud Functions全体フロー
  - プレミアムチェック
  - エラーハンドリング

✅ E2Eテスト
  - チャット検出 → 会議生成
  - ホームアイコン → 会議生成
  - 無料1回制限の確認

✅ コストモニタリング
  - 実際のAPI呼び出しコスト確認
  - 想定: 0.12円/会議
```

### デプロイ

```bash
# 1. Firestore初期データ投入
npm run deploy:initial-database

# 2. Cloud Functions
firebase deploy --only functions

# 3. Firestore Rules
firebase deploy --only firestore:rules

# 4. iOS App
# TestFlightでベータテスト（社内）
```

---

## 📅 フェーズ2: 機能拡張

### 期間: 2ヶ月（MVP後）

### 目標
```
✅ テンプレート拡充
✅ ユーザーフィードバック反映
✅ 実データ収集開始
✅ 精度向上
```

### 実装内容

#### 1. テンプレート拡充（5-6週目）

```
30パターン → 100パターンへ

10カテゴリ × 10パターン = 100テンプレート

各カテゴリに細分化:
- career_transfer_cautious_20s.json
- career_transfer_cautious_30s.json
- career_startup_high_openness.json
- ...
```

**動的テンプレート選択**
```typescript
function selectTemplate(
  category: string,
  userAge: number,
  userBIG5: Big5Scores,
  statsData: StatsData
): Template {
  // 年齢、性格、統計結果から最適テンプレート選択
  const ageGroup = getAgeGroup(userAge);  // 20s, 30s, 40s...
  const dominantTrait = getDominantTrait(userBIG5);

  const templateKey = `${category}_${dominantTrait}_${ageGroup}`;

  return templates[templateKey] ?? templates[`${category}_default`];
}
```

#### 2. 投票機能（7-8週目）

**会議結果に投票**
```swift
struct SixPersonMeeting {
    // 既存フィールド
    var votingResult: VotingResult?
}

struct VotingResult: Codable {
    var helpful: Bool?        // 役に立った？
    var followed: Bool?       // 実際に実行した？
    var satisfaction: Int?    // 満足度（1-5）
}
```

**UI追加**
```swift
// 結論カードの下に投票ボタン
VStack(spacing: 12) {
    Text("この会議は役に立ちましたか？")
        .font(.subheadline)

    HStack(spacing: 20) {
        Button(action: { vote(helpful: true) }) {
            Label("役に立った", systemImage: "hand.thumbsup")
        }
        Button(action: { vote(helpful: false) }) {
            Label("あまり", systemImage: "hand.thumbsdown")
        }
    }
}
```

**Firestoreに保存して分析**
```typescript
// 毎月集計
exports.analyzeVotingResults = functions
  .pubsub.schedule('0 0 1 * *')  // 月初
  .onRun(async () => {
    const results = await getMonthlyVotingResults();

    // どのテンプレートが評価高いか
    // どのカテゴリが人気か
    // AI生成 vs テンプレートどちらが良いか

    await saveAnalytics(results);
  });
```

#### 3. 実データ収集開始（9-12週目）

**オプトイン形式で収集**
```swift
struct SettingsView {
    Toggle("統計データへの協力（匿名）", isOn: $contributeToDatabase)
        .onChange(of: contributeToDatabase) { newValue in
            if newValue {
                // 説明表示
                showDataContributionSheet = true
            }
        }
}
```

**データ収集シート**
```swift
struct DataContributionSheet: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("📊 統計データへのご協力")
                .font(.title2)

            Text("""
            あなたの選択を匿名で統計データに追加することで、
            他のユーザーへのアドバイス精度が向上します。

            ✅ 完全匿名（個人は特定されません）
            ✅ いつでも停止可能
            ✅ 既存データも削除可能
            """)
            .multilineTextAlignment(.center)

            Button("協力する") {
                enableContribution()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

**「今日の選択」機能（簡易版）**
```swift
// 日記画面に追加
struct DiaryView {
    // 既存の日記機能

    // 新規: 今日の選択を記録
    VStack {
        Text("今日、何か決断をしましたか？")
        TextField("例: 転職の面接を受けた", text: $todayDecision)

        Picker("カテゴリ", selection: $decisionCategory) {
            ForEach(ConcernCategory.allCases) { category in
                Text(category.label).tag(category)
            }
        }

        Button("記録する") {
            saveTodayDecision()
        }
    }
}
```

**実データをデータベースに追加**
```typescript
exports.addRealUserData = functions
  .firestore.document('users/{userId}/decisions/{decisionId}')
  .onCreate(async (snap, context) => {
    const decision = snap.data();

    if (!decision.contributeToDatabase) {
      return;
    }

    // 匿名化
    const anonymousId = generateAnonymousId();

    await admin.firestore()
      .collection('personality_database')
      .doc(anonymousId)
      .set({
        big5: decision.userBIG5,
        concerns: {
          [decision.category]: {
            decision: decision.choice,
            satisfaction: decision.satisfaction,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          }
        },
        isAIGenerated: false  // 実データ
      }, { merge: true });
  });
```

#### 4. 分析ダッシュボード（内部用）

```swift
// Admin専用ビュー
struct AnalyticsDashboardView: View {
    var body: some View {
        List {
            Section("使用状況") {
                Text("総会議数: \(totalMeetings)")
                Text("今月の会議数: \(monthlyMeetings)")
                Text("平均コスト: ¥\(averageCost)")
            }

            Section("人気カテゴリ") {
                ForEach(popularCategories) { category in
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text("\(category.count)回")
                    }
                }
            }

            Section("データソース") {
                Text("AI生成: \(aiGeneratedCount)人")
                Text("実データ: \(realDataCount)人")
                ProgressView(value: Double(realDataCount) / Double(totalDataCount))
            }
        }
    }
}
```

---

## 📅 フェーズ3: 完全版機能

### 期間: 3-6ヶ月（フェーズ2後）

### 目標
```
✅ 実データが主体になる
✅ 新機能追加
✅ パフォーマンス最適化
✅ ユーザー体験の洗練
```

### 実装内容

#### 1. 質問モード（13-16週目）

**6人が質問してくる**
```swift
struct QuestionModeView: View {
    @State private var currentQuestionIndex = 0

    var body: some View {
        VStack {
            // キャラクターが質問
            CharacterBubbleView(
                character: characters[currentQuestionIndex],
                message: questions[currentQuestionIndex]
            )

            // ユーザーが回答
            TextField("あなたの答え", text: $userAnswer)

            Button("答える") {
                saveAnswer()
                currentQuestionIndex += 1
            }
        }
    }
}
```

**質問例**
```
🧑 今の自分: 「今の年収と転職先の予想年収を教えてもらえる？」
👶 子供の自分: 「新しい会社でやってみたいワクワクすることは何？」
👴 未来の自分: 「20年後、どちらを選んだ方が後悔しないと思う？」
```

#### 2. 詳細ストーリー機能（17-20週目）

**似た人の体験談を表示**
```swift
struct DetailedStoryView: View {
    let story: UserStory

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 匿名ユーザーの体験
            Text("Aさん（32歳、性格類似度: 87%）の体験")
                .font(.headline)

            Text("5年前、私も同じ悩みを抱えていました...")

            // タイムライン
            TimelineView(events: story.timeline)

            // 満足度の変化
            SatisfactionChartView(data: story.satisfactionHistory)

            // 学び
            Text("学んだこと: \(story.lesson)")
                .italic()
        }
    }
}
```

#### 3. キャッシュ最適化（21-22週目）

```typescript
// Firestore → Redis移行（頻繁にアクセスされるデータ）
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_URL,
  token: process.env.UPSTASH_REDIS_TOKEN
});

async function searchDatabaseWithCache(
  big5: Big5Scores,
  category: string
): Promise<PersonalityData[]> {
  const cacheKey = `search:${hashBIG5(big5)}:${category}`;

  // キャッシュチェック
  const cached = await redis.get(cacheKey);
  if (cached) {
    return JSON.parse(cached as string);
  }

  // Firestoreから検索
  const results = await searchFirestore(big5, category);

  // キャッシュ保存（1時間）
  await redis.setex(cacheKey, 3600, JSON.stringify(results));

  return results;
}
```

**コスト削減効果**
```
キャッシュヒット率30%想定:
Firestore読み取り: 0.09円 × 0.7 = 0.063円
総コスト: 0.12円 → 0.093円（22%削減）
```

#### 4. A/Bテスト（23-24週目）

```typescript
// テンプレート vs 完全AI生成
exports.generateMeeting = functions
  .https.onCall(async (data, context) => {

    const userId = context.auth!.uid;
    const experimentGroup = getUserExperimentGroup(userId);

    let useTemplate: boolean;
    if (experimentGroup === 'A') {
      useTemplate = true;  // 100%テンプレート
    } else if (experimentGroup === 'B') {
      useTemplate = false; // 100%AI生成
    } else {
      useTemplate = Math.random() < 0.8;  // 既存（80/20）
    }

    // ログ記録
    await logExperiment({
      userId,
      group: experimentGroup,
      useTemplate,
      timestamp: Date.now()
    });

    // ...
  });
```

---

## 🧪 テスト戦略

### 1. 単体テスト

```typescript
// functions/test/big5Transform.test.ts
describe('BIG5 Transformation', () => {
  test('opposite variant inverts all scores', () => {
    const original = {
      openness: 4,
      conscientiousness: 4,
      extraversion: 2,
      agreeableness: 4,
      neuroticism: 3
    };

    const opposite = transformBIG5(original, 'opposite');

    expect(opposite.openness).toBe(2);
    expect(opposite.conscientiousness).toBe(2);
    expect(opposite.extraversion).toBe(4);
  });

  test('wise variant increases agreeableness', () => {
    const original = { /* ... */ };
    const wise = transformBIG5(original, 'wise');

    expect(wise.agreeableness).toBeGreaterThan(original.agreeableness);
  });
});
```

### 2. 統合テスト

```typescript
// functions/test/generateMeeting.integration.test.ts
describe('Generate Meeting Integration', () => {
  test('creates meeting for premium user', async () => {
    const userId = 'test-premium-user';
    await setPremiumStatus(userId, true);

    const result = await callFunction('generateMeeting', {
      concern: '転職すべきか悩んでいます',
      category: 'career',
      userBIG5: testBIG5
    });

    expect(result.data.meetingId).toBeDefined();
    expect(result.data.conversation.messages).toHaveLength(12);
  });

  test('blocks free user after 1 meeting', async () => {
    const userId = 'test-free-user';
    await setPremiumStatus(userId, false);

    // 1回目は成功
    await callFunction('generateMeeting', { /* ... */ });

    // 2回目は失敗
    await expect(
      callFunction('generateMeeting', { /* ... */ })
    ).rejects.toThrow('プレミアム会員限定機能です');
  });
});
```

### 3. E2Eテスト

```swift
// CharacterUITests/SixPersonMeetingTests.swift
class SixPersonMeetingTests: XCTestCase {
    func testFullFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. ホーム画面から会議ボタンタップ
        app.buttons["💭"].tap()

        // 2. 悩み入力
        let textField = app.textFields["悩みを入力"]
        textField.tap()
        textField.typeText("転職すべきか悩んでいます")

        // 3. カテゴリ選択
        app.buttons["キャリア・仕事"].tap()

        // 4. 会議開始
        app.buttons["会議を開始"].tap()

        // 5. メッセージが順次表示される
        XCTAssertTrue(app.staticTexts["🧑 今の自分"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["🔄 真逆の自分"].waitForExistence(timeout: 4))

        // 6. 結論が表示される
        XCTAssertTrue(app.staticTexts["📝 結論"].waitForExistence(timeout: 20))
    }
}
```

### 4. コストモニタリング

```typescript
// Cloud Functionsでコスト記録
exports.logCost = functions
  .firestore.document('users/{userId}/six_person_meetings/{meetingId}')
  .onCreate(async (snap, context) => {
    const meeting = snap.data();

    await admin.firestore()
      .collection('analytics')
      .doc('costs')
      .collection('daily')
      .doc(getTodayDateString())
      .set({
        totalMeetings: admin.firestore.FieldValue.increment(1),
        totalCost: admin.firestore.FieldValue.increment(meeting.cost),
        averageCost: // 計算
      }, { merge: true });
  });

// 毎日アラート
exports.dailyCostAlert = functions
  .pubsub.schedule('0 9 * * *')  // 毎朝9時
  .onRun(async () => {
    const yesterday = await getDailyCost(getYesterdayDateString());

    if (yesterday.totalCost > 1000) {  // 1,000円超えたらアラート
      await sendSlackAlert(`⚠️ コストアラート: 昨日のコストが${yesterday.totalCost}円でした`);
    }
  });
```

---

## 🚀 デプロイメントチェックリスト

### フェーズ1 MVP リリース前

```
□ データ準備
  □ AI生成データベース（1,000人分）完成
  □ テンプレート30パターン完成
  □ Firestore Indexesを作成

□ バックエンド
  □ Cloud Functions動作確認
  □ セキュリティルール設定
  □ エラーハンドリング実装
  □ ログ設定（Cloud Logging）

□ フロントエンド
  □ プレミアムチェック動作確認
  □ エラーメッセージ適切に表示
  □ ローディング状態の表示
  □ アニメーション滑らか

□ テスト
  □ 単体テスト全パス
  □ 統合テスト全パス
  □ E2Eテスト全パス
  □ コスト計測（想定: 0.12円/会議）

□ ドキュメント
  □ ユーザーガイド作成
  □ FAQ作成
  □ プレミアム機能説明

□ モニタリング
  □ Firebase Analytics設定
  □ Crashlytics設定
  □ コストアラート設定

□ App Store
  □ スクリーンショット更新
  □ 説明文更新
  □ プライバシーポリシー更新
```

### デプロイ手順

```bash
# 1. バックエンド
cd functions
npm run build
npm run test
firebase deploy --only functions

# 2. Firestore
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# 3. 初期データ投入
npm run deploy:initial-database

# 4. iOS App
# Xcodeでビルド番号インクリメント
# Archive → Distribute App → TestFlight

# 5. 動作確認
# TestFlightで社内テスト（1週間）

# 6. 本番リリース
# App Store Connect → Submit for Review
```

---

## 🔄 ロールバック手順

### Cloud Functionsロールバック

```bash
# 現在のバージョン確認
firebase functions:list

# 前バージョンにロールバック
firebase functions:delete generateMeeting --force
firebase deploy --only functions:generateMeeting --version <前バージョン>
```

### Firestore Rulesロールバック

```bash
# Firestore Console → Rules → History → Rollback
```

### iOSアプリロールバック

```
App Store Connectでは直接ロールバック不可

対策:
1. 致命的バグの場合
   → 前バージョンを緊急再提出
   → 審査を「Expedited Review」でリクエスト

2. 一時的な対策
   → サーバー側で機能を無効化
   → アプリ内で「メンテナンス中」表示
```

**サーバー側での機能無効化**
```typescript
// Remote Configで制御
const featureFlags = await admin.remoteConfig().getTemplate();

exports.generateMeeting = functions
  .https.onCall(async (data, context) => {

    // 機能フラグチェック
    const isEnabled = featureFlags.parameters['six_person_meeting_enabled'];
    if (!isEnabled) {
      throw new functions.https.HttpsError(
        'unavailable',
        '現在この機能はメンテナンス中です'
      );
    }

    // ...
  });
```

---

## 📊 成功指標（KPI）

### フェーズ1（MVP）

```
目標:
✅ 月間会議数: 100回以上
✅ プレミアム転換率: 3%以上
✅ ユーザー満足度: 70%以上（投票）
✅ コスト/会議: 0.15円以下
```

### フェーズ2（機能拡張）

```
目標:
✅ 月間会議数: 500回以上
✅ プレミアム転換率: 5%以上
✅ ユーザー満足度: 80%以上
✅ 実データ比率: 10%以上
✅ コスト/会議: 0.12円以下
```

### フェーズ3（完全版）

```
目標:
✅ 月間会議数: 2,000回以上
✅ プレミアム転換率: 10%以上
✅ ユーザー満足度: 85%以上
✅ 実データ比率: 30%以上
✅ コスト/会議: 0.10円以下
```

---

## 🎯 次のアクション

### すぐに始めること

1. **AI初期データベース生成スクリプト作成**
   ```bash
   cd functions/scripts
   touch generateInitialDatabase.ts
   ```

2. **30テンプレートの作成**
   ```bash
   mkdir -p functions/templates
   # 10カテゴリ × 3パターン = 30ファイル
   ```

3. **Cloud Functions基本構造作成**
   ```bash
   cd functions/src
   touch sixPersonMeeting.ts
   ```

4. **SwiftUIビュー雛形作成**
   ```bash
   cd Character/Views
   mkdir SixPersonMeeting
   touch SixPersonMeeting/SixPersonInputView.swift
   ```

### 1週間以内にやること

- [ ] AI初期データベース生成（1,000人分）
- [ ] テンプレート30パターン完成
- [ ] Cloud Functions基本実装
- [ ] SwiftUI基本画面実装

### 1ヶ月以内にやること

- [ ] MVP全機能実装完了
- [ ] テスト完了
- [ ] TestFlightで社内テスト開始
- [ ] ドキュメント完成

---

## ✅ まとめ

### 実装の優先順位

```
【高】必須（MVP）
- 6人会議の基本機能
- 30テンプレート
- プレミアムチェック
- コストモニタリング

【中】重要（フェーズ2）
- テンプレート拡充（100個）
- 投票機能
- 実データ収集開始

【低】あると良い（フェーズ3）
- 質問モード
- 詳細ストーリー
- キャッシュ最適化
```

### リスク管理

```
⚠️ コストが想定より高い
→ テンプレート比率を上げる（80% → 90%）
→ キャッシュ導入を前倒し

⚠️ ユーザー満足度が低い
→ テンプレート品質改善
→ AI生成比率を上げる

⚠️ プレミアム転換率が低い
→ 無料枠を0回にする
→ 他のプレミアム特典を強化
```

### 最終的なゴール

```
🎯 ユーザー1,000人、課金率5%
🎯 月間500会議、年間6,000会議
🎯 年間コスト: 720円
🎯 年間収益: 588,000円
🎯 利益率: 99.88%

👉 安定的に黒字、スケール可能なビジネスモデル
```

---

設計書は以上で完成です！
次は実装に進みましょう 🚀
