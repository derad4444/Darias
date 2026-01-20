# データ構造設計（既存DB統合版 + キャッシュ最適化）

## 📊 既存Firestoreスキーマの活用

### 戦略
```
✅ 新規コレクション最小化
✅ 既存の users, Big5Analysis, PersonalityStatsMetadata を最大活用
✅ 実ユーザーデータを統計ソースに使用
✅ AI生成データは不要（実データで十分）
✅ 会議内容を共有キャッシュで再利用（コスト削減 + 高速化）
```

---

## 🆕 1. 新規追加: 共有会議キャッシュ

**全ユーザー共通のキャッシュデータ（ルートレベル）**

```
/shared_meetings/{sharedMeetingId}
{
  sharedMeetingId: "sm_abc123",

  // キャッシュキー（検索用）
  personalityKey: "O4_C4_E2_A4_N3_female",
  concernCategory: "career",  // Big5AnalysisCategory
  concernSubcategory: "career_change",

  // キーワードハッシュ（類似検索用、オプション）
  concernKeywords: ["転職", "仕事", "辞めたい"],

  // 会話内容（全ユーザー共通）
  conversation: {
    generationType: "template" | "ai_generated",

    rounds: [
      {
        roundNumber: 1,
        messages: [
          {
            speaker: "original",
            text: "転職は大きな決断だから...",
            emotion: "😟"
          },
          {
            speaker: "opposite",
            text: "えー！慎重すぎない？...",
            emotion: "😄"
          }
          // 6人分
        ]
      }
      // 3ラウンド
    ],

    conclusion: {
      summary: "どちらを選んでも満足度は同じですが...",
      recommendations: [
        "3ヶ月の準備期間を設ける",
        "最低5社は面接を受ける"
      ],
      votes: {
        "should_change": ["opposite", "child"],
        "should_consider": ["original", "ideal", "wise"],
        "should_not_change": ["shadow"]
      }
    }
  },

  // 統計データ（全ユーザー共通）
  statsData: {
    sampleSize: 127,
    similarityThreshold: 0.85,
    referencedPersonalityKeys: [
      "O4_C4_E2_A4_N3_female",
      "O4_C4_E2_A4_N2_female",
      "O5_C4_E2_A4_N3_male"
    ],
    results: {
      "positive_action": {
        count: 76,
        avgSatisfaction: 7.5,
        percentage: 0.60
      },
      "stayed": {
        count: 51,
        avgSatisfaction: 6.8,
        percentage: 0.40
      }
    },
    successPatterns: [
      {
        pattern: "慎重に準備する",
        frequency: 0.75
      }
    ]
  },

  // 再利用統計
  usageCount: 145,  // 145人が使用
  ratings: {
    avgRating: 4.2,  // 平均評価
    totalRatings: 89,  // 評価した人数
    distribution: {
      "5": 45,
      "4": 28,
      "3": 12,
      "2": 3,
      "1": 1
    }
  },

  // メタデータ
  createdAt: Timestamp,
  lastUsedAt: Timestamp,
  templateId: "template_career_change_001"  // 使用したテンプレート
}
```

**Firestore Index（必須）:**
```javascript
// 複合インデックス
personalityKey ASC, concernCategory ASC, usageCount DESC
```

---

## 🆕 2. 新規追加: ユーザーの会議履歴

**個人の履歴（参照のみ保存）**

```
/users/{userId}/characters/{characterId}/meeting_history/{historyId}
{
  historyId: "history_xyz789",

  // 共有会議への参照（メインデータ）
  sharedMeetingId: "sm_abc123",  // ← これで会話内容を取得

  // ユーザー固有データ
  userConcern: "転職すべきか迷っている",  // ユーザーが実際に入力した悩み
  userBIG5: {  // 記録時点のスコア
    openness: 4,
    conscientiousness: 4,
    extraversion: 2,
    agreeableness: 4,
    neuroticism: 3
  },

  // フィードバック（shared_meetingsの評価に反映）
  userFeedback: {
    votedFor: "wise",  // 投票したキャラクター
    helpful: true,
    rating: 5  // 1-5
  },

  // メタデータ
  createdAt: Timestamp,
  viewedAt: Timestamp,

  // キャッシュヒット情報（デバッグ用）
  cacheHit: true
}
```

---

## 🆕 3. 新規追加: 会議テンプレート

ルートレベルの共有リソース（変更なし）

```
/meeting_templates/{templateId}
{
  templateId: "template_career_change_001",

  category: "career",
  subcategory: "career_change",

  conditions: {
    concernKeywords: ["転職", "仕事", "辞めたい", "キャリア"],
    big5Range: {
      conscientiousness: { min: 3, max: 5 }
    },
    priority: 1
  },

  rounds: [
    {
      roundNumber: 1,
      messages: [
        {
          speaker: "original",
          template: "転職は大きな決断だから、慎重に考えた方がいい。似た性格の{sampleSize}人のデータを見ると...",
          variables: ["sampleSize"],
          emotion: "😟"
        },
        // 6人分のメッセージ
      ]
    }
    // 3ラウンド
  ],

  conclusionPrompt: "ユーザーの悩み: {concern}\n統計データ: {stats}\n6人の会話を踏まえて、具体的なアドバイスを3つ、100文字以内で生成してください。",

  createdAt: Timestamp,
  usageCount: 0,
  lastUsed: Timestamp
}
```

---

## 🔧 4. 既存コレクションの活用

### A. users/{userId} - プレミアムチェック

**既存フィールドを使用:**
```javascript
{
  subscription: {
    status: "free" | "premium"  // ← これを使用
  }
}
```

**新規追加フィールド提案:**
```javascript
{
  usage_tracking: {
    chat_count_today: number,
    // 既存フィールド...

    // 新規追加
    six_person_meeting_count: number,  // 総使用回数
    last_meeting_date: string          // YYYY-MM-DD
  }
}
```

### B. characters/{characterId}/details/current - BIG5データ取得

**既存フィールドをそのまま使用:**
```javascript
{
  confirmedBig5Scores: {
    openness: 4,
    conscientiousness: 4,
    extraversion: 2,
    agreeableness: 4,
    neuroticism: 3
  },
  personalityKey: "O4_C4_E2_A4_N3_female"  // ← キャッシュ検索に使用
}
```

### C. Big5Analysis/{personalityKey} - 統計データソース

**既存フィールドを分析に活用:**
```javascript
{
  personality_key: "O4_C4_E2_A4_N3_female",
  career_analysis: String,      // ← テキスト分析で傾向抽出
  romance_analysis: String,
  decision_analysis: String,
  big5_scores: { ... }
}
```

### D. PersonalityStatsMetadata/summary - 統計メタデータ

**既存フィールドを活用:**
```javascript
{
  total_completed_users: 1523,
  personality_counts: {
    "O4_C4_E2_A4_N3_female": 127,
    "O4_C4_E2_A4_N2_female": 89
  }
}
```

---

## 🔍 5. データ検索ロジック（キャッシュ優先）

### メイン処理フロー

```swift
func generateOrReuseMeeting(
    userId: String,
    characterId: String,
    concern: String,
    concernCategory: String
) async throws -> String {

    // 1. ユーザーのBIG5とpersonalityKey取得
    let userDoc = try await db.collection("users").document(userId)
        .collection("characters").document(characterId)
        .collection("details").document("current")
        .getDocument()

    guard let personalityKey = userDoc.data()?["personalityKey"] as? String,
          let big5Data = userDoc.data()?["confirmedBig5Scores"] as? [String: Any],
          let userBIG5 = Big5Scores.fromScoreMap(big5Data) else {
        throw MeetingError.invalidUserData
    }

    // 2. キャッシュ検索（最重要）
    let cacheQuery = try await db.collection("shared_meetings")
        .whereField("personalityKey", isEqualTo: personalityKey)
        .whereField("concernCategory", isEqualTo: concernCategory)
        .order(by: "usageCount", descending: true)
        .limit(to: 1)
        .getDocuments()

    var sharedMeetingId: String
    var cacheHit = false

    if !cacheQuery.documents.isEmpty {
        // 3a. ✅ キャッシュヒット！（コスト0円）
        sharedMeetingId = cacheQuery.documents[0].documentID
        cacheHit = true

        // 使用回数カウントアップ
        try await db.collection("shared_meetings").document(sharedMeetingId).updateData([
            "usageCount": FieldValue.increment(Int64(1)),
            "lastUsedAt": FieldValue.serverTimestamp()
        ])

        print("✅ Cache hit! Saved AI generation cost (0.12円)")

    } else {
        // 3b. ❌ キャッシュミス → 新規生成（コスト0.12円）
        print("⚠️ Cache miss. Generating new meeting...")

        // 類似性格検索
        let similarKeys = try await findSimilarPersonalityKeys(
            userBIG5: userBIG5,
            userGender: extractGender(from: personalityKey),
            threshold: 0.85
        )

        // 統計データ算出
        let statsData = try await calculateStatsFromAnalysis(
            personalityKeys: similarKeys,
            concernCategory: concernCategory
        )

        // 会話生成（テンプレート or AI）
        let conversation = try await generateConversation(
            concern: concern,
            concernCategory: concernCategory,
            userBIG5: userBIG5,
            statsData: statsData
        )

        // shared_meetings に保存
        let sharedRef = try await db.collection("shared_meetings").addDocument(data: [
            "personalityKey": personalityKey,
            "concernCategory": concernCategory,
            "concernSubcategory": extractSubcategory(concern),
            "concernKeywords": extractKeywords(concern),
            "conversation": conversation.toDictionary(),
            "statsData": statsData.toDictionary(),
            "usageCount": 1,
            "ratings": [
                "avgRating": 0.0,
                "totalRatings": 0,
                "distribution": ["5": 0, "4": 0, "3": 0, "2": 0, "1": 0]
            ],
            "createdAt": FieldValue.serverTimestamp(),
            "lastUsedAt": FieldValue.serverTimestamp()
        ])

        sharedMeetingId = sharedRef.documentID
    }

    // 4. ユーザーの履歴に参照を保存
    let historyRef = try await db.collection("users").document(userId)
        .collection("characters").document(characterId)
        .collection("meeting_history")
        .addDocument(data: [
            "sharedMeetingId": sharedMeetingId,
            "userConcern": concern,
            "userBIG5": userBIG5.toDictionary(),
            "cacheHit": cacheHit,
            "createdAt": FieldValue.serverTimestamp()
        ])

    return historyRef.documentID
}
```

### キャッシュヒット率の予測

```
【初期（リリース直後）】
キャッシュ数: 0
キャッシュヒット率: 0%

【1週間後】
89パターン × 10カテゴリ = 約100キャッシュ
キャッシュヒット率: 10-20%

【1ヶ月後】
主要パターン500キャッシュ
キャッシュヒット率: 40-50%

【3ヶ月後】
ほぼ全パターンカバー
キャッシュヒット率: 70-80%
```

---

## 📦 6. Swift モデル定義

### Big5Scores（既存モデルを再利用）

```swift
struct Big5Scores: Codable {
    let openness: Double
    let conscientiousness: Double
    let extraversion: Double
    let agreeableness: Double
    let neuroticism: Double

    func toDictionary() -> [String: Double] {
        return [
            "openness": openness,
            "conscientiousness": conscientiousness,
            "extraversion": extraversion,
            "agreeableness": agreeableness,
            "neuroticism": neuroticism
        ]
    }

    static func fromScoreMap(_ map: [String: Any]) -> Big5Scores? {
        guard let o = (map["openness"] as? Double) ?? (map["openness"] as? Int).map(Double.init),
              let c = (map["conscientiousness"] as? Double) ?? (map["conscientiousness"] as? Int).map(Double.init),
              let e = (map["extraversion"] as? Double) ?? (map["extraversion"] as? Int).map(Double.init),
              let a = (map["agreeableness"] as? Double) ?? (map["agreeableness"] as? Int).map(Double.init),
              let n = (map["neuroticism"] as? Double) ?? (map["neuroticism"] as? Int).map(Double.init) else {
            return nil
        }
        return Big5Scores(openness: o, conscientiousness: c,
                         extraversion: e, agreeableness: a, neuroticism: n)
    }

    func similarity(to other: Big5Scores) -> Double {
        let diff = abs(openness - other.openness) +
                   abs(conscientiousness - other.conscientiousness) +
                   abs(extraversion - other.extraversion) +
                   abs(agreeableness - other.agreeableness) +
                   abs(neuroticism - other.neuroticism)
        return 1.0 - (diff / 25.0)
    }
}
```

### SharedMeeting（新規）

```swift
struct SharedMeeting: Identifiable, Codable {
    let id: String
    let personalityKey: String
    let concernCategory: String
    let concernSubcategory: String?
    let concernKeywords: [String]
    let conversation: Conversation
    let statsData: StatsData
    let usageCount: Int
    let ratings: Ratings
    let createdAt: Date
    let lastUsedAt: Date
    let templateId: String?

    struct Conversation: Codable {
        let generationType: GenerationType
        let rounds: [Round]
        let conclusion: Conclusion

        enum GenerationType: String, Codable {
            case template
            case aiGenerated = "ai_generated"
        }
    }

    struct Round: Codable {
        let roundNumber: Int
        let messages: [Message]
    }

    struct Message: Identifiable, Codable {
        let id: String
        let speaker: String
        let text: String
        let emotion: String

        enum CodingKeys: String, CodingKey {
            case id, speaker, text, emotion
        }

        init(id: String = UUID().uuidString, speaker: String, text: String, emotion: String) {
            self.id = id
            self.speaker = speaker
            self.text = text
            self.emotion = emotion
        }

        var variant: PersonalityVariant? {
            PersonalityVariant(rawValue: speaker)
        }
    }

    struct Conclusion: Codable {
        let summary: String
        let recommendations: [String]
        let votes: [String: [String]]
    }

    struct StatsData: Codable {
        let sampleSize: Int
        let similarityThreshold: Double
        let referencedPersonalityKeys: [String]
        let results: [String: Result]
        let successPatterns: [SuccessPattern]

        struct Result: Codable {
            let count: Int
            let avgSatisfaction: Double
            let percentage: Double
        }

        struct SuccessPattern: Codable {
            let pattern: String
            let frequency: Double
        }

        func toDictionary() -> [String: Any] {
            // Firestore保存用の変換
            // 実装省略
            return [:]
        }
    }

    struct Ratings: Codable {
        let avgRating: Double
        let totalRatings: Int
        let distribution: [String: Int]
    }
}
```

### MeetingHistory（新規）

```swift
struct MeetingHistory: Identifiable, Codable {
    let id: String
    let sharedMeetingId: String  // 参照
    let userConcern: String
    let userBIG5: Big5Scores
    var userFeedback: UserFeedback?
    let createdAt: Date
    var viewedAt: Date?
    let cacheHit: Bool

    struct UserFeedback: Codable {
        var votedFor: String?
        var helpful: Bool?
        var rating: Int?  // 1-5
    }

    // 会話内容を取得する関数
    func fetchSharedMeeting() async throws -> SharedMeeting {
        let db = Firestore.firestore()
        let doc = try await db.collection("shared_meetings")
            .document(sharedMeetingId)
            .getDocument()

        return try doc.data(as: SharedMeeting.self)
    }
}
```

---

## 🔐 7. セキュリティルール

```javascript
// firestore.rules

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // 共有会議（全ユーザー読み取り可能）
    match /shared_meetings/{sharedMeetingId} {
      allow read: if isAuthenticated();
      allow write: if false;  // Cloud Functionsのみ
    }

    // 会議履歴（自分のキャラクターのみ）
    match /users/{userId}/characters/{characterId}/meeting_history/{historyId} {
      allow read, write: if isOwner(userId);
    }

    // 会議テンプレート（全ユーザー読み取り専用）
    match /meeting_templates/{templateId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // Big5Analysis（全ユーザー読み取り専用、統計用）
    match /Big5Analysis/{personalityKey} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // PersonalityStatsMetadata（全ユーザー読み取り専用）
    match /PersonalityStatsMetadata/{docId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }
  }
}
```

---

## 📈 8. データフロー

### 会議生成時のデータフロー（キャッシュ優先）

```
1. ユーザーが悩みを入力
   ↓
2. Cloud Function呼び出し
   ↓
3. users/{userId} から subscription.status 確認
   ↓
4. characters/{characterId}/details/current から personalityKey 取得
   ↓
5. 【最重要】shared_meetings から検索
   WHERE personalityKey == user.personalityKey
   AND concernCategory == user.concernCategory
   ↓
6a. キャッシュヒット
    → usageCount インクリメント
    → meeting_history に参照保存
    → 完了（0円、0.5秒）
   ↓
6b. キャッシュミス
    → Big5Analysis から類似personalityKey検索
    → PersonalityStatsMetadata から人数取得
    → 統計データ算出
    → テンプレート選択 or AI生成
    → shared_meetings に保存
    → meeting_history に参照保存
    → 完了（0.12円、3-5秒）
   ↓
7. usage_tracking.six_person_meeting_count インクリメント
```

---

## 💰 9. コスト効果

### キャッシュヒット率別のコスト

```
【キャッシュヒット率 0%（初期）】
月間250会議 × 0.12円 = 30円/月

【キャッシュヒット率 50%（1ヶ月後）】
・ヒット: 125会議 × 0円 = 0円
・ミス: 125会議 × 0.12円 = 15円
合計: 15円/月（50%削減）

【キャッシュヒット率 80%（3ヶ月後）】
・ヒット: 200会議 × 0円 = 0円
・ミス: 50会議 × 0.12円 = 6円
合計: 6円/月（80%削減）
```

### 追加のメリット

```
✅ レスポンス速度: 3-5秒 → 0.5秒以下
✅ API呼び出し削減: 80%削減
✅ Firestore読み取り削減: 80%削減
✅ 人気の会議ランキング機能が作れる
✅ 高評価の会議をレコメンドできる
```

---

## 🔄 10. Phase 2: 実データ収集

### daily_choices サブコレクション（将来追加）

```
/users/{userId}/characters/{characterId}/daily_choices/{choiceId}
{
  choiceId: "choice_20251222",
  date: "2025-12-22",

  choices: [
    {
      category: "career",
      question: "転職の面接を受けますか？",
      decision: "accepted",
      feeling: "nervous",
      mood: 7
    }
  ],

  overallMood: 7.5,
  note: "緊張したけど良い経験だった",

  createdAt: Timestamp
}
```

---

## 📝 11. まとめ

### 新規追加するコレクション

1. **shared_meetings/{sharedMeetingId}** - 共有会議キャッシュ（最重要）
2. **meeting_templates/{templateId}** - 会話テンプレート
3. **users/{userId}/characters/{characterId}/meeting_history/{historyId}** - 個人履歴
4. **users/{userId}/characters/{characterId}/daily_choices/{choiceId}** - Phase 2で追加

### 既存コレクションの活用

1. **users/{userId}** - subscription.status でプレミアムチェック
2. **characters/{characterId}/details/current** - confirmedBig5Scores, personalityKey
3. **Big5Analysis/{personalityKey}** - 統計データのメインソース
4. **PersonalityStatsMetadata/summary** - サンプル数の取得

### Firestore Index（必須）

```javascript
// shared_meetings コレクション
personalityKey ASC, concernCategory ASC, usageCount DESC
```

### データ量の見積もり

```
Big5Analysis: 既存89パターン
PersonalityStatsMetadata: 1,523ユーザー分

shared_meetings: 最大 890件（89パターン × 10カテゴリ）
meeting_history: ユーザー数 × 利用回数（参照のみなので軽量）

→ 十分な統計データが既にある
→ AI生成データは不要
→ キャッシュで80%コスト削減可能
```

---

次のステップ: API設計の修正 (`05_api-design.md`)
