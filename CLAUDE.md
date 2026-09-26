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
| 削除した機能の復元手順（アーカイブ） | `shared/docs/archive/` |

`shared/docs/archive/` は現行仕様ではない。削除した機能をあとから戻すときの手引きだけを置く。
仕様書に廃止の経緯を書かない代わりに、復元に必要な情報をここへ逃がしている。

- 実装しようとしている機能の仕様書が存在する場合は**実装前に必ず読む**
- 仕様書と実装が食い違っていた場合はユーザーに報告してから進める
- 仕様書がない場合はその旨をユーザーに伝える

### 3. 実装後に仕様書を更新する（必須・毎回）

**実装完了と仕様書更新はセット。実装だけして仕様書を更新しないことは禁止。**

更新対象の仕様書を特定する手順:
1. 変更したファイルに対応する仕様書を `shared/docs/` から探す
2. 仕様書の「関連ファイル」セクションや内容から、変更が反映されるべき箇所を特定する
3. Firestoreのデータ構造が変わった場合は `shared/docs/firebase/Firestoreスキーマ.md` も更新する

更新内容に含めること:
- 変更後の動作説明（変更前の記述を上書き）
- `最終更新日` フィールドを当日日付に更新
- 根拠（コードのファイル名・変更箇所）があれば明示する

仕様書が存在しない場合はユーザーに報告し、新規作成が必要か確認する。

### 3.5. 機能を変えたら、アプリの外にある説明・素材も同じ作業の中で直す（必須・毎回）

**機能の追加・削除・名前や見た目の変更をしたら、仕様書だけでなく、その機能を説明・宣伝・撮影している場所をすべて確認して直す。**
アプリの外の説明は grep に引っかからない別リポジトリや画像にあることが多く、放っておくと古い説明が公開され続ける
（実例: 削除した冒険機能を LP が9月下旬まで宣伝していた／サポートページが「BIG5で100問に答える」のままだった／
リールの画面素材に削除済みの冒険タブが写っていた）。

| 置き場所 | 何があるか | 直し方・反映のしかた |
|---|---|---|
| アプリ内の説明 | 使い方ガイド（`help_guide_screen.dart`）・オンボーディング（`onboarding_screen.dart`）・ヒント（`hint_service.dart`） | コードを直してアプリを再起動して確認 |
| 公開ページ（正本） | `shared/docs/public/`（`support.md`・`terms-of-use.md`・`privacy-policy.md`・`index.html`） | GitHub Pages（derad4444.github.io/Darias/）に main への push で反映。**push はユーザーの指示を待つ** |
| アプリ内の写し | `terms_of_service_screen.dart`・`privacy_policy_screen.dart` | 公開ページの正本と必ず対で直す |
| Hosting 3サイト | Web版アプリ・配布ページ（`dl/`）・LP（`~/dev/DARIASLP/`・**別リポジトリ**） | それぞれデプロイ。LPは grep から漏れるので必ず見る。確認は `curl` で公開中の中身を見る |
| ストア | ストア画像（`~/dev/DARIAS/画像/ストア画像/生成スクリプト/`）・説明文 | 画像は生成スクリプトで作り直す。App Store Connect / Google Play の説明文はユーザーが手で直す（リンクを添えて案内する） |
| リール制作ツール | `~/dev/リール制作ツール/アプリ/自動投稿/` の画面素材（`assets/screens/` と `screens.json`）・台本の前提（`src/content/claude_content.py` の元素の性格・判定軸・機能の説明） | 画面はシミュレータで撮り直して差し替え、Cloud Run にデプロイ。ツール側の `docs/` 仕様書も更新する |
| Instagram | ハイライト（はじめまして・性格タイプ・AIと話してみた・使い方）・固定表示のリール | 画像や動画を作り直し、投稿と差し替えはアプリで手作業（ユーザーに手順を渡す） |

進め方:
1. 変える機能の名前・画面名・文言で、上の置き場所を検索する（別リポジトリの LP・リール制作ツールも含める）。画像や動画は検索に出ないので、機能が写っていないか目で確認する
2. 直せるものはその場で直す。ユーザーの手作業が要るもの（ストアの説明文・Instagram・push）は、最後にまとめて一覧で報告する
3. **見た目が変わった機能**（タブの追加・削除、画面構成の変更など）は、リールの画面素材・ハイライト・ストア画像に古い画面が写っていないかを必ず見る

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

**タスクリストがあっても自動で順番に進めない。各タスクの実装前に「何をどう変えるか・なぜか」をユーザーに説明し、GOをもらってから着手する。**

---

## ワークフロー

- `git push` はユーザーから明示的に依頼があるまで絶対に行わない
- 動作確認前にプッシュしない
- コード変更後は毎回アプリを再起動する
- **アプリ起動は iOSシミュレータで行う（既定）。** ユーザーから明示的にWebを指定された場合のみ Flutter Web を使う

#### iOSシミュレータ起動手順（既定・重要）

**今後アプリを起動・再起動するときは、特に指定がなければ iOSシミュレータで開くこと。**

iOS debug の App Check は `lib/main.dart` で `AppleDebugProvider`（デバッグトークンをコードに直接記載）を使うため、Webのような `--dart-define=WEB_APP_CHECK_DEBUG_TOKEN=...` は不要。

正しい手順:
1. シミュレータを起動（未起動なら）:
   ```
   open -a Simulator
   xcrun simctl boot "iPhone 16 Pro"   # 起動済みなら無視してよい
   ```
2. 既存の `flutter run`（iOS）プロセスがあれば停止してから起動する。`flutter run` でシミュレータ上に起動:
   ```
   flutter run -d "iPhone 16 Pro"
   ```
   - 接続先デバイスIDが不明なときは `flutter devices` で確認する。
   - pubspec.yaml に新パッケージを追加した場合は起動前に `cd ios && pod install` を実行する。
3. コード変更後の反映はプロセスを再起動する（`flutter run` を停止 → 再実行）。ホットリスタート（`R`）でも可だが、確実を期すなら再起動する。

#### Flutter Web 再ビルド手順（ユーザーがWebを指定した場合のみ）

**`flutter run -d chrome` を使わない。** これを使うと再ビルドのたびに新しいChromeタブ／ウィンドウが開かれてしまう（既存Chromeがプロファイルをロックしていると起動失敗もする）。Chrome自体はSIGKILL(-9)で終了しない（SharedPreferences/Firebase Authデータが消える）。

正しい手順:
1. 既存のFlutterプロセスを停止: `lsof -ti:8080 | xargs kill -9`
2. **`web-server` モードで起動**（ブラウザを自動で開かない）:
   ```
   flutter run -d web-server --web-port=8080 --dart-define=WEB_APP_CHECK_DEBUG_TOKEN=6c6674e4-dc43-4eb2-97a9-2dd004888428
   ```
3. **既存のChromeウィンドウのタブをリロードして反映**（新しいタブは開かない）:
   ```
   osascript -e 'tell application "Google Chrome"
     repeat with w in windows
       repeat with t in tabs of w
         if (URL of t) contains "localhost:8080" then tell t to reload
       end repeat
     end repeat
   end tell'
   ```

※ web-serverモードはブラウザを開かないため、再起動後は必ず上記osascriptで既存タブをリロードすること（F5リロードでも可だが手動誘導より自動リロードが確実）。Chrome自体は終了させない。

### ユーザーが自分で行う手順の案内

ユーザー自身が手動で操作しなければならない手順（ブラウザ操作・コンソール操作・アップロード・外部サービス設定など）が出てきた場合は、**該当ページへのリンクを必ず一緒に記載すること**。特定のページに直接飛べる深いリンクがある場合はそちらを優先する。

よく使うリンク:
| 操作 | リンク |
|-----|-------|
| App Store Connect（アプリ管理・審査提出） | https://appstoreconnect.apple.com |
| Transporter（IPA アップロード）| https://apps.apple.com/jp/app/transporter/id1450874784 |
| Firebase Console | https://console.firebase.google.com/project/my-character-app |
| Firebase Console → App Check | https://console.firebase.google.com/project/my-character-app/appcheck |
| Firebase Console → Functions | https://console.firebase.google.com/project/my-character-app/functions |
| Firebase Console → Firestore | https://console.firebase.google.com/project/my-character-app/firestore |
| Google reCAPTCHA Console | https://www.google.com/recaptcha/admin |

上記以外のサービス（GitHub、Google Cloud Console、各種ダッシュボード等）でもブラウザで行う作業が発生した場合は、その都度リンクを調べて記載する。

## プロジェクト情報

- Flutter: `/Users/onoderaryousuke/dev/DARIAS/flutter`
- Cloud Functions: `/Users/onoderaryousuke/dev/DARIAS/shared/functions`
- Firebase project: `my-character-app`
- State management: Riverpod / Router: GoRouter / DB: Firestore
