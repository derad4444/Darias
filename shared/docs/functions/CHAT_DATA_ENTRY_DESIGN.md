# チャットからのデータ入力機能 設計書

> ホーム画面のチャット入力から、自然言語でメモ・タスク・予定を追加する機能の設計。

**最終更新日**: 2026-03-07
**対象ファイル**:
- `flutter/lib/data/datasources/remote/chat_datasource.dart`
- `flutter/lib/presentation/screens/home/home_screen.dart`
- `shared/functions/const/extractSchedule.js`

---

## 概要

チャット入力欄にメッセージを送ると、クライアント側でキーワードを検出し、内容に応じて **メモ / タスク / 予定** の追加フローへ自動的に振り分ける。

通常のキャラクター返答（`posts` 保存）とは独立して動作し、検出されたデータは **ユーザーの確認ダイアログを経てから** Firestore に保存される。

---

## 処理の優先順位

メッセージ送信時、以下の順序でキーワードをチェックし、最初にマッチした処理のみ実行する。

```
1. メモキーワード検出
   ↓ マッチしない
2. タスクキーワード検出
   ↓ マッチしない
3. 予定キーワード検出
   ↓ マッチしない
4. 通常チャット（generateCharacterReply を呼出 → posts 保存）
```

> **注意**: メモ・タスク・予定として処理されたメッセージは `posts` コレクションに保存されない。ただし、アクティビティ型日記の生成時（scheduledDiaryGeneration）はそれぞれのコレクションを直接参照するため日記には反映される。

---

## 1. メモ追加

### トリガーキーワード

以下のいずれかを含むメッセージが対象（完全一致ではなく `contains` で検出）:

| キーワード |
|-----------|
| `メモ` |
| `メモして` |
| `メモしといて` |
| `メモしておいて` |
| `メモしておく` |

### 処理フロー

```
ユーザー入力
    ↓
[クライアント] キーワード検出
    ↓
[クライアント] キーワードをメッセージから除去してタイトルを抽出（ローカル処理、Cloud Function 不使用）
    ↓
確認ダイアログ表示（「メモを保存しますか？」）
    ↓ 追加する → users/{userId}/memos/{autoId} に保存
    ↓ 編集する → /memo/detail 画面へ遷移
    ↓ キャンセル → 破棄
```

### タイトル抽出ロジック

キーワードを除去した残りの文字列をタイトルとする。除去後が空の場合は元のメッセージ全体をタイトルとする。

**例:**
- `「明日の会議についてメモしといて」` → タイトル: `「明日の会議について」`
- `「メモして」` → タイトル: `「メモして」`（除去後が空のため元文全体）

### 保存先

```
users/{userId}/memos/{autoId}
```

| フィールド | 値 |
|-----------|-----|
| `title` | 抽出されたタイトル |
| `content` | `""` （空文字） |
| `tag` | `""` |
| `isPinned` | `false` |
| `createdAt` | 現在日時 |
| `updatedAt` | 現在日時 |

### チャット返答

`"メモしておくね！"`（固定文）

---

## 2. タスク追加

### トリガーキーワード

| キーワード |
|-----------|
| `タスク` |
| `タスクに追加` |
| `タスク追加` |
| `やること` |
| `TODO` |
| `todo` |

### 処理フロー

```
ユーザー入力
    ↓
[クライアント] キーワード検出
    ↓
[クライアント] キーワードを除去してタイトルを抽出（ローカル処理、Cloud Function 不使用）
    ↓
確認ダイアログ表示（「タスクを追加しますか？」）
    ↓ 追加する → users/{userId}/todos/{autoId} に保存
    ↓ 編集する → /todo/detail 画面へ遷移
    ↓ キャンセル → 破棄
```

### 保存先

```
users/{userId}/todos/{autoId}
```

| フィールド | 値 |
|-----------|-----|
| `title` | 抽出されたタイトル |
| `description` | `""` |
| `isCompleted` | `false` |
| `dueDate` | `null` |
| `priority` | `"中"` |
| `tag` | `""` |
| `createdAt` | 現在日時 |
| `updatedAt` | 現在日時 |

### チャット返答

`"タスクに追加しておくね！"`（固定文）

---

## 3. 予定追加

### トリガーキーワード

以下のいずれかを含む場合に予定検出処理を実行（誤検出の可能性あり）:

| キーワード |
|-----------|
| `予定` / `スケジュール` |
| `日` / `時` |
| `から` / `まで` |
| `明日` / `今日` |
| `週` / `月` / `年` |

> **注意**: 「今日のメモ」などもキーワードにマッチする場合があるが、メモ・タスクの優先度が高いため先に処理される。予定キーワードのみの検出でも Cloud Function が呼ばれるが、`hasSchedule: false` が返れば通常チャットにフォールバックする。

### 処理フロー

```
ユーザー入力
    ↓
[クライアント] 予定キーワード検出
    ↓
[Cloud Function: extractSchedule] 呼出
    ↓ OpenAI (gpt-4o-mini) で日時・タイトル・場所を解析
    ↓
hasSchedule: false → 通常チャット処理へフォールバック
hasSchedule: true  ↓
確認ダイアログ表示（「予定を追加しますか？」）
    ↓ 追加する → users/{userId}/schedules/{autoId} に保存
    ↓ 編集する → /calendar/detail 画面へ遷移（初期値セット済み）
    ↓ キャンセル → 破棄
```

### extractSchedule Cloud Function

| 項目 | 値 |
|-----|-----|
| **関数名** | `extractSchedule` |
| **モデル** | `gpt-4o-mini` |
| **リージョン** | `asia-northeast1` |
| **メモリ** | 512MiB |
| **タイムアウト** | 120秒 |

**入力:**

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `userId` | `string` | Firebase Auth UID |
| `userMessage` | `string` | ユーザーのメッセージ |

**出力:**

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `hasSchedule` | `boolean` | 予定が検出されたか |
| `scheduleData` | `map` | 予定データ（hasSchedule: true 時のみ） |
| `scheduleData.title` | `string` | 予定タイトル |
| `scheduleData.startDate` | `Timestamp` | 開始日時（JST基準で解析） |
| `scheduleData.endDate` | `Timestamp` | 終了日時 |
| `scheduleData.isAllDay` | `boolean` | 終日フラグ（00:00-23:59 の場合自動でtrue） |
| `scheduleData.location` | `string` | 場所（任意） |
| `scheduleData.memo` | `string` | メモ（任意） |
| `scheduleData.tag` | `string` | タグ（任意） |
| `scheduleData.repeatOption` | `string` | 繰り返し（デフォルト `"none"`） |

> **注意**: Cloud Function は予定データを返すだけで Firestore には保存しない。保存はクライアント側がユーザー確認後に行う。

### 保存先

```
users/{userId}/schedules/{autoId}
```

スキーマ詳細は `FIRESTORE_SCHEMA_COMPLETE.md` の `users/{userId}/schedules` セクション参照。

### チャット返答

`"予定楽しんでね！"`（固定文）

---

## 確認ダイアログの UI

3種類とも同じ `_ActionConfirmDialog` ウィジェットを使用（`home_screen.dart`）。

| ボタン | 動作 |
|-------|------|
| **追加する** | Firestore に即時保存 → SnackBar で完了通知 |
| **編集する** | 各詳細画面へ遷移（初期値はセット済み） |
| **キャンセル** | 破棄（Firestore には保存しない） |

- 重複ダイアログ防止フラグ（`_isShowingDialog`）により同時に複数のダイアログは表示されない
- ダイアログは `barrierDismissible: false`（外タップで閉じない）

---

## 関連コレクション一覧

| 機能 | 保存先 | 処理方式 |
|-----|-------|---------|
| メモ | `users/{userId}/memos` | クライアントローカル抽出 |
| タスク | `users/{userId}/todos` | クライアントローカル抽出 |
| 予定 | `users/{userId}/schedules` | Cloud Function (extractSchedule) で解析 |
| 通常チャット | `users/{userId}/characters/{cid}/posts` | Cloud Function (generateCharacterReply) |

---

## 制約・注意事項

- メッセージの最大長は **100文字**（クライアントUI・generateCharacterReply Cloud Function 双方で制限）
- メモ・タスクの抽出はローカル処理のため、複雑な文章でもキーワード除去のみでシンプルに抽出される
- 予定検出は幅広いキーワードでトリガーされるため、意図しない Cloud Function 呼び出しが発生する場合がある（`hasSchedule: false` で通常チャットにフォールバック）
- ダイアログでキャンセルしてもキャラクターの返答（固定文）は既に表示済み
