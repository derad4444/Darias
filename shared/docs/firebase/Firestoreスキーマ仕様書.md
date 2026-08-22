# Firestore Database Schema (完全版)

> このドキュメントはFirestoreデータベースの完全なコレクション構造とフィールド定義を示しています。

**最終更新日**: 2026-08-14
**トップレベルコレクション**: 11
**主な更新**: `details/current` に `personalityKey` を明記し、保存キーとスコアがずれる条件・小数キーの是正（2026-08-14 バックフィル）を追記

---

## 目次

1. [users](#users) - ユーザーデータ
2. [Big5Analysis](#big5analysis) - BIG5性格解析マスターデータ
3. [PersonalityStatsMetadata](#personalitystatsmetadata) - 性格統計メタデータ
4. [shared_meetings](#shared_meetings) - 6人会議キャッシュ
5. [contacts](#contacts) - お問い合わせデータ
6. [system](#system) - システム設定
7. [compatibilityCache](#compatibilitycache) - 相性診断カテゴリ別キャッシュ

---

## `users`

**用途**: ユーザー情報とサブコレクション
**ドキュメントID**: Firebase Auth UID

**フィールド:**

- **name**: `string` - ユーザー名
- **email**: `string` - メールアドレス
- **character_id**: `string` - 現在のキャラクターID
- **created_at**: `timestamp` - アカウント作成日時
- **updated_at**: `timestamp` - 最終更新日時
- **emailSent**: `boolean` - 登録確認メール送信済みフラグ
- **emailMessageId**: `string` - 送信メールID
- **emailSentAt**: `timestamp` - メール送信日時
- **subscriptionStatus**: `string` - サブスクリプション状態 (`"premium"` / `"free"`)。`subscription/current` と同期。Cloud Functions・iOS PurchaseManager が書き込み
- **hasCompletedOnboarding**: `boolean` - キャラクター作成完了フラグ（アカウント登録時の初期セットアップ完了を示す。オンボーディングスライドの表示制御には使用しない）
- **hasSeenOnboardingSlides**: `boolean` - オンボーディングスライド視聴済みフラグ。`false` またはフィールドなしの場合、次回ログイン時にスライドを表示する。スキップ or 「始める！」ボタン押下時に `true` へ更新
- **characterGender**: `string` - キャラクター性別
- **growthStage**: `number` - キャラクター成長ステージ（0=赤ちゃん/1=幼少期/2=大人）。`calculateAndSaveAxisScores` が10シグナルごとに書き込む。フレンドアバター表示に使用
- **usage_tracking**: `map` - 会議機能の利用回数追跡（プレミアムユーザーのみ書き込み）
  - **meeting_count_this_month**: `number` - 今月の会議利用回数
  - **last_meeting_month**: `string` - 最後に会議を利用した月（YYYY-MM形式）。現在月と異なる場合はカウントをリセット
- **lastLoginAt**: `timestamp` - 最終ログイン日時。アプリ起動時に Flutter クライアント（`lastLoginAtSyncProvider`）が `FieldValue.serverTimestamp()` で書き込む。`scheduledDiaryGeneration` が7日以上未更新のユーザーの日記生成をスキップする際に参照。フィールドなしの既存ユーザーはスキップ対象外
- **fcmToken**: `string` - Firebase Cloud Messaging デバイストークン。ログイン後・通知許可付与後に `notification_service.dart` の `saveFcmToken()` が書き込む。`scheduledDiaryGeneration` が日記生成後にFCMプッシュ通知を送信する際に参照。トークンはデバイス再インストールや OS の更新で変わるため `onTokenRefresh` で自動更新。フィールドなしの場合は通知を送信しない
- **diaryNotificationsEnabled**: `boolean` - 日記通知のON/OFF設定。通知設定画面のトグルで書き込み（デフォルト: フィールドなし = 通知ON扱い）。`scheduledDiaryGeneration` が `false` の場合はFCM通知をスキップ

**アクセス権限**: ユーザー自身のデータのみ読み書き可

---

### `users/{userId}/characters`

**用途**: ユーザーのキャラクター情報
**ドキュメントID**: キャラクターID（UUID）

**フィールド:**

- **id**: `string` - キャラクターID
- **name**: `string` - キャラクター名
- **gender**: `string` - 性別（male/female）
- **imageSource**: `string` - 画像ソース（local/remote/firebaseStorage）
- **isDefault**: `boolean` - デフォルトキャラクターフラグ

**サブコレクション:**

#### `users/{userId}/characters/{characterId}/details`

**ドキュメントID**: `current` (固定)
**用途**: キャラクターの詳細情報と性格分析結果

**フィールド:**

- **created_at**: `timestamp` - 作成日時
- **updated_at**: `timestamp` - 更新日時
- **gender**: `string` - 性別（"male", "female", "neutral"）
- **personalityKey**: `string` - 性格タイプキー（例: "O3_C3_E3_A4_N3_男性"）
- **analysis_level**: `number` - 分析レベル（0, 20, 50, 100）
- **points**: `number` - ポイント数
- **confirmedBig5Scores**: `map` - 確定BIG5スコア
  - **openness**: `number` (1-5) - 開放性
  - **conscientiousness**: `number` (1-5) - 誠実性
  - **extraversion**: `number` (1-5) - 外向性
  - **agreeableness**: `number` (1-5) - 協調性
  - **neuroticism**: `number` (1-5) - 神経症傾向
- **big5Scores**: `map` - 前バージョンのBIG5スコア（後方互換性）
- **strength**: `string` - 性格の強み
- **weakness**: `string` - 性格の弱み
- **aptitude**: `string` - 適性
- **hobby**: `string` - 趣味
- **skill**: `string` - スキル
- **favorite_place**: `string` - お気に入りの場所
- **favorite_color**: `string` - 好きな色
- **favorite_word**: `string` - 口癖。鉤括弧・引用符を含まない素のフレーズで保存する（12文字以内・独り言としても自然に使える言い切りの形）
- **favorite_entertainment_genre**: `string` - 好きなエンターテイメントジャンル
- **word_tendency**: `string` - 話し方の特徴

> 上記のキャラクター属性は `CharacterDetailsTemplate/{personalityKey}` から複製される（同じ性格キーのユーザー間で同一の値になる）。
>
> **夢（`dream`）はこのドキュメントには保存しない。** `details` は firestore.rules で認証済みユーザーの単体取得が許可されているため、ユーザーが自由入力できる夢は本人限定の `characters/{characterId}/dream/current` に置く。移行前に生成された既存ユーザーの `dream` は残存しており、読み取り側のフォールバックに使われる。

- **sixPersonalities**: `array<map>` - 6人会議用の6つの分身データ
  - **characterId**: `string` - キャラクターID（original/opposite/ideal/shadow/child/wise）
  - **name**: `string` - キャラクター名（今の自分/真逆の自分/理想の自分/本音の自分/子供の頃の自分/未来の自分）
  - その他性格パラメータ
- **generationStatus**: `map` - キャラクター生成ステータス
  - **stage**: `number` - 生成ステージ（0/1/2/3）
  - **status**: `string` - ステータス（not_started/generating/completed/failed）
  - **message**: `string` - ステータスメッセージ
  - **startedAt**: `timestamp` - 開始日時
  - **completedAt**: `timestamp` - 完了日時
  - **failedAt**: `timestamp` - 失敗日時
  - **updatedAt**: `timestamp` - 更新日時
- **axisScores**: `map` - チャットシグナルから算出した5軸スコア（-1.0〜+1.0）。`calculateAndSaveAxisScores` が10シグナルごとに書き込む
  - **energy**: `number` - エネルギー軸（正=外向・負=内向）
  - **lifestyle**: `number` - ライフスタイル軸（正=計画的・負=自発的）
  - **relationship**: `number` - 対人関係軸（正=協調・負=独立）
  - **processing**: `number` - 情報処理軸（正=論理・負=直感）
  - **judgment**: `number` - 判断基準軸（正=安定・負=感情）
- **element**: `string` - 元素タイプ（"炎"/"風"/"雷"/"光"/"水"/"土"/"氷"/"闇"/"無"）。軸スコアから決定
- **typeName**: `string` - タイプ名（例: "場を沸かす炎タイプ"）。element と relationship/lifestyle 軸で決定
- **convertedBig5Scores**: `map` - 軸スコアから変換したBIG5スコア（1.0〜5.0）。`confirmedBig5Scores`（質問形式の診断結果）とは別フィールド
- **axisUpdatedAt**: `timestamp` - 軸スコア最終更新日時
- **axisGeneratedAt**: `timestamp` - `generateCharacterDetails` を初回実行した日時。30シグナル到達時に1回だけ設定され、初回生成の重複を防ぐガードとして機能する（以降は性格タイプの変化、または性格キーがはっきり変わったときに再生成される）
- **personalityKey**: `string` - 丸めたBig5 5値＋性別（例 `O5_C3_E4_A2_N5_女性`）。`CharacterDetailsTemplate` と `Big5Analysis` の参照キーになる

> **保存されているキーとスコアはずれることがある**: `convertedBig5Scores` は10シグナルごとに更新されるが、`personalityKey` は再生成時にしか書き換わらない。ずれが一定以上になった時点で再生成される（判定は `hasDecisiveKeyChange()`。詳細は [性格解析仕様書](../functions/性格解析仕様書.md#性格キーの変化による再生成ヒステリシス付き)）。
>
> 2026-08-14 のバックフィル以前は、丸めずに保存された小数キー（`O4.77…_C2.46…_男性`）が混在していた。現在は解消済みだが、`parsePersonalityKey()` は互換のため小数キーと旧並び順（`O3_C3_A3_E3_N3`）も読める。

#### `users/{userId}/characters/{characterId}/dream`

**ドキュメントID**: `current` (固定)
**用途**: キャラクターの夢（本人限定）

**フィールド:**

- **dream**: `string` - 現在採用中の夢（最大40文字）
- **dreamOptions**: `array<string>` - AIが性格から生成した候補5個
- **dreamSource**: `string` - 夢の由来（`"user"` = ユーザーが選択・入力 / `"ai"` = 候補から暫定採用）
- **pendingDreamProposal**: `boolean` - 性格が変わって新しい候補ができたことを示すフラグ。進化ダイアログで提案し、確認後に `false` にする
- **dreamOptionsUpdatedAt**: `timestamp` - 候補の最終更新日時
- **dreamUpdatedAt**: `timestamp` - ユーザーが夢を選択・入力した日時
- **updated_at**: `timestamp` - 更新日時

**なぜ `details` と分けているか**: `details` は firestore.rules でフレンドのアバター表示のため認証済みユーザーの単体取得が許可されている。夢はユーザーが自由入力でき、かつ他ユーザーが参照する必要がないため、本人限定ルール（`users/{userId}/{subcollection=**}`）が適用されるこのサブコレクションに置く。

**`dream` は再生成で上書きされない**: 性格タイプが変わって候補が作り直されても、ユーザーが選んだ夢はそのまま維持される。詳細は [性格解析仕様書の夢の選択フロー](../functions/性格解析仕様書.md#夢の選択フロー) を参照。

#### `users/{userId}/characters/{characterId}/personalityHistory`

**用途**: 性格タイプの変動履歴。初回元素決定時、およびタイプ変化のたびに `calculateAndSaveAxisScores` が追記する。Flutter の `PersonalityHistoryScreen` で表示される

**フィールド（各ドキュメント）:**

- **element**: `string` - 変化後の元素タイプ（"炎"/"風" など）
- **typeName**: `string` - 変化後のタイプ名（例: "場を沸かす炎タイプ"）
- **signalCount**: `number` - 記録時のシグナル数（成長段階判定に使用）
- **recordedAt**: `timestamp` - 記録日時（UIでは `recordedAt` 降順で表示）

**記録タイミング:**
1. 初回元素決定時（`prevElement === undefined` かつ `signalCount >= 30`）
2. element または typeName が変化したとき（`typeChanged && prevElement !== undefined`）

**成長段階の判定（`signalCount` から）:**
- `signalCount < 30` → 赤ちゃん期（`assets/images/character_growth/赤ちゃん.png`）
- `30 ≤ signalCount < 100` → 幼少期（`assets/images/character_growth/幼少期_{element}.png`）
- `signalCount >= 100` → 成人（`assets/images/character_growth/成人_{gender}_{element}.png`）

---

#### `users/{userId}/personalitySignals`

**用途**: チャットメッセージから抽出したパーソナリティタグを蓄積。`classifyAndExtract` がタグを含むメッセージを処理するたびに追記される
**ドキュメントID**: 自動生成

**フィールド:**

- **tags**: `array<string>` - 抽出されたパーソナリティタグ（最大3件）。有効タグ16種から選択
- **messageType**: `string` - メッセージタイプ（"chat" / "memo" / "task" 等）
- **timestamp**: `timestamp` - シグナル記録日時

**備考:**
- `calculateAndSaveAxisScores` は累積件数が10の倍数になるたびにこのコレクションを読み取って軸スコアを再計算する
- 過去90日・最大200件を使用（時間減衰あり）
- `Cloud Function (classifyAndExtract)` のみが書き込む

---

#### `users/{userId}/personalityMeta`

**ドキュメントID**: `current` (固定)
**用途**: パーソナリティシグナルのメタ情報（累積カウント・タイプ変化通知）を管理

**フィールド:**

- **signalCount**: `number` - 累積シグナル数。`savePersonalitySignal` がトランザクションでインクリメント
- **lastSignalAt**: `timestamp` - 最終シグナル記録日時
- **pendingTypeChangeNotification**: `boolean` - 元素タイプが変化した際に立つフラグ（変化時のみ存在）
- **newElement**: `string` - 変化後の元素（変化時のみ）
- **newTypeName**: `string` - 変化後のタイプ名（変化時のみ）
- **typeChangedAt**: `timestamp` - タイプ変化日時（変化時のみ）
- **pendingFirstDreamSelection**: `boolean` - 初回のキャラクター詳細生成に成功したとき `calculateAndSaveAxisScores` が立てるフラグ。ホーム画面が検知して夢の選択ダイアログを表示し、選択または「あとで選ぶ」で `false` にする
- **firstDreamReadyAt**: `timestamp` - 上記フラグを立てた日時

**備考:**
- Flutter `signalCountProvider` がこのドキュメントをリアルタイム購読し、キャラクター詳細画面の進捗表示に使用
- `_Big5AnalysisSection`（✨人格解析欄）は `signalCount >= 30` のときのみ表示される

---

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
  - **trait**: `string` - 特性
  - **direction**: `string` - 方向性
  - **value**: `number` - 回答値（1-5）
  - **answeredAt**: `timestamp` - 回答日時
- **completed**: `boolean` - 完了フラグ（100問完了時にtrue）
- **completedAt**: `timestamp` - 完了日時（完了時のみ）
- **finalScores**: `map` - 最終BIG5スコア（完了時のみ）
- **lastAskedAt**: `timestamp` - 最終質問日時

**BIG5質問の段階:**
- 段階1: 1-20問（基本分析）各特性4問ずつ
- 段階2: 21-50問（詳細分析）各特性10問ずつ
- 段階3: 51-100問（総合分析）各特性20問ずつ

#### `users/{userId}/characters/{characterId}/posts`

**用途**: チャット履歴の保存
**ドキュメントID**: 自動生成

**フィールド:**

- **content**: `string` - ユーザーのメッセージ（最大100文字）。オープナー保存時は `""` （空文字）
- **analysis_result**: `string` - キャラクターの返答（AI生成）またはオープナーテキスト
- **timestamp**: `timestamp` - 投稿日時

**ドキュメント種別:**

| 種別 | content | analysis_result |
|------|---------|----------------|
| 通常チャット | ユーザーメッセージ（最大100文字） | AI生成の返答 |
| チャットオープナー | `""` （空文字） | オープナーテキスト（1日1回保存） |

**備考:**
- メモ・タスク・予定の検出メッセージは `posts` に保存されない（各コレクションに直接保存）
- 通常チャット: `ChatDatasource._savePost()` が書き込む
- オープナー: `ChatDatasource.saveOpenerPost()` が1日1回書き込む（`SharedPreferences` の `chat_opener_saved_date` で重複防止）
- 履歴画面では `content` が空のドキュメントはユーザーバブルを非表示にしてキャラクターバブルのみ表示する

#### `users/{userId}/characters/{characterId}/meeting_history`

**用途**: 6人会議の利用履歴
**ドキュメントID**: 自動生成UUID

**フィールド:**

- **sharedMeetingId**: `string` - 共有会議ID（shared_meetingsへの参照）
- **userConcern**: `string` - ユーザーの悩み内容
- **concernCategory**: `string` - 悩みカテゴリ
- **userBIG5**: `map` - 利用時のユーザーBIG5スコア
- **cacheHit**: `boolean` - キャッシュから取得したかどうか
- **createdAt**: `timestamp` - 利用日時

#### `users/{userId}/characters/{characterId}/diary`

**用途**: キャラクターごとの日記（毎日23:50 JSTにCloud Functionが自動生成）
**ドキュメントID**: 自動生成UUID

**フィールド:**

- **id**: `string` - 日記ID
- **date**: `timestamp` - 日記の日付
- **content**: `string` - 本文（従来型日記のみ。アクティビティ型は空文字）
- **user_comment**: `string` - ユーザーが追記したコメント
- **created_at**: `timestamp` - 作成日時
- **created_date**: `string` - 作成日（YYYY-MM-DD形式、JST）
- **diary_type**: `string` *(アクティビティ型のみ)* - 日記種別。`"activity"` 固定
- **facts**: `array<string>` *(アクティビティ型のみ)* - 当日の活動を事実ベースでまとめた箇条書きリスト。`generateDiary.js` が実データから組み立てるため件数は変動し、活動がない日は空配列になる
  - 例: `["タスク「報告書作成」を完了した", "メモ「アイデアメモ」を記録した"]`
- **ai_comment**: `string` *(アクティビティ型のみ)* - キャラクターが事実に基づいて生成した前向きな一言コメント（250〜350文字）。キャラクターの個性（口癖・話し方・夢・強み）とBIG5性格を反映する。口癖は語り口の参考として扱い、本文に必ず登場するとは限らない

**diary_type の種別:**

| diary_type | 説明 |
|------------|------|
| *(フィールドなし)* | 従来型：AIがキャラクターとして書いた日記本文（`content` フィールドに格納） |
| `"activity"` | アクティビティ型：当日の活動事実（`facts`）＋AIコメント（`ai_comment`）|

**収集データソース（アクティビティ型）:**

| データ | コレクション | 条件 |
|--------|------------|------|
| デイリーミッション | `users/{uid}/dailyMissions/{YYYY-MM-DD}` | JSTの当日。`loginDone && chatCount >= 6 && diaryRead` で達成を判定 |
| チャット | `users/{uid}/characters/{cid}/posts` | `timestamp` が当日（本文はAIへ上位5件。件数は `count()` で実数） |
| 6人会議 | `users/{uid}/characters/{cid}/meeting_history` | `createdAt` が当日（上位2件） |
| 冒険（ローグライク） | `users/{uid}/roguelike_runs` | `createdAt` が当日（上位3件） |

**インデックス:**
- `date` (DESC)

---

#### `users/{userId}/characters/{characterId}/generationStatus`

**ドキュメントID**: `current` (固定)
**用途**: キャラクター生成状態の追跡（detailsにも統合済み）

---

### `users/{userId}/incomingRequests`

**用途**: 自分が受信したフレンド申請を管理
**ドキュメントID**: 申請送信者の Firebase Auth UID

**フィールド:**

- **fromUserId**: `string` - 申請を送ったユーザーのID
- **fromUserName**: `string` - 申請送信者の表示名
- **fromUserEmail**: `string` - 申請送信者のメールアドレス
- **toUserId**: `string` - 申請を受け取ったユーザーのID（自分）
- **toUserName**: `string` - 申請受信者の表示名
- **status**: `string` - ステータス（`"pending"` / `"accepted"` / `"rejected"`）
- **createdAt**: `timestamp` - 申請日時

**備考**: `sendFriendRequest` Cloud Function が申請送信者の `outgoingRequests` と申請受信者の `incomingRequests` 両方に書き込む。承認・拒否後は適宜削除される。

---

### `users/{userId}/outgoingRequests`

**用途**: 自分が送信したフレンド申請を管理
**ドキュメントID**: 申請受信者の Firebase Auth UID

**フィールド:**

- **fromUserId**: `string` - 申請を送ったユーザーのID（自分）
- **fromUserName**: `string` - 申請送信者の表示名
- **fromUserEmail**: `string` - 申請送信者のメールアドレス
- **toUserId**: `string` - 申請を受け取ったユーザーのID
- **toUserName**: `string` - 申請受信者の表示名
- **status**: `string` - ステータス（`"pending"` / `"accepted"` / `"rejected"`）
- **createdAt**: `timestamp` - 申請日時

**備考**: フレンド承認後は対応するドキュメントが削除される。

---

### `users/{userId}/compatibilityResults`

**用途**: フレンドとの相性診断結果を保存（カテゴリ別）
**ドキュメントID**: フレンドの Firebase Auth UID

**フィールド:**

- **scores**: `map` - 全カテゴリの相性スコア（BIG5から決定論的に算出）
  - **friendship**: `number` - 友情スコア（0〜100）
  - **romance**: `number` - 恋愛スコア（0〜100、上限82）
  - **work**: `number` - 仕事スコア（0〜100）
  - **trust**: `number` - 信頼スコア（0〜100）
  - **overall**: `number` - 総合スコア（0〜100）
- **unlockedCategories**: `array<string>` - 診断済みカテゴリのリスト（例: `["friendship", "romance"]`）。`FieldValue.arrayUnion` で追記される
- **friendship**: `map` *(解放済みの場合)* - 友情カテゴリの診断結果
  - **comment**: `string` - 相性コメント（30文字以内）
  - **advice**: `string` - アドバイス（60文字以内）
  - **conversation**: `array<map>` - キャラクター会話（4〜5ターン）
    - **isMyCharacter**: `boolean` - 自分のキャラクターの発言かどうか
    - **text**: `string` - セリフ
  - **big5Key**: `string` - キャッシュキー（`fp1|fp2` ソート済み）
  - **createdAt**: `timestamp` - 診断実行日時
- **romance**: `map` *(同上)*
- **work**: `map` *(同上)*
- **trust**: `map` *(同上)*

**備考**: `diagnoseCompatibility` Cloud Function が `set({merge: true})` で書き込む。スコアは再診断時に上書きされるが、カテゴリデータは蓄積される。

---

### `users/{userId}/friends`

**用途**: フレンド（相互登録ユーザー）の管理と予定共有レベル設定
**ドキュメントID**: フレンドのFirebase Auth UID

**フィールド:**

- **id**: `string` - フレンドのユーザーID
- **name**: `string` - フレンドの表示名
- **shareLevel**: `string` - フレンドへの予定公開レベル（`"none"` / `"public"` / `"full"`）
  - `none`: 予定を一切共有しない
  - `public`: `isPublic = true` かつ `isPublic = true` のタグの予定を共有
  - `full`: 非公開予定・非公開タグの予定を含めてすべて共有
- **createdAt**: `timestamp` - フレンド登録日時

**重要**: `users/{A}/friends/{B}.shareLevel` は「AがBに対して自分の予定をどのレベルで見せるか」を意味する。`getFriendSchedules` Cloud Function はこのフィールドを参照してフィルタリングを行う。

---

### `users/{userId}/askHistory`

**用途**: 「フレンドのことを聞く」機能の質問履歴。`askAboutFriend` Cloud Function が質問成功時に書き込む
**ドキュメントID**: 自動生成

**フィールド:**

- **friendId**: `string` - 質問対象のフレンドのユーザーID
- **friendName**: `string` - フレンドの表示名（書き込み時点の名前）
- **question**: `string` - 質問内容（最大100文字）
- **recommendation**: `string` - フレンドの性格から導き出した具体的なおすすめ（60文字以内）
- **conversation**: `array<map>` - キャラクター会話（4〜5ターン）
  - **isMyCharacter**: `boolean` - 自分のキャラクターの発言かどうか
  - **text**: `string` - セリフ
- **createdAt**: `timestamp` - 質問日時

**アクセス権限**: ユーザー自身のみ読み書き可（Cloud Function 経由での書き込み）

**インデックス:**
- `createdAt` (DESC)（Flutter: `askHistoryProvider` が最新50件を取得）

**備考:**
- 結果は自分の `askHistory` にのみ保存される。フレンド側からは参照できない（プライベート）
- フレンドを削除しても `askHistory` は削除されない
- 無料ユーザーの利用制限（1日1回）は Flutter の `AskFriendLimitManager`（SharedPreferences）で管理しており、Firestoreへの書き込みは行わない

---

### `users/{userId}/dailyMissions`

**用途**: デイリーミッションの進捗・達成状況を管理
**ドキュメントID**: `YYYY-MM-DD`（当日の日付文字列）

**フィールド:**

- **loginDone**: `boolean` - ログインミッション達成フラグ
- **chatCount**: `number` - 当日のチャット送信回数（上限6でカウント停止）
- **diaryRead**: `boolean` - 日記を開いたフラグ
- **allCompleted**: `boolean` - 全4ミッション達成フラグ。読み込み時は `loginDone && chatCount >= 6 && diaryRead` から再計算する（Firestoreの保存値は参照しない）
- **completedAt**: `timestamp?` - 全達成した日時

**書き込みタイミング:**
- `loginDone`: アプリ初回起動時（`_checkAndShowDailyMission`）
- `chatCount`: チャット送信成功後（`incrementChat()`）。chat6Done（chatCount >= 6）達成後はカウント停止
- `diaryRead`: デイリーミッションシートから日記を開いた時（`markDiaryRead()`）

**ミッション定義:**
| キー | 説明 | 達成条件 |
|------|------|--------|
| login | ログイン | 当日初回アプリ起動時に自動達成 |
| chat2 | チャットを2回する | chatCount >= 2 |
| chat6 | チャットを6回する | chatCount >= 6 |
| diary | 日記を確認する | デイリーミッションシートから日記を開く |

**関連ファイル:**
- `flutter/lib/data/models/daily_mission_model.dart`
- `flutter/lib/data/datasources/remote/daily_mission_datasource.dart`
- `flutter/lib/presentation/providers/daily_mission_provider.dart`
- `flutter/lib/presentation/widgets/daily_mission_sheet.dart`

---

### `users/{userId}/friendNotifications`

**用途**: フレンドが自分との相性診断を実行したことを通知するドキュメントを保管。フレンドタブの未読バッジ表示に使用
**ドキュメントID**: 通知を送ったフレンドのユーザーID

**フィールド:**

- **type**: `string` - 通知種別（現在は `"compatibility"` 固定）
- **isRead**: `boolean` - 既読フラグ（`false` = 未読。バッジ対象）
- **createdAt**: `timestamp` - 通知作成日時

**アクセス権限**: ユーザー自身のみ読み書き可

**備考:**
- `unreadCompatibilityCountProvider` が `type == "compatibility" && isRead == false` の件数をリアルタイム購読し、`friendTabBadgeCountProvider` に加算してタブバッジを表示する
- 書き込みは `diagnoseCompatibility` Cloud Function のミラーセーブ時に実行（設計済み）

---

### `users/{userId}/settings`

**用途**: ユーザーのアプリ設定（クロスデバイス・クロスプラットフォーム同期）
**ドキュメントID**: 設定種別固定

### `users/{userId}/diary`

> **⚠️ 注意**: このコレクションは旧設計のパスです。実際の日記データはキャラクターごとに管理されており、`users/{userId}/characters/{characterId}/diary` に保存されています。詳細は上記の characters サブコレクションを参照してください。

---

### `users/{userId}/subscription`

**ドキュメントID**: `current` (固定)
**用途**: サブスクリプション情報

**フィールド:**

- **status**: `string` - ステータス（"active", "cancelled", "expired", "free"）
- **plan**: `string` - プラン名（"free", "premium"）
- **payment_method**: `string` - 支払い方法（"app_store" = iOS / "google_play" = Android / "unknown"）
- **auto_renewal**: `boolean` - 自動更新フラグ
- **start_date**: `timestamp` - 開始日
- **end_date**: `timestamp | null` - 終了日
- **updated_at**: `timestamp` - 更新日時
- **product_id**: `string` - 商品ID（`com.character.premium.monthly`）※レシート検証時に書き込み

iOS（`validateAppStoreReceipt`）のみ書き込むフィールド:

- **transaction_id**: `string` - トランザクションID
- **original_transaction_id**: `string` - 初回トランザクションID

Android（`validateGooglePlayReceipt`）のみ書き込むフィールド:

- **purchase_token**: `string` - Google Play の購入トークン（Play Developer API での再検証に使用）

> レシート検証（`shared/functions/validateReceipt.js`）を経由せずクライアントがフォールバック更新した場合は、`end_date` を含む上記の一部が書き込まれない。詳細は [サブスクリプション仕様書](../architecture/サブスクリプション仕様書.md) を参照。

---

### `users/{userId}/roguelike_runs`

**用途**: ローグライク冒険ゲーム「心の迷宮」の冒険履歴（試作機能）
**ドキュメントID**: 自動採番（`add`）
**書き込み**: 冒険終了時に結果画面で1件保存（`RoguelikeDatasource.saveRun`）
**アクセス制御**: `users/{userId}/{subcollection=**}` ルールで本人のみ read/write（専用ルール追加なし）

**フィールド:**

- **characterName**: `string` - 冒険したキャラクター名
- **element**: `string` - 本編での元素タイプ
- **inferredElement**: `string` - 冒険中の行動から推定した元素（「無」あり）
- **result**: `string` - 終了種別（`clear` / `retreat` / `timeUp` / `failed`、中断時は `retreat`）
- **title**: `string` - 獲得した称号
- **topTrait**: `string` - 最も高かった行動特性名
- **traits**: `map<string,int>` - 10特性のスコア
- **growthStage**: `string` - 成長段階（`baby` / `young` / `adult`）
- **dungeonId**: `string` - 挑戦したダンジョン（悩み）のID
- **worry**: `string` - 挑戦した悩みの名前
- **enemiesDefeated**: `int` - 倒した敵の数
- **visitedCount**: `int` - 訪れたノード数（枝道式マップで通過したノードの数）
- **finalHp / finalFood / finalMoney / finalItems / finalBond**: `int` - 終了時の各リソース（`finalItems` は回復薬の所持数。`finalBond` は相棒がいた時のみ意味を持つ。相棒不在時は0）
- **hadCompanion**: `bool` - 冒険終了時点で相棒（仲間）がいたか
- **companionName**: `string` - 相棒の名前（不在時は空文字）
- **createdAt**: `timestamp` - 保存時刻（サーバ時刻）

> 詳細なゲーム仕様は `shared/docs/game/ローグライク冒険ゲーム仕様書.md` を参照。

---

### `users/{userId}/roguelike_clears`

**用途**: ローグライク「心の迷宮」で**克服した悩み（ダンジョン）の記録（心の図鑑）**
**ドキュメントID**: `dungeonId`（悩みのID。1悩み1ドキュメントで冪等）
**書き込み**: ボス撃破でダンジョンをクリアした時に結果画面で記録（`RoguelikeDatasource.recordClear`、`set(merge:true)`）
**アクセス制御**: `users/{userId}/{subcollection=**}` ルールで本人のみ read/write（専用ルール追加なし）

**フィールド:**

- **worry**: `string` - 克服した悩みの名前
- **clearedAt**: `timestamp` - 克服した時刻（サーバ時刻）

> 用途: タイトルのダンジョン選択画面で「克服済み」表示・最終ダンジョン解禁判定に使う。

---

### `users/{userId}/roguelike_meta/codex`

**用途**: ローグライク「心の迷宮」の**図鑑（出会ったイベント・敵・獲得した称号の累積）**。結果画面の「冒険で解放したもの」表示に使う。
**ドキュメントID**: 固定 `codex`（ユーザーごとに1件）
**書き込み**: 冒険終了時に結果画面で `arrayUnion` 追記（`RoguelikeDatasource.recordCodex`、`set(merge:true)`）
**アクセス制御**: `users/{userId}/{subcollection=**}` ルールで本人のみ read/write（専用ルール追加なし）

**フィールド:**

- **events**: `array<string>` - 出会ったイベントIDの累積
- **enemies**: `array<string>` - 出会った敵IDの累積
- **titles**: `array<string>` - 獲得した称号の累積

### `users/{userId}/roguelike_meta/diagnosis`

**用途**: 全踏破後の**冒険の総合診断（AI生成）**。詳細画面「冒険の性格」タブに表示。
**ドキュメントID**: 固定 `diagnosis`（ユーザーごとに1件）
**書き込み**: 「冒険の性格」タブの生成/更新ボタンで、`generateAdventureDiagnosis`（Cloud Function）の結果を保存（`RoguelikeDatasource.saveDiagnosis`、`set(merge:true)`）
**アクセス制御**: `users/{userId}/{subcollection=**}` ルールで本人のみ read/write（専用ルール追加なし）

**フィールド:**

- **summary**: `string` - 「あなたはこういう選択を多く取る」診断文
- **advice**: `string` - 「この傾向をこう活かす」助言文
- **element**: `string` - 生成時の総合推定元素
- **topTrait**: `string` - 生成時の最上位の行動特性
- **updatedAt**: `timestamp` - 生成/更新日時

### `users/{userId}/roguelike_meta/stamina`

**用途**: ダンジョン挑戦の**スタミナ**（無料は基本1回＋広告で+1回＝最大2回／プレミアムは無制限）。
**ドキュメントID**: 固定 `stamina`（ユーザーごとに1件）
**書き込み**: 「出発する」時に記録（`RoguelikeDatasource.setStamina`）。回復判定は `basePlayAt` から**24時間経過**でクライアントが行う。広告+1回は同サイクル内で有効。
**アクセス制御**: `users/{userId}/{subcollection=**}` ルールで本人のみ read/write（専用ルール追加不要）

**フィールド:**

- **basePlayAt**: `timestamp` - 基本1回を使った時刻。ここから24時間で回復（未使用/回復済みは未設定）
- **adPlayUsed**: `bool` - 現在のサイクル（基本プレイ後24時間）で広告+1回を使ったか
- **updatedAt**: `timestamp` - 更新日時

---

## `CharacterDetailsTemplate`

**用途**: 性格ごとのキャラクター属性テンプレート（全ユーザー共有・キャッシュ用）
**ドキュメントID**: `personalityKey`（`Big5Analysis` と同じ形式。例: `O3_C4_E2_A5_N1_female`）

**フィールド:**

- **personality_key**: `string` - 性格タイプのキー
- **attributes**: `map` - キャラクター属性10項目（`favorite_color` / `favorite_place` / `favorite_word` / `word_tendency` / `strength` / `weakness` / `skill` / `hobby` / `aptitude` / `favorite_entertainment_genre`）
- **dreams**: `array<string>` - 夢の候補5個
- **model**: `string` - 生成に使用したモデル（`gpt-4o-2024-11-20`）
- **updated_at**: `timestamp` - 更新日時

**共有できる理由**: `characterDetails` プロンプトの入力は「四捨五入したBIG5 5値 + 性別」だけで、これは `personalityKey` と1対1に対応する。同じキーなら送信されるプロンプトが文字列レベルで一致するため、結果を使い回せる。

**アクセス権限**: Cloud Function 専用（`firestore.rules` でクライアントからの読み書きを禁止）。各ユーザーには `details/current` と `dream/current` にコピーされる。

---

## `Big5Analysis`

**用途**: BIG5性格診断の解析結果を保存（共有・キャッシュ用）
**ドキュメントID**: `O{openness}_C{conscientiousness}_E{extraversion}_A{agreeableness}_N{neuroticism}_{gender}`
（各スコアは `Math.round()` で整数化した値。`{gender}` は `"男性"` / `"女性"` / `"neutral"`。例: `O3_C4_E2_A5_N1_女性`）

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
  - **stress**: `map` - ストレス分析
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

- **total_completed_users**: `number` - 性格診断完了（`personalityKey` 設定済み）の性格数。Firebase Authentication の全ユーザー数とは異なる（スプレッドシート表示名: 「総性格数（診断完了）」）
- **unique_personality_types**: `number` - ユニークな性格タイプ数
- **gender_distribution**: `map` - 性別分布
  - **female**: `number` - 女性（`personalityKey` が `_女性` 末尾）
  - **male**: `number` - 男性（`personalityKey` が `_男性` 末尾）
  - **neutral**: `number` - 未設定
- **personality_counts**: `map` - 各性格タイプの人数
  - **{personalityKey}**: `number` - 各性格タイプの人数（例: `"O3_C4_E2_A5_N1_女性": 3`）
- **element_counts**: `map` - 元素ごとの人数
  - **{element}**: `number` - 元素名（炎/風/雷/光/水/土/氷/闇/無）ごとの人数
- **type_name_counts**: `map` - タイプ名ごとの人数
  - **{typeName}**: `number` - タイプ名（例: `"場を沸かす炎タイプ"`, `"独り燃える炎タイプ"`）ごとの人数
- **personality_details**: `map` - `personalityKey` ごとの詳細情報
  - **{personalityKey}**: `map`
    - **element**: `string` - 元素（例: `"炎"`）
    - **typeName**: `string` - タイプ名（例: `"場を沸かす炎タイプ"`）
    - **count**: `number` - 人数

**データソース**: `recalculatePersonalityStats` Cloud Function が `collectionGroup("details")` で全ユーザーの `details/current` を走査して集計。`element`/`typeName` が Firestore 未保存の場合は `axisScores` から計算して補完。

**アクセス権限**: 認証ユーザー読み取り可、書き込みは不可（Cloud Functionのみ）

---

## `shared_meetings`

**用途**: 6人会議の共有・再利用データ（キャッシュ）
**ドキュメントID**: 自動生成UUID

**フィールド:**

- **personalityKey**: `string` - 性格キー（キャッシュマッチング用）
- **concernCategory**: `string` - 悩みカテゴリ（career, romance, money, health, family, future, hobby, study, moving, other）
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
    - **recommendations**: `array<string>` - アドバイス（3項目）

    > 過去に生成されたドキュメントには `nextSteps` フィールドが残っているが、クライアント・Cloud Functions とも参照しない。
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

**インデックス:**
- `personalityKey` (ASC) + `concernCategory` (ASC) + `usageCount` (DESC)

**アクセス権限**: 認証済みユーザーは読み取り可、書き込みは不可（Cloud Functionのみ）

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

## `system`

**用途**: アプリケーション全体の設定を格納
**ドキュメントID**: 任意（例: `config`, `settings`）

**アクセス権限**: 全ユーザー読み取り可、書き込みは不可（読み取り専用）

---

## `compatibilityCache`

**用途**: 相性診断のカテゴリ別 AI 生成結果をキャッシュ。同じ BIG5 スコアの組み合わせ × カテゴリに対して再生成を省略する
**ドキュメントID**: `{big5Fingerprint1}|{big5Fingerprint2}_{category}`（例: `o2c3e4a3n2|o3c4e3a4n2_friendship`）

**キーの生成ルール:**
- BIG5指紋形式: `o{O}c{C}e{E}a{A}n{N}`（各スコア1〜5）
- 2人の指紋をアルファベット順でソートして `|` で連結
- キャッシュは双方向で共有される（A↔B と B↔A は同じキャッシュ）

**フィールド:**

- **comment**: `string` - 相性コメント（30文字以内）
- **advice**: `string` - アドバイス（60文字以内）
- **conversation**: `array<map>` - キャラクター会話
  - **isMyCharacter**: `boolean` - 元の生成時に「自分キャラ」だったかどうか（キャッシュ再利用時は needsFlip で反転）
  - **text**: `string` - セリフ
- **big5Key**: `string` - キャッシュキー自身（冗長だが参照用）
- **createdAt**: `timestamp` - キャッシュ生成日時

**備考:**
- `diagnoseCompatibility` Cloud Function のみが書き込む（クライアントからの直接アクセス不可）
- キャッシュヒット時は `isMyCharacter` を `needsFlip` フラグで反転してから返す
- カテゴリ別（4カテゴリ）にそれぞれ独立してキャッシュされる
- 理論上のキャッシュ数: 5^10 × 4カテゴリ / 2（対称性） = 約3,900万通り（BIG5の組み合わせ爆発のため実質ヒット率は低い）

**アクセス権限**: 書き込みは Cloud Function のみ

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
         → details に confirmedBig5Scores を更新
    ↓
50問完了 → Big5Analysis に詳細分析を保存
    ↓
100問完了 → Big5Analysis に総合分析を保存
         → PersonalityStatsMetadata を更新
         → sixPersonalities を事前計算
    ↓
6人会議利用
    ↓
shared_meetings でキャッシュ検索
    ↓
キャッシュヒット → 再利用、meeting_history に記録
キャッシュミス → 新規生成、shared_meetings に保存、meeting_history に記録
```

---

## データモデルの相互関係

```
users/{userId}
├── characters/{characterId}
│   ├── details/current
│   │   ├── confirmedBig5Scores
│   │   ├── personalityKey → Big5Analysis/{key} 参照
│   │   ├── sixPersonalities[]
│   │   ├── axisScores {}          ← チャットシグナル由来（10シグナルごと更新）
│   │   ├── element                ← 元素タイプ
│   │   ├── typeName               ← タイプ名
│   │   ├── convertedBig5Scores {} ← 軸スコアから変換したBIG5
│   │   ├── axisUpdatedAt
│   │   ├── axisGeneratedAt        ← 30シグナル時に generateCharacterDetails を初回実行
│   │   └── （属性10項目）         ← CharacterDetailsTemplate/{key} から複製
│   ├── dream/current              ← 夢（本人限定。details と違い他ユーザーは読めない）
│   │   ├── dream                  ← 現在採用中の夢（再生成で上書きしない）
│   │   ├── dreamOptions []        ← 候補5個
│   │   ├── dreamSource            ← "user" / "ai"
│   │   └── pendingDreamProposal   ← 新候補ができたことを示すフラグ
│   ├── big5Progress/current
│   ├── posts/{docId}
│   ├── meeting_history/{docId}
│   │   └── sharedMeetingId → shared_meetings/{id} 参照
│   └── diary/{docId}
│       ├── [従来型] content
│       └── [アクティビティ型] diary_type / facts[] / ai_comment
├── personalitySignals/{docId}      ← チャットシグナル蓄積（新規）
│   ├── tags []
│   ├── messageType
│   └── timestamp
├── personalityMeta/current         ← シグナル集計メタ（新規）
│   ├── signalCount
│   ├── lastSignalAt
│   ├── （タイプ変化時のみ）pendingTypeChangeNotification / newElement / newTypeName
│   └── （初回詳細生成時）pendingFirstDreamSelection / firstDreamReadyAt
├── subscription/current
├── friends/{friendUserId}                  ← 新規（2026-04-17）フレンド共有設定
├── incomingRequests/{fromUserId}           ← 新規（2026-04-17）受信フレンド申請
├── outgoingRequests/{toUserId}             ← 新規（2026-04-17）送信フレンド申請
├── compatibilityResults/{friendUserId}     ← 新規（2026-04-17）相性診断結果
│   ├── scores {}
│   ├── unlockedCategories []
│   └── {category}: { comment, advice, conversation[], big5Key, createdAt }
├── askHistory/{docId}                      ← 新規（2026-05-10）フレンドのことを聞く履歴
│   ├── friendId / friendName / question
│   ├── recommendation
│   ├── conversation []
│   └── createdAt
├── friendNotifications/{friendId}          ← 相性診断通知（バッジ用）
│   ├── type ("compatibility")
│   ├── isRead
│   └── createdAt
└── diary/{docId}

shared_meetings/{id}
├── conversation
│   ├── rounds[]
│   │   └── messages[]
│   └── conclusion
├── statsData
├── ratings
└── personalityKey → Big5Analysis/{key} 参照

PersonalityStatsMetadata/summary
└── personality_counts {}

Big5Analysis/{personalityKey}
├── big5_scores {}
├── analysis_20 {}
├── analysis_50 {}
└── analysis_100 {}
```

---

## セキュリティルール要約

| コレクション | 読み取り | 書き込み |
|-------------|---------|---------|
| `users/{userId}/**` | 本人のみ | 本人のみ |
| `Big5Analysis` | 認証ユーザー | Cloud Functionのみ |
| `PersonalityStatsMetadata` | 認証ユーザー | Cloud Functionのみ |
| `shared_meetings` | 認証ユーザー | Cloud Functionのみ |
| `contacts` | 不可 | 認証ユーザー（作成のみ） |
| `system` | 全員 | 不可 |
| `compatibilityCache` | 不可（CF経由のみ） | Cloud Functionのみ |

---

**最終更新**: 2026-05-30（`ad_analytics` コレクション削除（デッドコード）；`PersonalityStatsMetadata` に `element_counts`・`type_name_counts`・`personality_details` フィールドを追加；`total_completed_users` の意味を明記）
**前回更新**: 2026-05-10（`askHistory` サブコレクション追加（「フレンドのことを聞く」履歴）；`friendNotifications` サブコレクションのスキーマ記載追加；データモデル図を更新）
**前回更新**: 2026-05-02（`users/{userId}.lastLoginAt` フィールド追加；`posts.analysis_result` の max_tokens 記述を削除）  
**前回更新**: 2026-04-19（オンボーディングスライド機能追加: `users/{userId}.hasSeenOnboardingSlides` フィールド追加；`hasCompletedOnboarding` の用途を明確化）  
**前々回更新**: 2026-04-17（フレンド予定共有機能追加: `users/{userId}/friends`・`incomingRequests`・`outgoingRequests` サブコレクション、`settings/calendarSettings` 追加、`schedules`/`tags` に `isPublic` フィールド追加；相性診断機能追加: `users/{userId}/compatibilityResults` サブコレクション、トップレベル `compatibilityCache` コレクション追加）
**作成者**: Claude Code
