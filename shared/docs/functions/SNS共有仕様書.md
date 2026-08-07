# DARIAS SNS共有仕様書

**最終更新日**: 2026-08-08

---

## 概要

DARIAS では以下の画面でコンテンツをOSネイティブのシェアシートへ渡すSNS共有機能を提供する。  
共有には `share_plus` パッケージ（v10.1.4）を使用する。

### iOS実機対応の共通実装ルール

iOS 16+ で `UIActivityViewController` の `popoverPresentationController` が non-nil になる場合、origin を渡さないと `FlutterError` で無言に失敗する。  
**全シェアボタンに `GlobalKey` を付与し `sharePositionOrigin` に座標を渡すこと。**

```dart
final GlobalKey _shareButtonKey = GlobalKey();

// ボタン側
SizedBox(key: _shareButtonKey, child: /* シェアボタン */);

// 呼び出し側
final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
await Share.share(text, sharePositionOrigin: origin);
```

---

## 機能別仕様

### 1. 日記（DiaryDetailSheet）

**ソース**: `lib/presentation/screens/diary/diary_detail_screen.dart`  
**ボタン**: AppBar右上のシェアアイコン（`Icons.share`）  
**メソッド**: `_shareDiary()`  
**共有タイプ**: PNG画像 + テキスト（`Share.shareXFiles`）。画像取得失敗時（web等）はテキストのみにフォールバック

#### 画像生成の仕組み

画面ルートの `Stack` に、画面外（`Positioned(left: -9999)`）の静的シェアカードを
`RepaintBoundary`（`_shareCardKey`）で配置してキャプチャする（進化ダイアログ・ローグライク結果と同方式）。
会話アニメーション中の画面をそのまま撮ると崩れるため、共有用のカードを別に描いている。
カードは結論表示後（`_showConclusion == true`）にのみツリーへ追加する。

キャプチャ後は `getTemporaryDirectory()` に `darias_meeting.png` として保存し `XFile` として渡す。

#### シェアカードデザイン（`_MeetingShareCard`・width 360）

```
┌────────────────────────────┐
│      自分会議 — 6人の私       │
│  💭 {相談内容}（最大3行で省略）  │
│  💡 会議の結論                │
│  ┌──────────────────────┐  │
│  │ {summary 全文}         │  │
│  └──────────────────────┘  │
│  🎯 アドバイス                │
│  ┌──────────────────────┐  │
│  │ 1. / 2. / 3.          │  │
│  └──────────────────────┘  │
│  今の自分・真逆の自分・理想の自分 │
│  本音の自分・子供の頃・未来の自分 │
│           DARIAS            │
└────────────────────────────┘
背景: パステル縦グラデ(#FFF1F6→#F1F7FF)
```

- **結論サマリー（200〜300文字）は省略しない**。シェアカードは読ませるものなので、
  途中で切れているほうが体裁が悪いため。相談内容のみ3行で省略する
- **相談内容をカードに載せる**方針。共有テキストが元々全文を載せており、
  共有するかどうかはユーザー自身が決める行為であるため
- 共有中は `_isSharing = true` → ボタンをスピナー＋「準備中...」にして無効化（多重タップ防止）
- iOS の `sharePositionOrigin` を `_shareButtonKey` から算出して渡す

**共有テキスト形式**:

```
{dateString}の日記

【活動記録タイプの場合】
今日やったこと:
・{fact1}
・{fact2}
{aiComment}

【フリーテキストタイプの場合】
{content}

---
ひとこと: {userComment}  ← userComment がある場合のみ

#DARIAS #日記
```

**ハッシュタグ**: `#DARIAS #日記`

---

### 2. 自分会議（MeetingScreen）

**ソース**: `lib/presentation/screens/meeting/meeting_screen.dart`  
**ボタン**: 会議結果画面のシェアボタン  
**メソッド**: `_shareMeeting()`  
**共有タイプ**: テキストのみ（`Share.share`）

**共有テキスト形式**:

```
【自分会議の結論】

📋 相談内容:
{concern}

💡 会議の結論:
{conclusion.summary}

🎯 アドバイス:
1. {recommendation1}
2. {recommendation2}
...

---
#DARIAS #自分会議
```

**ハッシュタグ**: `#DARIAS #自分会議`

---

### 3. 性格タイプ進化ダイアログ（TypeEvolutionDialog）

**ソース**: `lib/presentation/screens/home/home_screen.dart`（`_TypeEvolutionDialog`）  
**ボタン**: ダイアログ内の「シェアする」アウトラインボタン  
**メソッド**: `_captureAndShare()`  
**共有タイプ**: PNG画像 + テキスト（`Share.shareXFiles`）。画像取得失敗時はテキストのみにフォールバック

#### 画像生成の仕組み

アニメーションレイヤー（`FadeTransition`/`ScaleTransition`）内の `RepaintBoundary` は `toImage()` と干渉するため、  
**アニメーション外（`left: -9999` に位置する静的カード）を `RepaintBoundary` でキャプチャ**して画像を生成する。

```
RepaintBoundary (key: _offscreenCardKey)
  └── _buildShareCard()  ← アニメーションなしの静的カード（Positioned left: -9999）
```

キャプチャ後は `getTemporaryDirectory()` に `darias_evolution.png` として保存し `XFile` として渡す。

#### シェアカードデザイン

```
┌────────────────────────────────────┐
│     性格タイプが変わりました          │  ← 元素カラーテキスト
│                                    │
│           🔥  (絵文字・丸)           │  ← ClipOval + 元素カラーglow
│                                    │
│            炎属性                   │  ← 元素カラー
│   場を沸かす炎タイプ になりました！  │  ← 白文字 bold
│                                    │
│   あなたの性格がより深く分析されました │  ← グレーサブテキスト
│                                    │
│              DARIAS                │  ← フッター（元素カラー薄め）
└────────────────────────────────────┘
背景: #1A1A2E / ボーダー: 元素カラー / カードwidth: 320px
```

#### 元素カラー対応表

| 元素 | カラー |
|------|-------|
| 炎 | `#FF6B35` |
| 風 | `#64B5F6` |
| 雷 | `#FFD54F` |
| 光 | `#FFF9C4` |
| 水 | `#42A5F5` |
| 土 | `#8D6E63` |
| 氷 | `#80DEEA` |
| 闇 | `#CE93D8` |
| 無 | `#B0BEC5` |

#### ボタンUI仕様

- 共有中は `_isSharing = true` → スピナー表示 + ボタン無効化（多重タップ防止）
- 完了後 `_isSharing = false`

**共有テキスト**: `DARIASで「{typeName}」になりました！ #DARIAS #性格診断`  
**ハッシュタグ**: `#DARIAS #性格診断`

---

### 4. 相性診断カテゴリ画面（CompatibilityCategoryScreen）

**ソース**: `lib/presentation/screens/friend/compatibility_category_screen.dart`  
**ボタン**: AppBar右上のシェアアイコン（`Icons.share`）。`_showResult == true` になってから出現  
**メソッド**: `_share()`  
**共有タイプ**: テキストのみ（`Share.share`）

**共有テキスト形式**:

```
{cat.icon} {friendName}との{cat.label}の相性

相性スコア: {score}%

{comment}

💡 {advice}  ← advice がある場合のみ

#DARIAS #相性診断
```

**カテゴリ別アイコン・ラベル**:

| key | label | icon |
|-----|-------|------|
| friendship | 友情 | 👫 |
| romance | 恋愛 | 💫 |
| work | 仕事 | 💼 |
| trust | 信頼 | 🤝 |

**ハッシュタグ**: `#DARIAS #相性診断`

---

### 5. ローグライク冒険結果（RoguelikeResultScreen）

**ソース**: `lib/features/roguelike/screens/roguelike_result_screen.dart`
**ボタン**: 結果画面ヘッダー右上の「シェア」ボタン（`Icons.ios_share`、`_shareButtonKey` 付き）
**メソッド**: `_captureAndShare()`
**共有タイプ**: PNG画像 + テキスト（`Share.shareXFiles`）。画像取得失敗時（web等）はテキストのみにフォールバック

#### 画像生成の仕組み

結果画面ルートの `Stack` に、画面外（`Positioned(left: -9999)`）の静的シェアカードを `RepaintBoundary`（`_shareCardKey`）で配置してキャプチャする（進化ダイアログと同方式）。

```
Stack
 ├── SingleChildScrollView（結果本体）
 └── Positioned(left: -9999) → RepaintBoundary(key: _shareCardKey) → _ShareCard
```

キャプチャ後は `getTemporaryDirectory()` に `darias_roguelike.png` として保存し `XFile` として渡す。

#### シェアカードデザイン（`_ShareCard`・width 360）

```
┌──────────────────────────────┐
│      心の迷宮 — Inner Quest      │
│        「◯◯」を克服！  (リボン)   │
│            🧑 (アバター丸)         │
│      🏅 称号 / ◯◯              │
│        🔥 炎タイプ              │
│   ⚔️挑戦性86  💗利他性72  🔍好奇心64 │
│            DARIAS              │
└──────────────────────────────┘
背景: パステル縦グラデ(#FFF1F6→#F1F7FF)
```

- 共有中は `_isSharing = true` → スピナー表示＋ボタン無効化（多重タップ防止）
- iOS の `sharePositionOrigin` を `_shareButtonKey` から算出して渡す

**共有テキスト**: `DARIAS 心の迷宮 — 「{worry}」を克服しました！\n称号「{title}」／際立った傾向: {topTrait}／元素:{element}\n#DARIAS #心の迷宮`
**ハッシュタグ**: `#DARIAS #心の迷宮`

---

## ハッシュタグ一覧

| 機能 | ハッシュタグ |
|------|-------------|
| 日記 | `#DARIAS #日記` |
| 自分会議 | `#DARIAS #自分会議` |
| 性格診断（進化ダイアログ） | `#DARIAS #性格診断` |
| 相性診断 | `#DARIAS #相性診断` |
| ローグライク（心の迷宮） | `#DARIAS #心の迷宮` |

---

## 関連ファイル

| ファイル | 共有機能 |
|---------|---------|
| `presentation/screens/diary/diary_detail_screen.dart` | 日記シェア（`_shareDiary`） |
| `presentation/screens/meeting/meeting_screen.dart` | 自分会議シェア（`_shareMeeting`） |
| `presentation/screens/home/home_screen.dart` | 進化ダイアログシェア（`_captureAndShare`、`_buildShareCard`） |
| `presentation/screens/friend/compatibility_category_screen.dart` | 相性診断シェア（`_share`） |
| `features/roguelike/screens/roguelike_result_screen.dart` | ローグライク結果シェア（`_captureAndShare`、`_ShareCard`・画像+テキスト） |
