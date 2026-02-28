# Character アプリ クロスプラットフォーム設計書

## 概要

本ドキュメントは、既存のiOS版Characterアプリを Flutter で再構築し、iOS/Android/Web の3プラットフォームに展開するための設計書です。

---

## 1. アーキテクチャ全体図

```
┌─────────────────────────────────────────────────────────────────────┐
│                         クライアント層                                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Flutter Application                         │  │
│  │                                                                 │  │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │  │
│  │   │   iOS App   │  │ Android App │  │   Web App   │           │  │
│  │   │  (App Store)│  │(Google Play)│  │  (ブラウザ)  │           │  │
│  │   └─────────────┘  └─────────────┘  └─────────────┘           │  │
│  │          │                │                │                   │  │
│  │          └────────────────┼────────────────┘                   │  │
│  │                           │                                    │  │
│  │   ┌───────────────────────▼───────────────────────┐           │  │
│  │   │              共通ビジネスロジック層               │           │  │
│  │   │  • State Management (Riverpod)                │           │  │
│  │   │  • Repository Pattern                         │           │  │
│  │   │  • Use Cases                                  │           │  │
│  │   └───────────────────────────────────────────────┘           │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Firebase SDK
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         バックエンド層 (変更なし)                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Firebase Project                            │  │
│  │                                                                 │  │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │  │
│  │   │  Firestore  │  │   Storage   │  │    Auth     │           │  │
│  │   │   (既存DB)   │  │  (画像保存)  │  │  (認証)     │           │  │
│  │   └─────────────┘  └─────────────┘  └─────────────┘           │  │
│  │                                                                 │  │
│  │   ┌─────────────────────────────────────────────┐             │  │
│  │   │         Cloud Functions (Node.js 20)        │             │  │
│  │   │  • generateCharacterReply (AI返信)          │             │  │
│  │   │  • extractSchedule (予定抽出)               │             │  │
│  │   │  • generateVoice (音声合成)                 │             │  │
│  │   │  • generateBig5Analysis (BIG5解析)          │             │  │
│  │   │  • generateOrReuseMeeting (6人会議)         │             │  │
│  │   │  • validateAppStoreReceipt (iOS課金検証)    │             │  │
│  │   │  • validateGooglePlayReceipt (Android検証)  │             │  │
│  │   │  • checkSubscriptionStatus (日次期限チェック)│             │  │
│  │   │  • scheduledDiaryGeneration (日記自動生成)   │             │  │
│  │   │  • generateMonthlyReview (月次レビュー)      │             │  │
│  │   │  • sendRegistrationEmail (登録メール)        │             │  │
│  │   │  • sendContactEmail (問い合わせメール)       │             │  │
│  │   │  → 詳細: docs/CLOUD_FUNCTIONS_DESIGN.md     │             │  │
│  │   └─────────────────────────────────────────────┘             │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 技術スタック

### Flutter側

| カテゴリ | 技術/パッケージ | 用途 |
|---------|--------------|------|
| **言語** | Dart 3.x | メイン開発言語 |
| **状態管理** | Riverpod 2.x | アプリ全体の状態管理 |
| **ルーティング** | go_router | 宣言的ルーティング |
| **Firebase** | FlutterFire | Firebase連携 |
| | firebase_core | 初期化 |
| | cloud_firestore | データベース |
| | firebase_auth | 認証 |
| | firebase_storage | 画像ストレージ |
| | cloud_functions | Cloud Functions呼び出し |
| **課金** | in_app_purchase | iOS/Android課金 |
| | purchases_flutter (RevenueCat) | 課金管理の簡素化 |
| **広告** | google_mobile_ads | AdMob広告 |
| **ローカルDB** | drift (SQLite) | オフラインキャッシュ |
| **UI** | flutter_hooks | Reactライクなフック |
| | cached_network_image | 画像キャッシュ |
| | flutter_animate | アニメーション |
| **通知** | firebase_messaging | プッシュ通知 |
| | flutter_local_notifications | ローカル通知 |

### バックエンド側 (変更不要)

- Firebase Cloud Functions (Node.js 20)
- Firestore
- Firebase Storage
- Firebase Auth
- Firebase App Check

---

## 3. ディレクトリ構成

```
character_flutter/
├── lib/
│   ├── main.dart                      # エントリーポイント
│   ├── app.dart                       # アプリ設定
│   │
│   ├── core/                          # 共通基盤
│   │   ├── constants/                 # 定数定義
│   │   │   ├── app_constants.dart
│   │   │   ├── firebase_constants.dart
│   │   │   └── subscription_constants.dart
│   │   ├── errors/                    # エラー定義
│   │   │   ├── exceptions.dart
│   │   │   └── failures.dart
│   │   ├── extensions/                # 拡張メソッド
│   │   │   ├── date_extensions.dart
│   │   │   └── string_extensions.dart
│   │   ├── utils/                     # ユーティリティ
│   │   │   ├── logger.dart
│   │   │   └── validators.dart
│   │   └── theme/                     # テーマ設定
│   │       ├── app_theme.dart
│   │       ├── colors.dart
│   │       └── typography.dart
│   │
│   ├── data/                          # データ層
│   │   ├── models/                    # データモデル
│   │   │   ├── user_model.dart
│   │   │   ├── character_model.dart
│   │   │   ├── big5_model.dart
│   │   │   ├── post_model.dart
│   │   │   ├── schedule_model.dart
│   │   │   ├── diary_model.dart
│   │   │   ├── todo_model.dart
│   │   │   ├── memo_model.dart
│   │   │   └── subscription_model.dart
│   │   ├── datasources/               # データソース
│   │   │   ├── remote/
│   │   │   │   ├── firestore_datasource.dart
│   │   │   │   ├── auth_datasource.dart
│   │   │   │   ├── storage_datasource.dart
│   │   │   │   └── functions_datasource.dart
│   │   │   └── local/
│   │   │       └── cache_datasource.dart
│   │   └── repositories/              # リポジトリ実装
│   │       ├── auth_repository_impl.dart
│   │       ├── character_repository_impl.dart
│   │       ├── chat_repository_impl.dart
│   │       ├── schedule_repository_impl.dart
│   │       ├── diary_repository_impl.dart
│   │       ├── todo_repository_impl.dart
│   │       └── subscription_repository_impl.dart
│   │
│   ├── domain/                        # ドメイン層
│   │   ├── entities/                  # エンティティ
│   │   │   ├── user.dart
│   │   │   ├── character.dart
│   │   │   ├── big5_analysis.dart
│   │   │   ├── post.dart
│   │   │   ├── schedule.dart
│   │   │   ├── diary.dart
│   │   │   ├── todo.dart
│   │   │   └── subscription.dart
│   │   ├── repositories/              # リポジトリインターフェース
│   │   │   ├── auth_repository.dart
│   │   │   ├── character_repository.dart
│   │   │   ├── chat_repository.dart
│   │   │   ├── schedule_repository.dart
│   │   │   ├── diary_repository.dart
│   │   │   ├── todo_repository.dart
│   │   │   └── subscription_repository.dart
│   │   └── usecases/                  # ユースケース
│   │       ├── auth/
│   │       │   ├── sign_in_usecase.dart
│   │       │   ├── sign_up_usecase.dart
│   │       │   └── sign_out_usecase.dart
│   │       ├── character/
│   │       │   ├── get_character_usecase.dart
│   │       │   └── update_character_usecase.dart
│   │       ├── chat/
│   │       │   ├── send_message_usecase.dart
│   │       │   └── get_chat_history_usecase.dart
│   │       ├── big5/
│   │       │   ├── submit_answer_usecase.dart
│   │       │   └── get_analysis_usecase.dart
│   │       └── six_person_meeting/
│   │           └── generate_meeting_usecase.dart
│   │
│   ├── presentation/                  # プレゼンテーション層
│   │   ├── providers/                 # Riverpod Providers
│   │   │   ├── auth_provider.dart
│   │   │   ├── character_provider.dart
│   │   │   ├── chat_provider.dart
│   │   │   ├── schedule_provider.dart
│   │   │   ├── diary_provider.dart
│   │   │   ├── todo_provider.dart
│   │   │   ├── subscription_provider.dart
│   │   │   └── settings_provider.dart
│   │   ├── router/                    # ルーティング
│   │   │   └── app_router.dart
│   │   ├── screens/                   # 画面
│   │   │   ├── splash/
│   │   │   ├── onboarding/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── register_screen.dart
│   │   │   ├── home/
│   │   │   │   └── home_screen.dart
│   │   │   ├── character/
│   │   │   │   ├── character_select_screen.dart
│   │   │   │   └── character_detail_screen.dart
│   │   │   ├── chat/
│   │   │   │   └── chat_screen.dart
│   │   │   ├── big5/
│   │   │   │   ├── big5_intro_screen.dart
│   │   │   │   ├── big5_question_screen.dart
│   │   │   │   └── big5_result_screen.dart
│   │   │   ├── six_person_meeting/
│   │   │   │   └── meeting_screen.dart
│   │   │   ├── schedule/
│   │   │   │   ├── calendar_screen.dart
│   │   │   │   └── schedule_edit_screen.dart
│   │   │   ├── diary/
│   │   │   │   ├── diary_list_screen.dart
│   │   │   │   └── diary_edit_screen.dart
│   │   │   ├── todo/
│   │   │   │   └── todo_screen.dart
│   │   │   ├── memo/
│   │   │   │   └── memo_screen.dart
│   │   │   ├── settings/
│   │   │   │   ├── settings_screen.dart
│   │   │   │   ├── subscription_screen.dart
│   │   │   │   └── account_screen.dart
│   │   │   └── contact/
│   │   │       └── contact_screen.dart
│   │   └── widgets/                   # 共通ウィジェット
│   │       ├── common/
│   │       │   ├── app_button.dart
│   │       │   ├── app_text_field.dart
│   │       │   ├── loading_indicator.dart
│   │       │   └── error_dialog.dart
│   │       ├── character/
│   │       │   ├── character_avatar.dart
│   │       │   └── personality_badge.dart
│   │       ├── chat/
│   │       │   ├── chat_bubble.dart
│   │       │   └── chat_input.dart
│   │       ├── ads/
│   │       │   ├── banner_ad_widget.dart
│   │       │   └── rewarded_ad_manager.dart
│   │       └── calendar/
│   │           └── calendar_widget.dart
│   │
│   └── services/                      # 外部サービス
│       ├── analytics_service.dart
│       ├── notification_service.dart
│       ├── purchase_service.dart
│       └── ad_service.dart
│
├── test/                              # テスト
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── web/                               # Web固有設定
│   └── index.html
│
├── android/                           # Android固有設定
│   └── app/
│       └── build.gradle
│
├── ios/                               # iOS固有設定
│   └── Runner/
│       └── Info.plist
│
├── pubspec.yaml                       # 依存関係
└── firebase.json                      # Firebase設定
```

---

## 4. データモデル移行マッピング

### Swift → Dart 変換例

#### Character Model

**Swift (既存)**
```swift
struct CharacterModels {
    struct Character: Codable, Identifiable {
        let id: String
        var name: String
        var gender: String
        var big5Scores: Big5Scores?
        var personalityKey: String?
        var createdAt: Date
        var updatedAt: Date
    }

    struct Big5Scores: Codable {
        var openness: Double
        var conscientiousness: Double
        var extraversion: Double
        var agreeableness: Double
        var neuroticism: Double
    }
}
```

**Dart (新規)**
```dart
// lib/data/models/character_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_model.freezed.dart';
part 'character_model.g.dart';

@freezed
class CharacterModel with _$CharacterModel {
  const factory CharacterModel({
    required String id,
    required String name,
    required String gender,
    Big5ScoresModel? big5Scores,
    String? personalityKey,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CharacterModel;

  factory CharacterModel.fromJson(Map<String, dynamic> json) =>
      _$CharacterModelFromJson(json);

  factory CharacterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CharacterModel(
      id: doc.id,
      name: data['name'] ?? '',
      gender: data['gender'] ?? '',
      big5Scores: data['big5Scores'] != null
          ? Big5ScoresModel.fromJson(data['big5Scores'])
          : null,
      personalityKey: data['personalityKey'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

@freezed
class Big5ScoresModel with _$Big5ScoresModel {
  const factory Big5ScoresModel({
    required double openness,
    required double conscientiousness,
    required double extraversion,
    required double agreeableness,
    required double neuroticism,
  }) = _Big5ScoresModel;

  factory Big5ScoresModel.fromJson(Map<String, dynamic> json) =>
      _$Big5ScoresModelFromJson(json);
}
```

---

## 5. 主要機能の移行計画

### Phase 1: 基盤構築 (必須)

| 機能 | 内容 | 優先度 |
|-----|------|-------|
| Firebase初期化 | core, auth, firestore, storage 接続 | 🔴 最高 |
| 認証 | ログイン/サインアップ/ログアウト | 🔴 最高 |
| キャラクター選択 | 性別選択、キャラクター表示 | 🔴 最高 |
| ホーム画面 | メインナビゲーション | 🔴 最高 |

### Phase 2: コア機能

| 機能 | 内容 | 優先度 |
|-----|------|-------|
| チャット | キャラクターとの会話、履歴表示 | 🟠 高 |
| BIG5診断 | 質問表示、回答保存、結果表示 | 🟠 高 |
| 6人会議 | Cloud Functions呼び出し、結果表示 | 🟠 高 |

### Phase 3: サブ機能

| 機能 | 内容 | 優先度 |
|-----|------|-------|
| カレンダー | スケジュール CRUD | 🟡 中 |
| 日記 | 日記 CRUD | 🟡 中 |
| Todo | タスク管理 | 🟡 中 |
| メモ | メモ CRUD | 🟡 中 |

### Phase 4: 収益化・その他

| 機能 | 内容 | 優先度 |
|-----|------|-------|
| 課金 | サブスクリプション管理 | 🟢 高 |
| 広告 | バナー広告、リワード広告 | 🟢 高 |
| 設定 | フォント、テーマ、アカウント | 🟢 中 |
| 通知 | プッシュ通知、ローカル通知 | 🟢 中 |
| ウィジェット | iOS/Androidホーム画面ウィジェット | 🔵 低 |

---

## 6. プラットフォーム別の注意点

### iOS
- App Store 審査ガイドラインに準拠
- App Tracking Transparency (ATT) 対応
- StoreKit 2 から in_app_purchase への移行
- ウィジェット: home_widget パッケージ使用

### Android
- Google Play 審査ガイドラインに準拠
- Google Play Billing Library 対応
- 通知チャンネル設定
- バックグラウンド制限対応

### Web
- Firebase Hosting でデプロイ
- PWA対応 (Service Worker)
- Stripe決済 (アプリ内課金の代替)
- 広告: Google AdSense に変更
- レスポンシブデザイン対応

---

## 7. 課金システム設計

```
┌─────────────────────────────────────────────────────────────────┐
│                      課金フロー                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   iOS/Android                     Web                           │
│   ┌─────────────┐                ┌─────────────┐               │
│   │ RevenueCat  │                │   Stripe    │               │
│   │    SDK      │                │  Checkout   │               │
│   └──────┬──────┘                └──────┬──────┘               │
│          │                              │                       │
│          │    ┌───────────────────┐     │                       │
│          └────►  Firebase         ◄─────┘                       │
│               │  Cloud Functions  │                             │
│               │  (Webhook処理)    │                             │
│               └─────────┬─────────┘                             │
│                         │                                       │
│                         ▼                                       │
│               ┌───────────────────┐                             │
│               │    Firestore      │                             │
│               │ users/{id}/       │                             │
│               │ subscription/     │                             │
│               │ current           │                             │
│               └───────────────────┘                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### RevenueCat を推奨する理由
- iOS/Android の課金を統一API で管理
- サーバーサイド検証が自動
- ダッシュボードで売上分析
- Firestore との連携が容易

---

## 8. 移行スケジュール (目安)

```
Week 1-2:   プロジェクトセットアップ、Firebase接続、認証
Week 3-4:   キャラクター選択、ホーム画面
Week 5-6:   チャット機能
Week 7-8:   BIG5診断
Week 9-10:  6人会議
Week 11-12: カレンダー、日記、Todo、メモ
Week 13-14: 課金、広告
Week 15-16: 設定、通知、テスト
Week 17-18: バグ修正、審査対応
```

---

## 9. テスト戦略

| テストタイプ | ツール | 対象 |
|------------|-------|------|
| Unit Test | flutter_test | ビジネスロジック、モデル |
| Widget Test | flutter_test | UIコンポーネント |
| Integration Test | integration_test | E2Eフロー |
| Golden Test | golden_toolkit | UIスナップショット |

---

## 10. CI/CD パイプライン

```yaml
# GitHub Actions の例
name: Flutter CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build ios --release --no-codesign

  build-web:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
```

---

## 11. 既存iOSアプリからの段階的移行

### オプションA: 完全置き換え (推奨)
1. Flutter版を新規開発
2. 同じFirebaseプロジェクトに接続
3. 既存ユーザーはそのままログイン可能
4. App Store で既存アプリを更新

### オプションB: 並行運用
1. Flutter版を別アプリとしてリリース
2. 既存iOSアプリは保守モード
3. 新規ユーザーはFlutter版へ誘導

**推奨**: オプションA (1コードベースのメリットを最大化)

---

## 12. まとめ

### この設計の利点

1. **単一コードベース**: 1回の改修で iOS/Android/Web に反映
2. **DB共通**: 既存Firestoreをそのまま使用
3. **バックエンド変更不要**: Cloud Functionsは完全流用
4. **保守性向上**: 今後の機能追加が1箇所で完結
5. **コスト削減**: 3つ別々に開発するより大幅に低コスト

### 次のアクション

1. Flutter 開発環境のセットアップ
2. プロジェクト作成 (`flutter create character_flutter`)
3. Firebase 接続設定
4. Phase 1 の実装開始

---

*最終更新: 2026-01-16*
