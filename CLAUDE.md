# DARIAS プロジェクト Claude 指示書

## 仕様書・ドキュメント更新ルール

### コスト・トークン数の更新
仕様書のコスト見積もりやトークン数を変更する際は、**必ず実際のコードを読んで根拠を持って記載すること**。

確認必須ファイル:
- `shared/functions/src/prompts/templates.js` — 実際のプロンプト文字数
- `shared/functions/const/generateCharacterReply.js` — `max_tokens` 設定値
- `shared/functions/const/classifyAndExtract.js` — モデルとトークン設定

確認手順:
1. 対象のCloud Functionファイルを読む
2. `max_tokens` の実際の値を確認する（コメントや概算では判断しない）
3. システムプロンプトの文字数を実際にカウントする
4. `日本語: ~1.5chars/token` を使ってトークン換算する
5. 根拠を明示した上で仕様書を更新する

**「プロンプトに120文字以内と書いてあるから出力は80トークン」のような間接推論だけで数値を変更しない。**  
**コードを読まずに入力トークン数を変更しない。**

### 価格表・モデル単価の更新
モデルの料金は変動する。更新時は以下を確認してから記載すること:
- OpenAI公式の価格ページ（ユーザーに確認を促すか、最新情報源を参照する）
- 仕様書内の `モデル単価（参考）` テーブルに最終確認日を記載すること

---

## 設計・実装前の必須確認ルール

新機能の追加・既存機能の変更・バグ修正を問わず、実装に入る前に必ず以下を行うこと。

### 1. 関連ソースコードを読む
- 変更対象のファイルだけでなく、**呼び出し元・呼び出し先・関連プロバイダー**も確認する
- 既存の実装パターン（状態管理・ルーティング・データ保存方法）を把握してから新しいコードを書く
- 「おそらくこうなっているはず」という推測で実装を始めない

### 2. 関連する仕様書を読む
仕様書ディレクトリ: `shared/docs/`

| カテゴリ | パス |
|---------|------|
| 機能設計 | `shared/docs/functions/` |
| UX仕様 | `shared/docs/ux/` |

- 実装しようとしている機能の仕様書が存在する場合は**実装前に必ず読む**
- 仕様書と実装が食い違っていた場合はユーザーに報告してから進める
- 仕様書がない場合はその旨をユーザーに伝える

### 3. 実装後に仕様書を更新する
- 実装によって仕様書の内容が変わった場合は、実装完了後に仕様書も更新する
- 更新箇所は根拠（コードのファイル名・行番号・実測値）を明示する

### 4. セキュリティを確認する

実装・変更時に以下の観点を必ずチェックすること:

**Firestore / Cloud Functions:**
- Firestoreセキュリティルール（`firestore.rules`）で意図しないデータへのアクセスが生じないか
- Cloud FunctionsでユーザーID検証（`context.auth.uid`）を適切に行っているか
- 他ユーザーのデータを読み書きできる経路が生まれていないか

**Flutter クライアント:**
- ユーザー入力をそのままCloud Functionやfirestoreに渡す箇所で長さ制限・サニタイズが必要でないか
- 認証状態の確認なしにデータ取得・送信を行っていないか

**全般:**
- APIキー・シークレットをクライアントコードやログに含めていないか
- 新しい外部通信（API呼び出し等）を追加する場合はその必要性と範囲をユーザーに説明する

疑わしい点があれば実装前にユーザーに確認する。「動けばいい」で済ませない。

**コードも仕様書も読まずに「たぶんこうだろう」で実装・更新しない。**

---

## ワークフロー

- `git push` はユーザーから明示的に依頼があるまで絶対に行わない
- 動作確認前にプッシュしない
- コード変更後は毎回アプリを再起動する（Flutter Web: Chromeプロセスをosascriptで終了 → flutter run）
- ChromeはSIGKILL(-9)で終了しない（SharedPreferences/Firebase Authデータが消える）

## プロジェクト情報

- Flutter: `/Users/onoderaryousuke/Desktop/development-D/DARIAS/flutter`
- Cloud Functions: `/Users/onoderaryousuke/Desktop/development-D/DARIAS/shared/functions`
- Firebase project: `my-character-app`
- State management: Riverpod / Router: GoRouter / DB: Firestore
