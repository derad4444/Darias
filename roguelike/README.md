# DARIAS ローグライク試作品

## 概要

DARIASアプリに追加するローグライク型ミニゲームの試作品。
本編のキャラクターデータ（元素・成長段階）をそのまま使用し、プレイログから行動傾向を分析する。

---

## 作成ファイル一覧

### 仕様書・管理（このフォルダ）

| ファイル | 内容 |
|---------|------|
| `roguelike/README.md` | このファイル（ファイルリスト・削除手順） |
| `roguelike/docs/仕様書_v0.1.md` | ゲーム仕様書 v0.1 |

### Flutter コード

| ファイル | 内容 |
|---------|------|
| `flutter/lib/features/roguelike/models/action_log.dart` | 行動特性ログ（10特性）+ 元素推定 |
| `flutter/lib/features/roguelike/models/map_cell.dart` | マスの種別定義（9種類） |
| `flutter/lib/features/roguelike/models/game_event.dart` | イベント定義（10種類、選択肢・効果付き） |
| `flutter/lib/features/roguelike/models/enemy.dart` | 敵定義（4種類：通常3 + ボス1） |
| `flutter/lib/features/roguelike/models/game_state.dart` | ゲーム状態（リソース・マップ・フェーズ）+ マップ生成 |
| `flutter/lib/features/roguelike/providers/roguelike_provider.dart` | ゲームロジック（Riverpod StateNotifier） |
| `flutter/lib/features/roguelike/screens/roguelike_home_screen.dart` | タイトル画面（キャラ情報・ルール説明） |
| `flutter/lib/features/roguelike/screens/roguelike_game_screen.dart` | ゲーム画面（探索・イベント・戦闘） |
| `flutter/lib/features/roguelike/screens/roguelike_result_screen.dart` | 結果・冒険者分析画面 |
| `flutter/lib/features/roguelike/widgets/map_grid_widget.dart` | 4×4マップグリッドUI |
| `flutter/lib/features/roguelike/widgets/resource_bar_widget.dart` | リソースバー（HP・食料・お金・アイテム・絆） |

### 本体との接続（削除時に戻す箇所）

| ファイル | 変更内容 |
|---------|---------|
| `flutter/lib/presentation/router/app_router.dart` | import 3行 + GoRoute 3つを追加（`[ローグライク試作]` コメントで識別可能） |
| `flutter/lib/presentation/screens/home/home_screen.dart` | 「冒険」ボタン追加（`[ローグライク試作]` コメントで識別可能） |

---

## アクセス方法

アプリ起動 → ホーム画面 → 「冒険」ボタン

---

## 削除手順（没になった場合）

### 1. フォルダごと削除
```
DARIAS/roguelike/                              ← このフォルダごと削除
DARIAS/flutter/lib/features/roguelike/        ← このフォルダごと削除
```

### 2. app_router.dart から削除
`[ローグライク試作]` コメントがついたimport 3行と GoRoute 3つを削除。

### 3. home_screen.dart から削除
`[ローグライク試作]` コメントがついた SizedBox + _ActionButton 2つを削除。

---

## 現在の実装状況（MVP）

- [x] 4×4マップのランダム生成
- [x] 行動回数制限（10回）
- [x] 5リソース管理（HP・食料・お金・アイテム・絆）
- [x] イベント10種類（選択肢あり、成長段階で選択肢数が変化）
- [x] 敵4種類（通常3 + ボス1）、軽量ターン制戦闘
- [x] 行動ログ10特性の記録
- [x] 結果画面（行動傾向グラフ + 冒険者分析テキスト + 元素傾向推定）
- [x] 本編キャラクターデータ（元素・成長段階・名前）の反映

## 未実装（後回し）

- [ ] 協力プレイ・対人要素
- [ ] 複雑な装備システム
- [ ] ランキング
- [ ] AI生成による分析テキスト
- [ ] 称号・実績システム
