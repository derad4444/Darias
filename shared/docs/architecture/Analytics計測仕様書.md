# Analytics計測仕様書

**作成日**: 2026-08-19
**最終更新日**: 2026-08-19
**対象プラットフォーム**: Flutter（iOS / Android / Web）

---

## 目次

1. [概要](#概要)
2. [計測の目的](#計測の目的)
3. [個人情報の取り扱い方針](#個人情報の取り扱い方針)
4. [イベント一覧](#イベント一覧)
5. [ユーザープロパティ](#ユーザープロパティ)
6. [区分（バケット）の定義](#区分バケットの定義)
7. [ファイル構成](#ファイル構成)
8. [DebugViewでの確認方法](#debugviewでの確認方法)
9. [バージョン固定について](#バージョン固定について)

---

## 概要

Firebase Analytics を用いて、ユーザーの**離脱箇所**と**継続利用**を把握する。

| 項目 | 内容 |
|------|------|
| SDK | `firebase_analytics` 12.2.0（iOS Pod: FirebaseAnalytics 12.9.0） |
| 測定ID | `G-TNPZ5GTYE4`（`lib/firebase_options.dart`） |
| 収集の有効化 | `main.dart` で `setAnalyticsCollectionEnabled(true)` を明示 |
| 送信の窓口 | `lib/data/services/analytics_service.dart` の `AnalyticsService` **のみ** |

**画面から `FirebaseAnalytics` を直接呼ばないこと。** 送信口を1クラスに閉じることで、
チャット本文や日記本文を誤ってパラメータに渡す事故を構造的に防ぐ。

---

## 計測の目的

| 目的 | 使うイベント |
|------|-------------|
| どこで離脱しているか | `screen_view` / `sign_up` / `login` / `tutorial_begin` / `onboarding_slide_view` / `tutorial_complete` / `chat_message_sent` / `paywall_view` / `begin_checkout` / `purchase` |
| 継続して使われているか | `feature_used` ＋ 自動収集の `first_open` / `session_start` |
| セグメント別の差 | ユーザープロパティ（`element` / `growth_stage` / `signal_bucket` / `is_premium`） |

---

## 個人情報の取り扱い方針

**送信してよいもの**

- 画面名、イベント種別
- 回数・進捗の区分（バケットに丸めた値）
- 元素・成長段階・課金状態などの区分値

**送信してはいけないもの**

- uid、メールアドレス、氏名
- チャット本文、日記本文、自分会議の悩みの内容
- タグ名、フレンドID・フレンド名
- **上記の文字数**（内容推定の手掛かりになるため）

この方針に基づき **`setUserId()` は呼ばない**（Firebase Auth の UID を Analytics に渡さない）。

> 注: Firebase Analytics は端末ごとの `app_instance_id` を自動発行する。これは個人を特定する情報ではないが、
> 収集される事実としてプライバシーポリシーに記載している。
> iOS の Pod は `GoogleAppMeasurement/IdentitySupport` を含むため IDFA を扱いうるが、
> IDFA の取得は既存の AdMob 向け ATT の許諾に従う（Analytics 導入によるATT文言の変更は不要）。

---

## イベント一覧

### 自動収集（実装不要）

`first_open` / `session_start` / `app_remove` / `app_update` / `os_update` など。
継続率（維持率レポート）はこれらで確認できる。

### 実装イベント

| イベント名 | 種別 | 発火点 | パラメータ |
|-----------|------|--------|-----------|
| `screen_view` | 標準 | `app_router.dart` の `observers` に `FirebaseAnalyticsObserver` を登録 | `screen_name`（各 `GoRoute` の `name`） |
| `sign_up` | 標準 | `auth_provider.dart` `signUp()` 成功時 | `method`（現状 `email` のみ） |
| `login` | 標準 | `auth_provider.dart` `signIn()` 成功時 | `method`（現状 `email` のみ） |
| `tutorial_begin` | 標準 | `onboarding_screen.dart` `initState()` | なし |
| `onboarding_slide_view` | カスタム | `onboarding_screen.dart` `initState()`（0枚目）と `onPageChanged` | `slide_index`（0〜5） |
| `tutorial_complete` | 標準 | `onboarding_screen.dart` `_complete()` | `skipped`（`true` / `false`） |
| `chat_message_sent` | カスタム | `home_screen.dart` `_sendMessage()` 成功時 | `progress_bucket`, `phase` |
| `paywall_view` | カスタム | `premium_upgrade_screen.dart` `initState()` | `source` |
| `begin_checkout` | 標準 | `premium_upgrade_screen.dart` 購入ボタン押下時 | `value`, `currency`, `items` |
| `purchase` | 標準 | `purchase_service.dart` `PurchaseStatus.purchased` 時 | `value`, `currency`, `items` |
| `feature_used` | カスタム | 各機能の確定操作の直後 | `feature` |

#### `chat_message_sent` の補足

- **自動送信では発火しない。** `home_screen.dart` の `_triggerMeetingFollowup()`（自分会議の結論を
  自動でチャットに流す処理）はユーザーの発話ではないため計測対象外。
- `progress_bucket` は送信時点の `personalityMeta/current.signalCount` を区分に丸めた値。
  クライアントに「通算送信回数」は存在せず、これが唯一の通算進捗値のため採用している。
  ユーザープロパティ `signal_bucket` が「現在値」であるのに対し、こちらは「イベント発生時点の値」を表す。

#### `paywall_view` の `source`

課金画面への遷移は `context.push('/premium?source=...')` の形でクエリを付け、
`app_router.dart` が `PremiumUpgradeScreen(source:)` に渡す。

| `source` | 導線 |
|----------|------|
| `settings` | 設定画面のメニュー |
| `voice` | ホームの音声再生（プレミアム限定） |
| `web_chat_limit` | Web版のチャット制限ダイアログ |
| `friend_limit` | フレンド機能の制限ダイアログ |
| `meeting_banner` | 自分会議画面のバナー |
| `meeting_web_limit` | Web版の自分会議制限ダイアログ |
| `meeting_limit` | 自分会議の無料回数超過ダイアログ |
| `unknown` | `source` 未指定（想定外の遷移） |

#### `feature_used` の `feature`

機能ごとにイベント名を分けず1イベントに集約している（GA4のイベント種別上限を無駄に消費しないため）。

| `feature` | 発火点 |
|-----------|--------|
| `diary` | `diary_provider.dart` `saveUserComment()` 成功時 |
| `meeting` | `meeting_provider.dart` `generateOrReuseMeeting()` 成功時 |
| `todo` | `todo_provider.dart` `addTodo()` 成功時 |
| `calendar` | `calendar_provider.dart` `addSchedule()` 成功時 |
| `memo` | `memo_provider.dart` `addMemo()` 成功時 |
| `adventure` | `roguelike_provider.dart` `startGame()` |
| `friend` | `friend_ask_screen.dart` `_onAsk()` の質問送信後 |

---

## ユーザープロパティ

`main_shell_screen.dart` の `_syncAnalyticsSegment()` が設定する。
初回はポストフレームで1度、以降は `signalCountProvider` / `characterDetailsProvider` /
`effectiveIsPremiumProvider` の変化に `ref.listen` で追従する。

| プロパティ | 値 | 由来 |
|-----------|-----|------|
| `element` | 炎 / 風 / 雷 / 光 / 水 / 土 / 氷 / 闇 / 無 / `unknown` | `characterDetailsProvider` の `element`。シグナル30未満は未確定のため `unknown` |
| `growth_stage` | `baby` / `child` / `adult` | signalCount（30未満 / 30〜99 / 100以上） |
| `signal_bucket` | `0` / `1-9` / `10-29` / `30-99` / `100+` | signalCount |
| `is_premium` | `true` / `false` | `effectiveIsPremiumProvider` |

---

## 区分（バケット）の定義

`AnalyticsService` の静的メソッドとして定義している。

| メソッド | 区分 |
|---------|------|
| `signalBucket(int)` | `0` / `1-9` / `10-29` / `30-99` / `100+` |
| `growthStage(int)` | `baby`(<30) / `child`(30〜99) / `adult`(100〜) |

境界の 30 / 100 は `presentation/widgets/character/element_effect_widget.dart` の
`characterGrowthAssetPath()`（赤ちゃん / 幼少期 / 成人の切り替え条件）と一致させている。
**片方を変更したら必ずもう片方も合わせること。**

---

## ファイル構成

| ファイル | 役割 |
|---------|------|
| `lib/data/services/analytics_service.dart` | 送信の唯一の窓口。イベント定義・バケット定義 |
| `lib/main.dart` | `AnalyticsService.instance.initialize()` |
| `lib/presentation/router/app_router.dart` | `observers` にオブザーバー登録。`/premium` の `source` 受け渡し |
| `lib/presentation/screens/main/main_shell_screen.dart` | ユーザープロパティの同期 |
| `lib/presentation/screens/onboarding/onboarding_screen.dart` | オンボーディング3イベント |
| `lib/presentation/screens/home/home_screen.dart` | `chat_message_sent` |
| `lib/presentation/screens/premium/premium_upgrade_screen.dart` | `paywall_view` / `begin_checkout` |
| `lib/data/services/purchase_service.dart` | `purchase` |
| `lib/presentation/providers/*_provider.dart` | `sign_up` / `login` / `feature_used` |

---

## DebugViewでの確認方法

iOSシミュレータでは、起動引数 `-FIRDebugEnabled` を付けたときだけ DebugView に流れる。

```bash
# 1. シミュレータ用にビルド
flutter build ios --simulator --debug

# 2. インストール
xcrun simctl install booted build/ios/iphonesimulator/Runner.app

# 3. デバッグモードで起動（この引数が DebugView を有効にする）
xcrun simctl launch booted com.Derao.Character -FIRDebugEnabled

# 4. 送信ログを確認
xcrun simctl spawn booted log stream --style compact \
  --predicate 'eventMessage CONTAINS "FIRAnalytics" OR subsystem CONTAINS "com.google.firebase"'
```

`-FIRDebugDisabled` を付けて起動すると解除できる。

Firebase Console → [DebugView](https://console.firebase.google.com/project/my-character-app/analytics/app/ios:com.Derao.Character/debugview)

### ログに頼らず実測する方法（推奨）

Analytics SDK のイベントログは `log stream` に出ないことがあるため、SDK がシミュレータ内に持つ
ローカルDBとplistを直接読むのが確実。**イベントが記録されたか**と**Firebaseへ送信できたか**を分けて確認できる。

```bash
DEV=<simulator-udid>
C=$(xcrun simctl get_app_container $DEV com.Derao.Character data)

# 記録されたイベントと発火時刻（_vs=screen_view / _f=first_open / _s=session_start）
sqlite3 -header -column \
  "$C/Library/Application Support/Google/Measurement/google-app-measurement.sql" \
  "SELECT name, lifetime_count, datetime(last_fire_timestamp,'unixepoch','+9 hours') FROM events;"

# 設定済みユーザープロパティ（origin='app' が自前で設定したもの）
sqlite3 -column \
  "$C/Library/Application Support/Google/Measurement/google-app-measurement.sql" \
  "SELECT name, origin FROM user_attributes WHERE origin='app';"

# 送信結果（last_successful_upload が更新され、last_failed_upload が 0 なら成功）
plutil -p "$C/Library/Application Support/Google/Measurement/com.google.gmp.measurement.plist"
```

`app_instance_id`（上記plist内）が DebugView に表示される端末の識別子と一致する。

---

## バージョン固定について

`pubspec.yaml` の `firebase_analytics` は **`^` を付けずに `12.2.0` で固定**している。

`^12.2.0` にすると `firebase_analytics` の最新版が `firebase_core ^4.13.0` を要求し、
`firebase_core` / `cloud_firestore` / `firebase_auth` など Firebase プラグイン一式が
一括アップグレードされてしまうため。12.2.0 は現在の `firebase_core 4.6.0` に正確に対応する。

Firebase プラグインをまとめて更新する際は、この固定も併せて見直すこと。
