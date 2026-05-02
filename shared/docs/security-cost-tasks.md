# セキュリティ・コスト改善タスク

**作成日**: 2026-05-02  
**優先度**: 高 → 中 → 低 の順で対応

---

## ステータス凡例
- `[ ]` 未着手
- `[~]` 対応中
- `[x]` 完了
- `[-]` 対応不要（理由付き）

---

## 🔴 優先度：高（セキュリティ）

### [x] T01: Cloud Functions に Firebase Auth チェックを追加（2026-05-02 完了）

**問題**: 全 Function で `request.auth` を検証していないため、未認証のリクエストが通る

**対象ファイル**:
- `const/classifyAndExtract.js`
- `const/generateCharacterReply.js`
- `const/answerAppQuestion.js`
- `const/extractSchedule.js`
- `const/extractFromImage.js`
- `const/searchUsers.js`
- `const/friendRequest.js`（複数 export）
- `const/getFriendSchedules.js`
- `const/diagnoseCompatibility.js`

**実装方針**（既存挙動は一切変わらない）:
```js
// 全 Function の先頭に追加するだけ
if (!request.auth) {
  throw new HttpsError("unauthenticated", "Authentication required");
}
```
正規ユーザーは常に Firebase Auth でログイン済みのため、`request.auth` は必ず存在する。  
→ 実ユーザーへの影響ゼロ。未認証の外部リクエストのみブロック。

---

### [x] T02: userId のなりすまし防止（request.auth.uid との照合）（2026-05-02 完了）

**問題**: クライアントから送られた `userId` をそのまま信頼してFirestoreを操作している

**対象ファイル**（userId を受け取りFirestoreアクセスする Function）:
- `const/generateCharacterReply.js`
- `const/answerAppQuestion.js`
- `const/extractSchedule.js`
- `const/getFriendSchedules.js`（`requestUserId` の検証）
- `const/diagnoseCompatibility.js`

**実装方針**:
```js
// T01 の認証チェックの直後に追加
if (request.auth.uid !== data.userId) {
  throw new HttpsError("permission-denied", "User ID mismatch");
}
```
正規ユーザーは自分の UID を送っているので影響ゼロ。  
別ユーザーIDを指定したなりすましリクエストのみブロック。

**注意**: `friendRequest.js` は相手のユーザーIDも扱う → 送信者側の UID のみ検証すれば OK

**対応済みだったファイル（変更不要）**:
- `searchUsers.js` — すでに `if (!auth) return {users: []};` + `auth.uid` を使用 ✅
- `friendRequest.js` — すでに `if (!auth) return {error: "Unauthorized"};` + `auth.uid` を使用 ✅
- `getFriendSchedules.js` — すでに `if (!auth) return {error: "Unauthorized"};` + `auth.uid` を使用 ✅

---

## 🔴 優先度：高（コスト）

### [x] T03: classifyAndExtract に max_tokens を追加（2026-05-02 完了）

**問題**: 唯一 `max_tokens` 未設定。通常は短い JSON を返すが、モデルが長い回答を生成するリスク

**対象ファイル**: `const/classifyAndExtract.js`

**実装方針**:
```js
// completion 呼び出しに max_tokens: 200 を追加
// schedule JSON（1件）が最長で ~150 tokens 程度
{
  model: "gpt-4o-mini",
  messages: [...],
  temperature: 0,
  max_tokens: 200,  // ← 追加
}
```

---

## 🟡 優先度：中（コスト）

### [ ] T04: generateDiary.js の当日スケジュール取得に limit() を追加

**問題**: `generateDiary.js` 内の当日スケジュール取得クエリに `.limit()` なし

**対象**: `const/generateDiary.js` 行 60-64

**実装方針**: `.limit(10)` 追加（1日の予定が10件を超えることはほぼない）

---

### [ ] T05: scheduledTasks.js の全ユーザー取得を見直し

**問題**: `db.collection("users").get()` で全ユーザーを毎日無制限読み込み

**対象**: `src/functions/scheduledTasks.js` 行 36

**実装方針**:  
日記生成が必要なユーザー（プレミアム or 一定期間内にアクティブなユーザー）に絞る条件を追加するか、  
現状のユーザー数規模であればコスト影響が軽微なため経過観察でも可。

---

## 🟢 優先度：低（セキュリティ）

### [-] T06: App Check の有効化

**現状**: 全 Function で `enforceAppCheck: false`

**対応方針**: 現時点では対応不要。  
- 開発・テスト中は App Check が邪魔になりやすい
- T01/T02 の Firebase Auth チェックで外部からの不正呼び出しはほぼブロックできる
- リリース後・ユーザー規模が大きくなった段階で検討

---

### [-] T07: Firestore ルールの読み取り範囲（意図的な設計）

**現状**: 認証済みユーザーは他ユーザーの以下を読み取れる
- `users/{userId}` の基本プロフィール（name, characterId 等）
- `characters/{characterId}/details` のキャラクター情報
- `shared_meetings/{meetingId}` の会議データ
- `Big5Analysis/{key}` の性格タイプ定義

**対応方針**: **現状維持（意図的な設計）**  
フレンド機能・相性診断・アバター表示のために必要な読み取り範囲。  
サブコレクション（予定・日記・タスク等）は `request.auth.uid == userId` で保護済み。

---

## 📋 対応順序まとめ

| タスク | 内容 | 影響範囲 | リスク |
|-------|------|---------|--------|
| T01 | Auth チェック追加 | 全 Function | **ゼロ**（正規ユーザーに影響なし） |
| T02 | userId 照合追加 | 5 Function | **ゼロ**（自分のデータを操作するだけ） |
| T03 | max_tokens 追加 | 1 Function | ゼロ |
| T04 | limit() 追加 | 1 関数 | ほぼゼロ |
| T05 | 全ユーザー取得見直し | scheduledTasks | 要検討 |
