# DARIAS 管理ダッシュボード（ローカル・動的）

ボタン押下ごとに集計し直して最新表示するローカルツール。上部タブで2ページを切替:
- **手帳タブ利用状況** … Firestore を直接集計（ユーザー別の利用状況）
- **性格統計** … Cloud Function `recalculatePersonalityStats` を呼び出し（旧スプレッドシート集計の置き換え）

## 起動方法

- かんたん: `~/dev/DARIAS/利用状況ダッシュボード.command` をダブルクリック（ブラウザが自動で開く）
- または: `cd ~/dev/DARIAS/shared/scripts/usage-dashboard && node server.js` → http://localhost:8799
- 停止: 起動したターミナルで `Ctrl+C`

## 表示項目（列）

| 列 | 内容 | 更新 |
|---|---|---|
| 作成日 | アカウント作成日（doc `createdAt`/`created_at`、無ければ Firebase Auth `creationTime` で補完） | 作成時に固定（変わらない） |
| 経過日数 | 今日 − 作成日 | 再集計のたびに再計算 |
| 最終ログイン | doc `lastLoginAt`（ログイン時にアプリが同期） | ログインのたびに上書き |
| 予定/メモ/ToDo/日記/合計 | 各データ件数 | 常に最新 |
| メモ最終/ToDo最終 | 各 `updatedAt` の最新 | 常に最新 |
| 最新予定日 | 予定 `startDate` の最新（編集日フィールドが無いため。未来日あり＝橙色） | 常に最新 |

- 「再集計」ボタンで即最新化。名前・メール検索、各列クリックでソート可。
- 手帳データ（予定/メモ/ToDo/日記いずれか）を1件以上持つユーザーのみ表示。

## 性格統計ページ

旧スプレッドシートの「DARIAS管理」メニューと同じ集計を表示する。
- **プレビュー（書き込みなし）**: `recalculatePersonalityStats?dryRun=true` を実行し表示のみ。Firestoreに書き込まない。
- **再集計して書き込み**: `recalculatePersonalityStats`（dryRunなし）を実行。**Firestoreの性格統計を更新する**ため確認ダイアログあり。
- 表示: 総性格数・ユニークタイプ数 / 性別分布 / 元素分布（元素合計＋サブタイプ内訳） / 性格タイプ一覧（personalityKey・元素・タイプ名・人数）。
- ページを開いた直後は自動実行しない（書き込み事故防止）。ボタンで実行する。

## 補足・制約

- **ログイン日数（何日ログインしたか）は出せない**。アプリが履歴を保持しておらず `lastLoginAt`（最終1点）のみのため。必要なら別途トラッキング実装が必要（過去分は取得不可）。
- 集計は毎回 schedules/memos/todos/diary を読むため軽微な Firestore 読み取りコストが発生する（occasional利用想定）。
- サービスアカウント鍵 `shared/functions/keys/serviceAccountKey.json` を使用。ローカル実行専用（公開しないこと）。
