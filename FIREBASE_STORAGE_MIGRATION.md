# Firebase Storage画像移行ガイド

## 📋 概要

このガイドでは、Character アプリの画像を Assets.xcassets から Firebase Storage に移行する手順を説明します。

## 🎯 移行の目的

- **アプリサイズ削減**: 2.8GB → 約20MB（約2.78GB削減）
- **オンデマンド読み込み**: 必要な画像のみダウンロード
- **更新の柔軟性**: アプリ更新なしで画像を差し替え可能
- **キャッシュ管理**: ローカルキャッシュで高速表示

## 📦 実装内容

### 新規作成ファイル

1. **FirebaseImageService.swift**: Firebase Storageから画像を取得・管理
2. **upload-images-to-firebase.js**: 画像アップロードスクリプト
3. **storage.rules**: Firebase Storage セキュリティルール
4. **scripts/package.json**: Node.js依存関係

### 修正ファイル

1. **PersonalityImageService.swift**: Firebase Storageパス生成機能を追加
2. **CharacterPreloadService.swift**: Firebase Storage対応
3. **CharacterModels.swift**: ImageSource.firebaseStorage を追加
4. **CharacterDisplayComponent.swift**: 非同期画像取得に対応
5. **Logger.swift**: imageService カテゴリーを追加
6. **firebase.json**: Storage Rulesを追加

## 🚀 移行手順

### ステップ1: Firebase Storage Rulesをデプロイ

```bash
cd /Users/onoderaryousuke/Desktop/development-D/Character
firebase deploy --only storage
```

### ステップ2: 画像をFirebase Storageにアップロード

#### 2-1. Firebase Admin SDKの準備

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクト設定 → サービスアカウント
3. 「新しい秘密鍵を生成」をクリック
4. ダウンロードしたJSONファイルを `scripts/serviceAccountKey.json` として保存

#### 2-2. 依存関係のインストール

```bash
cd scripts
npm install
```

#### 2-3. 画像アップロードの実行

```bash
npm run upload
```

**アップロード内容:**
- Female画像: 243パターン
- Male画像: 243パターン
- デフォルト画像: 2枚
- **合計: 488枚**

**所要時間:** 約5-10分（ネットワーク速度による）

### ステップ3: Xcodeプロジェクトのビルド

1. Xcodeでプロジェクトを開く
2. ビルド（⌘B）してエラーがないことを確認
3. シミュレーターで動作確認

### ステップ4: 動作テスト

#### 必須テスト項目

- [ ] BIG5診断後にキャラクター画像が表示される
- [ ] 初回表示時にデフォルト画像が表示される
- [ ] Firebase Storageから画像が取得される（ログ確認）
- [ ] 2回目以降はキャッシュから表示される
- [ ] オフライン時にデフォルト画像にフォールバックする
- [ ] WiFi接続時にプリロードが動作する

#### テストコマンド（ログ確認）

Xcodeのコンソールで以下のログを確認:

```
🖼️ キャッシュから画像取得
⬇️ Firebase Storageからダウンロード開始
✅ ダウンロード完了
💾 キャッシュに保存
```

### ステップ5: Assets.xcassetsから画像を削除

**⚠️ 重要: このステップは動作確認後に実施してください**

```bash
# バックアップを作成
cd /Users/onoderaryousuke/Desktop/development-D/Character
cp -r Character/Assets.xcassets Character/Assets.xcassets.backup

# Female/Male画像を削除（デフォルト画像は残す）
cd Character/Assets.xcassets
find . -name "Female_*.imageset" -exec rm -rf {} +
find . -name "Male_*.imageset" -exec rm -rf {} +
```

**残す画像:**
- `character_female.imageset`
- `character_male.imageset`
- `AppIcon.appiconset`
- `AppLogo.imageset`
- その他のUI用画像

### ステップ6: 再ビルドとサイズ確認

```bash
# プロジェクトをクリーンビルド
# Xcode: Product → Clean Build Folder (⇧⌘K)

# ビルド後、.ipaまたはアーカイブサイズを確認
```

**期待されるサイズ削減:**
- 変更前: 約8.6GB
- 変更後: 約5.8GB（Assets.xcassetsから2.8GB削減）

## 🔧 キャッシュ管理

### キャッシュの場所

```
~/Library/Caches/CharacterImages/
```

### キャッシュの確認方法

```swift
let cacheSize = FirebaseImageService.shared.getCacheSizeFormatted()
print("キャッシュサイズ: \(cacheSize)")
```

### キャッシュのクリア

```swift
try? FirebaseImageService.shared.clearCache()
```

### キャッシュ設定

- **最大サイズ**: 500MB（FirebaseImageService.swift で変更可能）
- **有効期限**: 30日（FirebaseImageService.swift で変更可能）
- **自動クリーン**: 起動時と制限超過時

## 🐛 トラブルシューティング

### 画像が表示されない

1. **Firebase Storage Rulesを確認**
   ```bash
   firebase deploy --only storage
   ```

2. **画像がアップロードされているか確認**
   - Firebase Console → Storage → character-images/

3. **ログを確認**
   - Xcodeコンソールでエラーメッセージを確認

4. **ネットワーク接続を確認**
   - WiFi/モバイルデータが有効か
   - ファイアウォールやVPNの影響

### アップロードエラー

```
❌ アップロード失敗: PERMISSION_DENIED
```

**解決方法:**
- サービスアカウントキーが正しいか確認
- Firebase Storageが有効になっているか確認
- 請求先アカウントが設定されているか確認（Blaze プランが必要）

### キャッシュエラー

```
❌ キャッシュ保存失敗
```

**解決方法:**
- ディスク容量を確認
- アプリの権限を確認
- キャッシュディレクトリの作成権限を確認

## 📊 監視とメトリクス

### Firebase Consoleで確認すべき項目

1. **Storage使用量**: character-images/ のサイズ
2. **ダウンロード回数**: 1日あたりのリクエスト数
3. **エラー率**: 4xx/5xx エラーの発生率

### 推奨アラート設定

- Storage使用量が 5GB を超えた場合
- エラー率が 5% を超えた場合
- 1日あたりのダウンロードが 10,000 を超えた場合

## 💰 コスト見積もり

### Firebase Storage 料金（2024年1月時点）

- **ストレージ**: $0.026/GB/月
- **ダウンロード**: $0.12/GB

### 想定コスト

**ストレージ:**
- 画像サイズ: 約2.8GB
- 月額: 2.8GB × $0.026 = **約$0.07/月**

**ダウンロード（月間1000ユーザー想定）:**
- 1ユーザーあたり: 平均5MB（キャラクター画像1枚）
- 合計: 1000 × 5MB = 5GB
- 月額: 5GB × $0.12 = **約$0.60/月**

**合計: 約$0.67/月（約100円/月）**

## 📚 参考資料

- [Firebase Storage ドキュメント](https://firebase.google.com/docs/storage)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Firebase Storage Security Rules](https://firebase.google.com/docs/storage/security)

## ✅ チェックリスト

移行作業が完了したら、以下をチェックしてください:

- [ ] Firebase Storage Rulesをデプロイ
- [ ] 488枚の画像をアップロード
- [ ] Xcodeプロジェクトがビルド成功
- [ ] 全テスト項目をパス
- [ ] Assets.xcassetsから画像を削除
- [ ] アプリサイズが削減されていることを確認
- [ ] Firebase Console で使用量を確認
- [ ] 本番環境でテスト

## 🎉 移行完了

お疲れ様でした！Firebase Storageへの移行が完了しました。

今後の画像更新は、Firebase Consoleまたはアップロードスクリプトを使って行えます。
